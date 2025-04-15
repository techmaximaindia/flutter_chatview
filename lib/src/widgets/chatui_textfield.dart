/*
 * Copyright (c) 2022 Simform Solutions
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview/src/utils/constants/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../chatview.dart';
import '../utils/debounce.dart';
import '../utils/package_strings.dart';
import '../utils/constants/constants.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'image_message_view.dart';
import 'package:path/path.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'socket_manager.dart';
import 'send_message_widget.dart';


class ChatUITextField extends StatefulWidget {
  const ChatUITextField({
    Key? key,
    this.sendMessageConfig,
    /* required this.focusNode, */
    this.autofocus = true,
    required this.textEditingController,
    required this.onPressed,
    required this.onRecordingComplete,
    required this.onImageSelected,
    required this.onAIPressed,
    required this.messageController,
    required this.ai_send_pressed,
    /* this.reply_message_id,
    this.reply_messages, */
  }) : super(key: key);

  /// Provides configuration of default text field in chat.
  final SendMessageConfiguration? sendMessageConfig;

/*   /// Provides focusNode for focusing text field.
  final FocusNode focusNode; */

  /// Provides functions which handles text field.
  final TextEditingController textEditingController;

  /// Provides callback when user tap on text field.
  final VoidCallBack onPressed;

  /// Provides callback once voice is recorded.
  final Function(String?) onRecordingComplete;

  /// Provides callback when user select images from camera/gallery.
  final StringsCallBack onImageSelected;

  final bool autofocus;
  
  final VoidCallBack onAIPressed;

  final TextEditingController messageController;

  final VoidCallBack ai_send_pressed;
/* 
  final String? reply_message_id;
  
  final String? reply_messages; */
  

  @override
  State<ChatUITextField> createState() => _ChatUITextFieldState();
}

class _ChatUITextFieldState extends State<ChatUITextField> {
 
  /* final TextEditingController _messageController = TextEditingController(text: ""); */

  final ValueNotifier<String> _inputText = ValueNotifier('');

  final ImagePicker _imagePicker = ImagePicker();

  RecorderController? controller;

  ValueNotifier<bool> isRecording = ValueNotifier(false);

  SendMessageConfiguration? get sendMessageConfig => widget.sendMessageConfig;

  VoiceRecordingConfiguration? get voiceRecordingConfig =>
      widget.sendMessageConfig?.voiceRecordingConfiguration;

  ImagePickerIconsConfiguration? get imagePickerIconsConfig =>
      sendMessageConfig?.imagePickerIconsConfig;

  TextFieldConfiguration? get textFieldConfig =>
      sendMessageConfig?.textFieldConfig;

  OutlineInputBorder get _outLineBorder => OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.transparent),
        borderRadius: textFieldConfig?.borderRadius ??
            BorderRadius.circular(textFieldBorderRadius),
      );

  ValueNotifier<TypeWriterStatus> composingStatus =
      ValueNotifier(TypeWriterStatus.typed);

  late Debouncer debouncer;
  OverlayEntry? _suggestionOverlay;
  final LayerLink _layerLink = LayerLink();
  List<Map<String, String>> suggestions = [];
  String apiStatusMessage = ''; 
  String? current_page;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isSendEnabled = ValueNotifier<bool>(false);
  @override
  void initState() {
    attachListeners();
    debouncer = Debouncer(
        sendMessageConfig?.textFieldConfig?.compositionThresholdTime ??
            const Duration(seconds: 1));
    super.initState();

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      controller = RecorderController();
    }
    
    SocketManager().connectSocket(
      onMessageReceived: (incomingText) {
        setState(() {
          /* _messageController.text += incomingText;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          ); */
          widget.messageController.text += incomingText;
          widget.messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: widget.messageController.text.length),
          );
        });
        _isSendEnabled.value = true;
        _scrollToBottom();
      },
      /* source: 'chat', */
    );
    _loadPreferences();
  }
  Future<void> _loadPreferences() async {
   final prefs = await SharedPreferences.getInstance();
    current_page = prefs.getString('page')??''; 
  }
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }
  @override
  Future<void> dispose() async {
    debouncer.dispose();
    composingStatus.dispose();
    isRecording.dispose();
    _inputText.dispose();
    _suggestionOverlay?.remove();
    SocketManager().disconnectSocket();
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('conversation_id');
    prefs.remove('ticket_id');
    _loadPreferences();
    super.dispose();
  }
  void attachListeners() {
    composingStatus.addListener(() {
      widget.sendMessageConfig?.textFieldConfig?.onMessageTyping
          ?.call(composingStatus.value);
    });
  }
  List<dynamic> responses = [];
  Future<List<Map<String, String>>> fetch_canned_responses(String? shortcode) async 
  {
    if (shortcode == null) 
    {
      print('Shortcode is null');
      return Future.value([]); 
    }
    final prefs = await SharedPreferences.getInstance();
    final String? uuid = prefs.getString('uuid');
    final String? team_alias= prefs.getString('team_alias');
    final url = base_url+'api/canned_responses/';
    var headers = {
      'Authorization': '$uuid|$team_alias',
      'Content-Type': 'application/json',
    };
    var request = http.Request('POST', Uri.parse(url));
    request.body = json.encode({
      "short_code": shortcode,
      "source":"mobileapp"
    });
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) 
    {
      String responseBody = await response.stream.bytesToString();
      Map<String, dynamic> decodedResponse = json.decode(responseBody);

      if (decodedResponse.containsKey('data') && decodedResponse['data'] != null) 
      {
        List<Map<String, String>> todos = (decodedResponse['data'] as List)
            .map((item) => {
                  "short_code": item['short_code'].toString()??'',
                  "content": item['content'].toString()??'',
                  "media_type": item['media_type']?.toString() ?? '',
                  "media_url": item['media_url']?.toString() ?? '',
                })
            .toList();
        return todos;
      } 
      else 
      {
        print('Key "data" not found or is null');
        return [];
      }
    } 
    else if (response.statusCode == 404) 
    {
      print('Status code 404: Not found');
      return Future.value([]); 
    } 
    else 
    {
      print(response.reasonPhrase);
      return [];
    }
  }
  void _removeSuggestionOverlay() 
  {
    _suggestionOverlay?.remove();
    _suggestionOverlay = null;
  }

 Future<String> call_ai_assist(BuildContext context,String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? uuid = prefs.getString('uuid');
      final String? team_alias= prefs.getString('team_alias');
      final url = base_url + 'api/reply/';
      final String? cb_lead_id = prefs.getString('cb_lead_id');
      final String? platform = prefs.getString('platform');
      final String? conversation_id = prefs.getString('conversation_id');
      final String? cb_lead_name = prefs.getString('cb_lead_name');
      final String? ticket_id = prefs.getString('ticket_id');
      final String? ticket_name = prefs.getString('ticket_name');

      final String? page=prefs.getString('page');

      String source;
      String? alias;
      String? from_name;

      if(page=='chat'){
        source = "chat";
        alias = conversation_id;
        from_name = cb_lead_name;
      }
      else{
        source = "ticket";
        alias = ticket_id;
        from_name = ticket_name;
      }

      var headers = {
        'Content-Type': 'application/json',
        'Authorization': '$uuid|$team_alias',
      };
      var request = http.Request('POST', Uri.parse(url));
      request.body = json.encode({
        "source": "mobileapp",
        "type": "reply",
        "conversation_attributes": {
          "build_type": "summary",
          "conversation_alias": alias,
          "source": source,
          "from_name": from_name,
          "suggestion": text,
          "message_id": "",
          "query": "",
          "response_mode":'streaming',
          "ref_element":"button"
        }
      });
      request.headers.addAll(headers);
      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        Map<String, dynamic> decodedResponse = json.decode(responseBody);
        if (decodedResponse['success'] == 'false') {
          return decodedResponse['ai_error_message'];
        } else {
          var aiResponse = json.decode(decodedResponse['ai_response']);
         // return aiResponse['answer'];
           return source == "ticket"
              ? json.decode(aiResponse['answer'])['body']
              : aiResponse['answer']; 

        }
      } else {
        throw "Failed to generate AI response";
      }
    } catch (e) {
      return "";
    }
  }
  Future<void> sendMessage(String message,) async 
  {
    final prefs = await SharedPreferences.getInstance();
    final String? cb_lead_id = prefs.getString('cb_lead_id');
    final String? platform = prefs.getString('platform');
    final String? conversation_id = prefs.getString('conversation_id');
    Map<String, dynamic> data = {
      "cb_lead_id": cb_lead_id,
      "platform": platform,
      "message_body": message,
      "conversation_id":conversation_id,
      "cb_message_source": 'android',
      "reply_message_id": '', 
    };
    String jsonData = json.encode(data);
    final String? uuid = prefs.getString('uuid');
    final String? team_alias= prefs.getString('team_alias');
    String url = base_url + 'api/send_message/';
    var response = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "$uuid|$team_alias",
      },
      body: jsonData,
    );
    if (response.statusCode == 200) {

    } 
    else {

    }
  }
    Future<void> send_ticket_Message(String message,) async {
    final prefs = await SharedPreferences.getInstance();
      final String? ticket_id = prefs.getString('ticket_id');
    final String? ticket_name = prefs.getString('ticket_name');
    final String? platform = prefs.getString('platform');
    Map<String, dynamic> data = 
    {
    "ticket_alias": ticket_id,
    "message_body": message,
    "source":'mobileapp'
  };

    String jsonData = json.encode(data);
    final String? uuid = prefs.getString('uuid');
       final String? team_alias= prefs.getString('team_alias');
    String url = base_url + 'api/ticket/response/';
    var response = await http.post(
        Uri.parse(url),
        headers: 
        {
          "Content-Type": "application/json",
          "Authorization": "$uuid|$team_alias"
        },
        body: jsonData,
      );
    if (response.statusCode == 200) {
    } 
    else {

    }
  }

  void  _show_dialog_fetch_response(BuildContext context,String message)  {
  
    bool _isEditing = false;
    bool _isExpanded = false; 
     
    widget.messageController.clear();
    _isSendEnabled.value = false;

    call_ai_assist(context,message).then((response) {
        widget.messageController.text = response; 
         _isSendEnabled.value = response.isNotEmpty;
      }).catchError((error) {
        widget.messageController.text = "Failed to fetch response.";
        _isSendEnabled.value = false;
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.0),
                  topRight: Radius.circular(20.0),
              ),
              child: Container(
                height: _isExpanded ? MediaQuery.of(context).size.height : MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0059FC), Color(0xFF820AFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 60,
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isEditing = !_isEditing;
                                      });
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min, 
                                      children: [
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            color: _isEditing ? Colors.white : Colors.white,
                                          ),
                                        ),
                                        if (_isEditing) ...[
                                          SizedBox(width: 3),
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  widget.messageController.clear();
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row
                            (
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: 
                              [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      WidgetSpan(
                                        child: FaIcon(
                                          FontAwesomeIcons.magicWandSparkles,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        alignment: PlaceholderAlignment.middle,
                                      ),
                                      WidgetSpan(
                                        child: SizedBox(width: 5),
                                      ),
                                      TextSpan(
                                        text: "MaxIA",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    /* Divider(color: Colors.white54, thickness: 1), */
                    Expanded
                    (
                      child: Padding
                      (
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView
                        (
                          controller: _scrollController,
                          child: Card
                          (
                            color: Color(0xFF90CAF9), 
                            shape: RoundedRectangleBorder
                            (
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 5,
                            child: Padding
                            (
                              padding: const EdgeInsets.all(16.0),
                              child: Column
                              (
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: 
                                [
                                  TextField
                                  (
                                    controller: widget.messageController,
                                    maxLines: null,
                                    decoration: const InputDecoration
                                    (
                                      border: InputBorder.none,
                                    ),
                                    enabled: _isEditing,
                                    style: TextStyle(
                                      color:Colors.black, 
                                    ),
                                    onChanged:(text){
                                      setState(() {
                                        _isSendEnabled.value = text.trim().isNotEmpty;
                                      });
                                    }
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          height: 60,
                          padding: EdgeInsets.only(left: 8.0, right: 8.0, bottom: 20.0),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child:ValueListenableBuilder<bool>
                                      (
                                        valueListenable: _isSendEnabled,
                                        builder: (context, isSendEnabled, child) 
                                        {
                                         return ElevatedButton
                                         (
                                            onPressed: _isSendEnabled.value==true 
                                            ?() async {
                                              final value = await SharedPreferences.getInstance();
                                              final String? page = value.getString('page');

                                              /* if (page == 'chat') { */
                                                /* widget.onPressed(); */
                                                widget.ai_send_pressed();
                                                /* sendMessage(_messageController.text); */
                                              /* } else { */
                                                /* send_ticket_Message(_messageController.text); */
                                              /* } */
                                              /* _messageController.clear(); */
                                              widget.messageController.clear();
                                              Navigator.of(context).pop();
                                            }
                                            :null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                              minimumSize: const Size(double.infinity, 58),
                                            ),
                                            child: const Text(
                                              'Send',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            );
          },
        );
      },
    ).whenComplete(() {
      /* _messageController.clear(); */
      widget.messageController.clear();
      _isSendEnabled.value = false;
    });
  } 
  
  @override
  Widget build(BuildContext context) 
  {

    final outlineBorder = _outLineBorder;
    return IntrinsicHeight
    (
     child: Align
     (
        alignment: Alignment.bottomCenter,
        child: SizedBox
        (
          width: MediaQuery.of(context).size.width,
          //height:MediaQuery.of(context).size.height, new
          child: Stack
          (
            children: 
            [
              /* Positioned
              (
                right: 0,
                left: 0,
                bottom: 0,
                child: Container(
                  height: MediaQuery.of(context).size.height / ((!kIsWeb && Platform.isIOS) ? 24 : 28),
                  color: widget.sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,  newe
                ),
              ), */
              /* Padding(
                padding: EdgeInsets.fromLTRB(bottomPadding4,
                      bottomPadding4,
                      bottomPadding4,
                      bottomPadding4),
                child: */ Stack
                (
                  alignment: Alignment.bottomCenter,
                  children: 
                  [
                    if (suggestions.isNotEmpty)
                      Container
                      (
                        decoration: BoxDecoration(
                          color: widget.sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                        ),
                        margin: const EdgeInsets.only(
                          bottom: 17,
                          right: 0.4,
                          left: 0.4,
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          leftPadding,
                          leftPadding,
                          leftPadding,
                          30,
                        ),
                        child: Container
                        (
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ConstrainedBox
                          (
                            constraints: BoxConstraints(
                              maxHeight: 150,
                            ),
                            child: SingleChildScrollView
                            (
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: suggestions.map((suggestion) 
                                {
                                    Widget mediaWidget;
                                    switch (suggestion['media_type']) 
                                    {
                                      case 'image':
                                        mediaWidget = Image.network(
                                          suggestion['media_url'] ?? '',
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        );
                                        break;
                                      case 'video':
                                        mediaWidget = Icon(
                                          Icons.video_call,
                                          /* size: 50, */
                                          color: Colors.grey,
                                        );
                                        break;
                                      case 'audio':
                                        mediaWidget = Icon(
                                          Icons.audiotrack,
                                          /* size: 50, */
                                          color: Colors.grey,
                                        );
                                        break;
                                      case 'file':
                                        mediaWidget = Icon(
                                          Icons.file_copy_outlined,
                                          /* size: 50, */
                                          color: Colors.grey,
                                        );
                                        break;
                                      default:
                                        mediaWidget = Text(
                                          suggestion['content'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                          ),
                                        );
                                        break;
                                    }
                                   return ListTile
                                   (
                                    contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                                    dense: true,
                                    visualDensity: VisualDensity(horizontal: 0, vertical: -3),
                                    title: Row(
                                      children: [
                                        Flexible
                                        (
                                          child:Text
                                          (
                                            '${suggestion['short_code'] ?? 'No Shortcode'} - ',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 5,),
                                        Flexible(
                                          child: mediaWidget,
                                        ),
                                      ],
                                    ),
                                    onTap: () async{
                                      if (suggestion['media_url']!='') 
                                      {

                                        Future<File> _fileFromImageUrl(image_url) async 
                                        {
                                          final fileName = image_url.split('/').last;
                                            final response = await http.get(Uri.parse(image_url));

                                            final documentDirectory = await getApplicationDocumentsDirectory();

                                            final file = File(join(documentDirectory.path, fileName));

                                            file.writeAsBytesSync(response.bodyBytes);

                                            return file;
                                          }
                                        String getFileExtension(String fileName) 
                                        {
                                          return ".${fileName.split('.').last}".toLowerCase();
                                        }
                                       final prefs = await SharedPreferences.getInstance();
                                        final String? uuid = prefs.getString('uuid');
                                        final String? team_alias= prefs.getString('team_alias');
                                        final String? cb_lead_id = prefs.getString('cb_lead_id');
                                        final String? platform = prefs.getString('platform');
                                        final String? conversation_id = prefs.getString('conversation_id');
                                        String url = base_url+'api/send_image_message/';
                                        Map<String, String> headers = {"Authorization": "$uuid|$team_alias"};
                                        
                                        if (suggestion['media_url'] != '' ) 
                                        {
                                          var postUri = Uri.parse(url);
                                          var request = http.MultipartRequest("POST", postUri);
                                          request.fields['cb_lead_id'] = "$cb_lead_id";
                                          request.fields['platform'] = "$platform";
                                          request.fields['message_body'] = ''; 
                                          request.fields['conversation_id'] = "$conversation_id";
                                          request.fields['cb_message_source'] = 'android';
                                          request.headers.addAll(headers);
                                          String extension = getFileExtension("${suggestion['media_url']}");
                                          String media_type = "file";
                                          if(extension == '.jpeg' || extension == '.jpg' || extension == '.png')
                                          {
                                              media_type = "image";
                                          }
                                          else if(extension=='.mp4')
                                          {
                                            media_type="video";
                                          }
                                          else if(extension=='.mp3')
                                          {
                                            media_type="audio";
                                          }
                                          var uploadfile = await _fileFromImageUrl(suggestion['media_url']);
                                          //request.files.add(await http.MultipartFile.fromPath('file', uploadfile, contentType: MediaType('application', media_type)));
                                          request.files.add(await http.MultipartFile.fromPath('file', uploadfile.path, contentType: MediaType('application', media_type)));
                                          final response = await request.send();
                                          final responseData = await response.stream.toBytes();
                                          final responseString = String.fromCharCodes(responseData);
                                        }
                                      } 
                                      else 
                                      {
                                        widget.textEditingController.text = suggestion['content'] ?? '';
                                      }
                                      setState(() {
                                        suggestions = [];
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: textFieldConfig?.padding ?? const EdgeInsets.symmetric(horizontal: 4), /* new */
                        margin: textFieldConfig?.margin,
                        decoration: BoxDecoration(
                          borderRadius: textFieldConfig?.borderRadius ?? BorderRadius.circular(textFieldBorderRadius),
                          color: sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
                        ),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: isRecording,
                          builder: (_, isRecordingValue, child) {
                            return Row(
                              children: [
                                if (isRecordingValue && controller != null && !kIsWeb)
                                  AudioWaveforms(
                                    size: Size(MediaQuery.of(context).size.width * 0.75, 50),
                                    recorderController: controller!,
                                    margin: voiceRecordingConfig?.margin,
                                    padding: voiceRecordingConfig?.padding ?? const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: voiceRecordingConfig?.decoration ?? BoxDecoration(
                                      color: voiceRecordingConfig?.backgroundColor,
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    waveStyle: voiceRecordingConfig?.waveStyle ?? WaveStyle(
                                      extendWaveform: true,
                                      showMiddleLine: false,
                                      waveColor: voiceRecordingConfig?.waveStyle?.waveColor ?? Colors.black,
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: TextField(
                                      /* focusNode: widget.focusNode, */
                                      autofocus: widget.autofocus,
                                      controller: widget.textEditingController,
                                      style: textFieldConfig?.textStyle ?? const TextStyle(color: Colors.white),
                                      maxLines: textFieldConfig?.maxLines ?? 5,
                                      minLines: textFieldConfig?.minLines ?? 1,
                                      keyboardType: textFieldConfig?.textInputType,
                                      inputFormatters: textFieldConfig?.inputFormatters,
                                      onChanged: _onChanged,
                                      textCapitalization: textFieldConfig?.textCapitalization ?? TextCapitalization.sentences,
                                      decoration: InputDecoration(
                                        hintText: textFieldConfig?.hintText ?? PackageStrings.message,
                                        fillColor: sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
                                        filled: true,
                                        hintStyle: textFieldConfig?.hintStyle ?? TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.grey.shade600,
                                          letterSpacing: 0.25,
                                        ),
                                        contentPadding: textFieldConfig?.contentPadding ?? const EdgeInsets.symmetric(horizontal: 6),
                                        border: _outLineBorder,
                                        focusedBorder: _outLineBorder,
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: const BorderSide(color: Colors.transparent),
                                          borderRadius: textFieldConfig?.borderRadius ?? BorderRadius.circular(textFieldBorderRadius),
                                        ),
                                      ),
                                    ),
                                  ),
                                ValueListenableBuilder<String>(
                                  valueListenable: _inputText,
                                  builder: (_, inputTextValue, child){
                                    if (inputTextValue.isNotEmpty) {
                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                            IconButton(
                                              onPressed: () {
                                                final inputText = widget.textEditingController.text;
                                                if (inputText.isNotEmpty) {
                                                  _show_dialog_fetch_response(context, inputText);
                                                  widget.textEditingController.clear(); 
                                                  _inputText.value = '';
                                                } else {
                                                  _inputText.value = '';
                                                }
                                              },
                                              icon: const FaIcon(
                                                FontAwesomeIcons.magicWandSparkles,
                                                size: 18,
                                                color: Colors.black,
                                              ),
                                            ),
                                          IconButton(
                                            color: sendMessageConfig?.defaultSendButtonColor ?? Colors.green,
                                            onPressed: () {
                                              widget.onPressed();
                                              _inputText.value = '';
                                            },
                                            icon: sendMessageConfig?.sendButtonIcon ?? const Icon(Icons.send),
                                            ),
                                       ],
                                    );
                                    } else {
                                      return Row(
                                        children: [
                                          if (!isRecordingValue) ...[
                                            if (sendMessageConfig?.enableCameraImagePicker ?? true)
                                              IconButton(
                                                constraints: const BoxConstraints(),
                                                onPressed: () => /* _onIconPressed(
                                                  ImageSource.camera,
                                                  config: sendMessageConfig?.imagePickerConfiguration,
                                                ), */{},
                                                icon: imagePickerIconsConfig?.cameraImagePickerIcon ?? Icon(
                                                  Icons.camera_alt_outlined,
                                                  color: imagePickerIconsConfig?.cameraIconColor,
                                                ),
                                              ),
                                            if (sendMessageConfig?.enableGalleryImagePicker ?? true)
                                              IconButton(
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _onIconPressed(
                                                  context,
                                                  ImageSource.gallery,
                                                  config: sendMessageConfig?.imagePickerConfiguration,
                                                ),
                                                icon: imagePickerIconsConfig?.galleryImagePickerIcon ?? Icon(
                                                  Icons.image,
                                                  color: imagePickerIconsConfig?.galleryIconColor,
                                                ),
                                              ),
                                            
                                            if(inputTextValue.isEmpty)  
                                              IconButton(
                                                onPressed: () {
                                                  widget.onAIPressed();
                                                },
                                                icon: const FaIcon(
                                                  FontAwesomeIcons.magicWandSparkles,
                                                  size: 18,
                                                  color: Colors.black,
                                                ),
                                              ),  
                                          ],
                                          if (sendMessageConfig?.allowRecordingVoice ?? true && Platform.isIOS && Platform.isAndroid && !kIsWeb)
                                            IconButton(
                                              onPressed: _recordOrStop,
                                              icon: (isRecordingValue ? voiceRecordingConfig?.micIcon : voiceRecordingConfig?.stopIcon) ?? Icon(isRecordingValue ? Icons.stop : Icons.mic),
                                              color: voiceRecordingConfig?.recorderIconColor,
                                            )
                                        ],
                                      );
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                /* ), */
              ),
           ],     
          ),
        ),
     ),
    );
  }
  Future<void> _recordOrStop() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    if (!isRecording.value) {
      await controller?.record();
      isRecording.value = true;
    } else {
      final path = await controller?.stop();
      isRecording.value = false;
      widget.onRecordingComplete(path);
    }
  }
  /* void _onIconPressed(
    ImageSource imageSource, {
    ImagePickerConfiguration? config,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: imageSource,
        maxHeight: config?.maxHeight,
        maxWidth: config?.maxWidth,
        imageQuality: config?.imageQuality,
        preferredCameraDevice:
            config?.preferredCameraDevice ?? CameraDevice.rear,
      );
      String? imagePath = image?.path;
      if (config?.onImagePicked != null) {
        String? updatedImagePath = await config?.onImagePicked!(imagePath);
        if (updatedImagePath != null) imagePath = updatedImagePath;
      }
      widget.onImageSelected(imagePath ?? '', '');
    } catch (e) {
      widget.onImageSelected('', e.toString());
    }
  } */
/*  Future<void> _handleImageSelection(BuildContext context, String? imagePath) async {
  final String? sentImagePath = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (ctx) => ImageViewerPage(imagePath: imagePath ?? '',messageController: widget.textEditingController,),
    ),
  );

  if (sentImagePath != null) {
    widget.onImageSelected(sentImagePath, '');
  }
} */

void _onIconPressed(
  BuildContext ctx, // Pass a valid context
  ImageSource imageSource, {
  ImagePickerConfiguration? config,
}) async {
  try {
    final XFile? image = await _imagePicker.pickImage(
      source: imageSource,
      maxHeight: config?.maxHeight,
      maxWidth: config?.maxWidth,
      imageQuality: config?.imageQuality,
      preferredCameraDevice: config?.preferredCameraDevice ?? CameraDevice.rear,
    );

    String? imagePath = image?.path;

    // Allow custom processing of image path
    if (config?.onImagePicked != null) {
      String? updatedImagePath = await config?.onImagePicked!(imagePath);
      if (updatedImagePath != null) imagePath = updatedImagePath;
    }
     if (imagePath != null && imagePath.isNotEmpty) {
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (context) => ImageViewerPage(
            imagePath: imagePath??'',
            onSend: (sentImagePath,message) {
              widget.onImageSelected(sentImagePath,'', message??''); 
            },
            padding:EdgeInsets.fromLTRB(bottomPadding4,
                      bottomPadding4,
                      bottomPadding4,
                      bottomPadding4),
          ),
        ),
      );
    }
    /* if (imagePath != null && imagePath.isNotEmpty) {
      await _handleImageSelection(ctx, imagePath??''); // Use the valid context
    } */
  } catch (e) {
    widget.onImageSelected('', e.toString(),'');
  }
}


  
  void _onChanged(String inputText) async 
  {
    if (inputText.startsWith('/')) 
    {
      final canned_response = await fetch_canned_responses(inputText.substring(1));
      setState(() 
      {
        if (inputText.substring(1).isEmpty)
        {
            suggestions=[
              {
              "short_code": "Enter the shortcode",
              "content": "",
              "media_type": "",
              "media_url": ""
            }
          ];
        }
        else if (canned_response.isEmpty) 
        {
          suggestions = 
          [
            {
              "short_code": "Nothing to Suggest",
              "content": "",
              "media_type": "",
              "media_url": ""
            }
          ];
        } 
        else 
        {
          suggestions=canned_response;
        }
      });
    }
    else 
    {
      _removeSuggestionOverlay();
      setState(() 
      {
        suggestions = [];
      });
    }
    if(inputText.isEmpty)
    {
      _inputText.value='';
    }
    else
    {
      _inputText.value=inputText;
    }
    debouncer.run(() 
    {
      composingStatus.value = TypeWriterStatus.typed;
    },() 
    {
      composingStatus.value = TypeWriterStatus.typing;
    });
  }
}


class ImageViewerPage extends StatefulWidget {
  final String? imagePath;
  final Function(String, String?) onSend;
  final EdgeInsetsGeometry padding;

  const ImageViewerPage({Key? key, required this.imagePath, required this.onSend,required this.padding}) : super(key: key);

  @override
  _ImageViewerPageState createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final TextEditingController _messageController = TextEditingController();
  /* bool _showSendButton = false; */

  @override
  void initState() {
    super.initState();
    /* _messageController.addListener(_toggleSendButton); */
  }

  @override
  void dispose() {
/*     _messageController.removeListener(_toggleSendButton); */
    _messageController.dispose();
    super.dispose();
  }

/*   void _toggleSendButton() {
    setState(() {
      _showSendButton = _messageController.text.trim().isNotEmpty;
    });
  } */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Image Preview', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: widget.imagePath != null && widget.imagePath!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(File(widget.imagePath!), fit: BoxFit.contain),
                    )
                  : const Text('No image selected', style: TextStyle(color: Colors.white70)),
            ),
          ),
          Container(
            /* margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12), */
            margin:const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            padding:widget.padding,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 5,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: "Add a caption...",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                /* if (_showSendButton) */
                  GestureDetector(
                    onTap: () {
                      widget.onSend(widget.imagePath ?? '', _messageController.text.trim());
                      _messageController.clear();
                      Navigator.pop(context);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.send, color: Colors.blue, size: 24),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* class ImageViewerPage extends StatefulWidget {
  final String? imagePath;
  final Function(String, String?) onSend; // Callback to send image with message

  const ImageViewerPage({Key? key, required this.imagePath, required this.onSend}) : super(key: key);

  @override
  _ImageViewerPageState createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final TextEditingController _messageController = TextEditingController(); // Add controller

  @override
  void dispose() {
    _messageController.dispose(); // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Image')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: widget.imagePath != null && widget.imagePath!.isNotEmpty
                  ? Image.file(File(widget.imagePath!)) // Display selected image
                  : const Text('No image selected'),
            ),
          ),
          // Text Field for message input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter message...",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ❌ Cancel Button
              FloatingActionButton(
                backgroundColor: Colors.grey,
                onPressed: () {
                  Navigator.pop(context); // Move back without sending
                },
                child: const Icon(Icons.close, color: Colors.white),
              ),
              // ✅ Send Button
              FloatingActionButton(
                backgroundColor: Colors.blue,
                onPressed: () {
                  widget.onSend(widget.imagePath ?? '', _messageController.text.trim()??'');
                  Navigator.pop(context); // Close the viewer after sending
                },
                child: const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
} */
