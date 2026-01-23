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
import 'package:flutter/gestures.dart'; // For TapGestureRecognizer
import 'package:url_launcher/url_launcher.dart'; // For launching URLs
import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

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

class _ChatUITextFieldState extends State<ChatUITextField> with WidgetsBindingObserver{
 
  /* final TextEditingController _messageController = TextEditingController(text: ""); */

  final ValueNotifier<String> _inputText = ValueNotifier('');

  final ImagePicker _imagePicker = ImagePicker();

  /* RecorderController? controller; */
  
  late final RecorderController recorderController;
  
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
     WidgetsBinding.instance.addObserver(this);
    attachListeners();
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      recorderController = RecorderController()
    ..androidEncoder = AndroidEncoder.aac
    ..androidOutputFormat = AndroidOutputFormat.mpeg4
    ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
    ..sampleRate = 16000; 
      //controller = RecorderController();
    }
    debouncer = Debouncer(
        sendMessageConfig?.textFieldConfig?.compositionThresholdTime ??
            const Duration(seconds: 1));
    super.initState();

    
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
   @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app goes to inactive or paused state (like when swiping down)
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopRecordingIfActive();
    }
  }

  Future<void> _stopRecordingIfActive() async {
    if (isRecording.value) {
      try {
        await recorderController.stop();
        isRecording.value = false;
      } catch (e) {
        print('Error stopping recording: $e');
        isRecording.value = false;
      }
    }
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
  void dispose() async {
    debouncer.dispose();
    composingStatus.dispose();
    isRecording.dispose();
    _inputText.dispose();
    recorderController.stop();
    WidgetsBinding.instance.removeObserver(this);
     _stopRecordingIfActive();
    _suggestionOverlay?.remove();
    try {
      SocketManager().disconnectSocket();
    } catch (e) {
      print('Socket disconnection error: $e');
    }

    // Fire and forget any async operations
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('conversation_id');
      prefs.remove('ticket_id');
      _loadPreferences(); // if this is async, consider moving it elsewhere
    });
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
           /*return source == "ticket"
              ? json.decode(aiResponse['answer'])['body']
              : aiResponse['answer'];*/
          try {
            if (source == "ticket") {
              var decodedAnswer = json.decode(aiResponse['answer']);
              if (decodedAnswer is Map && decodedAnswer.containsKey('response')) {
                return decodedAnswer['response'];
              } else {
                return aiResponse['answer'];
              }
            } else {
              return aiResponse['answer'];
            }
          } catch (e) {
            return aiResponse['answer'];
          }

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
                    colors: [Color(0xFF6366F1), Color(0xFF820AFF)],
                    stops: [0.0, 0.8],
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
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Color(0xFF6366F1),
                                width: 3,
                              ),
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
  Widget build(BuildContext context) {
    final outlineBorder = _outLineBorder;
    return IntrinsicHeight(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: SafeArea(
            bottom: true,
            left: false,
            right: false,
            top: false,
            child: Stack(
              children: [
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    if (suggestions.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: widget.sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        margin: const EdgeInsets.only(bottom: 17, right: 0.4, left: 0.4),
                        padding: const EdgeInsets.fromLTRB(leftPadding, leftPadding, leftPadding, 30),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 150),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: suggestions.map((suggestion) {
                                  Widget mediaWidget;
                                  switch (suggestion['media_type']) {
                                    case 'image':
                                      mediaWidget = Image.network(
                                        suggestion['media_url'] ?? '',
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      );
                                      break;
                                    case 'video':
                                      mediaWidget = Icon(Icons.video_call, color: Colors.grey);
                                      break;
                                    case 'audio':
                                      mediaWidget = Icon(Icons.audiotrack, color: Colors.grey);
                                      break;
                                    case 'file':
                                      mediaWidget = Icon(Icons.file_copy_outlined, color: Colors.grey);
                                      break;
                                    default:
                                      mediaWidget = Text(
                                        suggestion['content'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.black, fontSize: 14),
                                      );
                                      break;
                                  }
                                  return ListTile(
                                    contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                                    dense: true,
                                    visualDensity: VisualDensity(horizontal: 0, vertical: -3),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
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
                                        SizedBox(width: 5),
                                        Flexible(child: mediaWidget),
                                      ],
                                    ),
                                    onTap: () async {
                                      if (suggestion['media_url'] != '') {
                                        Future<File> _fileFromImageUrl(image_url) async {
                                          final fileName = image_url.split('/').last;
                                          final response = await http.get(Uri.parse(image_url));
                                          final documentDirectory = await getApplicationDocumentsDirectory();
                                          final file = File(join(documentDirectory.path, fileName));
                                          file.writeAsBytesSync(response.bodyBytes);
                                          return file;
                                        }

                                        String getFileExtension(String fileName) {
                                          return ".${fileName.split('.').last}".toLowerCase();
                                        }

                                        final prefs = await SharedPreferences.getInstance();
                                        final String? uuid = prefs.getString('uuid');
                                        final String? team_alias = prefs.getString('team_alias');
                                        final String? cb_lead_id = prefs.getString('cb_lead_id');
                                        final String? platform = prefs.getString('platform');
                                        final String? conversation_id = prefs.getString('conversation_id');
                                        String url = base_url + 'api/send_image_message/';
                                        Map<String, String> headers = {"Authorization": "$uuid|$team_alias"};

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
                                        if(extension == '.jpg' || extension == '.png' || extension == '.jpeg' || extension == '.gif' || extension == '.bmp' || extension == '.webp'|| extension == '.heic' ||extension == '.heif')
                                        {
                                            media_type = "image";
                                        }
                                        else if(extension == '.mp4' || extension == '.avi' || extension == '.mov' || extension == '.wmv' ||  extension == '.flv' || extension == '.mkv' || extension == '.webm' || extension == '.3gp' || extension == '.m4v' )
                                        {
                                          media_type="video";
                                        }
                                        else if (extension == '.mp3' || extension == '.wav' || extension == '.aac' || extension == '.ogg' || extension == '.opus' || extension == '.m4a' || extension == '.flac' || extension == '.amr' || extension == '.webm' || extension == '.caf' || extension == '.aiff' || extension == '.aif')
                                        {
                                          media_type="audio";
                                        }
                                        

                                        var uploadfile = await _fileFromImageUrl(suggestion['media_url']);
                                        request.files.add(await http.MultipartFile.fromPath('file', uploadfile.path, contentType: MediaType('application', media_type)));
                                        final response = await request.send();
                                        final responseData = await response.stream.toBytes();
                                        final responseString = String.fromCharCodes(responseData);
                                      } else {
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
                    
                    // The rest of your input bar starts here
                    Container(
                          padding: textFieldConfig?.padding ?? const EdgeInsets.symmetric(horizontal: 4), /* new */
                          margin: textFieldConfig?.margin,
                          decoration: BoxDecoration(
                            borderRadius: textFieldConfig?.borderRadius ?? BorderRadius.circular(textFieldBorderRadius),
                            color: sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
                          ),
                          child: ValueListenableBuilder<bool>(
                            valueListenable: isRecording,
                            builder: (context, isRecordingValue, child) {
                              return Row(
                                children: [
                                  if (isRecordingValue && recorderController != null && !kIsWeb)
                                    AudioWaveforms(
                                      size: Size(MediaQuery.of(context).size.width * 0.75, 50),
                                      recorderController: recorderController!,
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
                                        cursorColor: Colors.black,    
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
                                                onPressed: () => _recordOrStop(context),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
    Future<void> _recordOrStop(BuildContext ctx) async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    
    if (!isRecording.value) {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await recorderController?.record(path: filePath); // Pass the path here
      isRecording.value = true;
    } else {
      // Stop recording
      final recordedPath = await recorderController.stop();
      isRecording.value = false;
      
      if (recordedPath != null && recordedPath.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final String? platform = prefs.getString('platform');
        
        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (ctx) => AudioViewerPage(
              fileUrl: recordedPath,
              onSend: (fileUrl, caption) {
                send_file_tap(fileUrl, caption ?? '');
              },
              platform: platform ?? '',
            ),
          ),
        );
      }
    }
  }
   /* Future<void> _recordOrStop(BuildContext ctx) async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    final prefs = await SharedPreferences.getInstance();
    final String? platform = prefs.getString('platform');
   /*  if (!isRecording.value) {
      await controller?.record();
      isRecording.value = true;
    } else {
      final recordedPath = await controller?.stop();
      isRecording.value = false; */
    if (!isRecording.value) {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await recorderController?.record(path: filePath); // Pass the path here
      isRecording.value = true;
    } else {
    final recordedPath = await recorderController?.stop();
    isRecording.value = false;
      
      if (recordedPath != null && recordedPath.isNotEmpty) {
        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (ctx) => AudioViewerPage(
              fileUrl: recordedPath,
              onSend: (fileUrl, caption) {
                send_file_tap(fileUrl, caption??'');
                //widget.onRecordingComplete(fileUrl);
              },
              platform: platform??'',
            ),
          ),
        );
      } else {
        //widget.onRecordingComplete(recordedPath);
      }
    }
  }  */ 
  String getFileExtension(String fileName) 
  {
    return ".${fileName.split('.').last}".toLowerCase();
  }
  void send_file_tap(String filePath, String? message) async {

    if(filePath != '')
    {
      final prefs = await SharedPreferences.getInstance();
      final String? uuid = prefs.getString('uuid');
      final String? team_alias = prefs.getString('team_alias');
      final String? cb_lead_id = prefs.getString('cb_lead_id');
      final String? platform = prefs.getString('platform');
      final String? conversation_id = prefs.getString('conversation_id');
      String url = base_url + 'api/send_image_message/';
      Map<String, String> headers = {"Authorization": "$uuid|$team_alias"};
      
      if (filePath != '' ) {
        var postUri = Uri.parse(url);
        var request = http.MultipartRequest("POST", postUri);
        request.fields['cb_lead_id'] = "$cb_lead_id";
        request.fields['platform'] = "$platform";
        request.fields['message_body'] = message??'';
        request.fields['conversation_id'] = "$conversation_id";
        request.fields['cb_message_source'] = 'android';
        request.headers.addAll(headers);
        String extension = getFileExtension(filePath);
        if(platform=='fb_whatsapp'|| platform=='whatsapp')
        {
          var mime_type = 'image/png';
          if(extension == '.jpg' || extension == '.jpeg')
          {
              mime_type = 'image/jpeg';
          }
          else if(extension == '.png')
          {
              mime_type = 'image/png';
          }
          else if(extension=='.aac'){
              mime_type = 'audio/aac';
          }
          else if(extension=='.amr'){
              mime_type= 'audio/amr';
          }
          else if(extension=='.mp3'){
              mime_type='audio/mpeg';
          }
          else if(extension=='.m4a'){
              mime_type='audio/mp4';
          }
         else if (extension == '.ogg' || extension == '.oga') {
            mime_type = 'audio/ogg';
          }
          else if(extension=='.3gp'){
              mime_type='video/3gpp';
          }
          else if(extension=='.mp4'){
              mime_type='video/mp4';
          }
          else if(extension=='.txt'){
            mime_type='text/plain';
          }
          else if(extension=='.xls'){
              mime_type='application/vnd.ms-excel';
          }
          else if(extension=='.xlsx'){
              mime_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          }
          else if(extension=='.doc'){
              mime_type='application/msword';
          }
          else if(extension=='.docx'){
              mime_type='application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          }
          else if(extension=='.ppt'){
            mime_type='application/vnd.ms-powerpoint';
          }
          else if(extension=='.pptx'){
            mime_type='application/vnd.openxmlformats-officedocument.presentationml.presentation';
          }
          else if (extension=='.pdf'){
            mime_type='application/pdf';
          }
          print("mime_type   $mime_type");
          final mimeParts = mime_type.split('/');
          request.files.add(await http.MultipartFile.fromPath('file', filePath, contentType: MediaType(mimeParts[0], mimeParts[1])));
        }
        else{
          
          String media_type = "file";
        
          if (extension == '.jpg' || extension == '.png' || extension == '.jpeg' || extension == '.gif' || extension == '.bmp' || extension == '.webp' || extension == '.heic' || extension == '.heif' || extension == '.svg' || extension == '.tiff' || extension == '.tif' || extension == '.ico' || extension == '.raw')
          {
              media_type = "image";
          }
          else if (extension == '.mp4' || extension == '.avi' || extension == '.mov' || extension == '.wmv' || extension == '.flv' || extension == '.mkv' || extension == '.webm' || extension == '.3gp' || extension == '.m4v' || extension == '.ts' || extension == '.mts' || extension == '.m2ts')
          {
            media_type = "video";
          }
          else if (extension == '.mp3' || extension == '.wav' || extension == '.aac' || extension == '.oga' || extension == '.ogg' || extension == '.opus' || extension == '.m4a' || extension == '.flac' || extension == '.amr' || extension == '.wma' || extension == '.caf' || extension == '.aiff' || extension == '.aif' || extension == '.mid' || extension == '.midi' || extension == '.3ga')
          {
            media_type = "audio";
          }
          request.files.add(await http.MultipartFile.fromPath('file', filePath, contentType: MediaType('application', media_type)));
        }  
        final response = await request.send();
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        /* if(widget.status=='Unassigned'){
          setState(() {
            postrequeststatus('open','Open');
            String? userId = prefs.getString('user_id');
            String? user_name=prefs.getString('name');
            postrequestagent(userId,user_name);
          });
        } */
      }
      setState(() {
        filePath='';
      });
    }
  }
  

void _showCustomNotification(BuildContext context) {
  OverlayEntry? overlayEntry;
  
  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35), 
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        'Unsupported File Format',
                        style: TextStyle(
                          fontWeight: FontWeight.w300,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'The selected format is not supported by WhatsApp.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () {
                  if (overlayEntry != null && overlayEntry!.mounted) {
                    overlayEntry!.remove();
                    overlayEntry = null; // Clear the reference
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  
  Overlay.of(context).insert(overlayEntry!);
  
  // Auto remove after 5 seconds with null check
  Future.delayed(Duration(seconds: 5), () {
    if (overlayEntry != null && overlayEntry!.mounted) {
      overlayEntry!.remove();
      overlayEntry = null;
    }
  });
}
void _onIconPressed(
  BuildContext ctx,
  ImageSource imageSource, {
  ImagePickerConfiguration? config,
}) async {
  try {
    // Get platform and page from SharedPreferences BEFORE picking image
    final prefs = await SharedPreferences.getInstance();
    final String? platform = prefs.getString('platform');
    final String? page = prefs.getString('page');
    
    // Check if WhatsApp format validation is needed
    bool needsWhatsAppValidation = page == 'chat' && 
                                    (platform == 'fb_whatsapp' || platform == 'whatsapp');
    
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
      // Validate WhatsApp image format after selection
      if (needsWhatsAppValidation) {
        String lowerPath = imagePath.toLowerCase();
        
        // WhatsApp only supports JPG, JPEG, PNG for images
        if (!lowerPath.endsWith('.jpg') && 
            !lowerPath.endsWith('.jpeg') && 
            !lowerPath.endsWith('.png')) {
           _showCustomNotification(ctx);
          
          return; 
        }
      }
      
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (context) => ImageViewerPage(
            imagePath: imagePath ?? '',
            onSend: (sentImagePath, message) {
              widget.onImageSelected(sentImagePath, '', message ?? ''); 
            },
            padding: EdgeInsets.fromLTRB(
              bottomPadding4,
              bottomPadding4,
              bottomPadding4,
              bottomPadding4
            ),
          ),
        ),
      );
    }
  } catch (e) {
    widget.onImageSelected('', e.toString(), '');
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
  
  @override
  void initState() {
    super.initState();

  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }



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

class AudioViewerPage extends StatefulWidget {
  final String fileUrl;
  final Function(String, String?) onSend;
  final String platform; 

  const AudioViewerPage({Key? key, required this.fileUrl, required this.onSend,required this.platform,}) : super(key: key);

  @override
  _AudioViewerPageState createState() => _AudioViewerPageState();
}

class _AudioViewerPageState extends State<AudioViewerPage> {
  final TextEditingController _messageController = TextEditingController();
  late audio.AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;
  bool _isInitialized = false;
  int? _fileSize;
  bool _hasCompleted = false;
  late bool _hideCaption;

  @override
  void initState() {
    super.initState();
    _hideCaption = widget.platform == 'fb_whatsapp' || 
                   widget.platform == 'whatsapp';
    _audioPlayer = audio.AudioPlayer();
    _initAudioPlayer();
    _getFileSize();
  }

  Future<void> _initAudioPlayer() async {
    try {
      // Stop any existing playback
      await _audioPlayer.stop();
      
      // Reset state
      setState(() {
        _isLoading = true;
        _isPlaying = false;
        _position = Duration.zero;
        _duration = Duration.zero;
      });

      // Set up listeners
      _audioPlayer.onPlayerStateChanged.listen((audio.PlayerState state) {
        setState(() {
          _isPlaying = state == audio.PlayerState.playing;
        });
      });

      _audioPlayer.onDurationChanged.listen((Duration duration) {
        setState(() {
          _duration = duration;
          _isLoading = false;
        });
      });

      _audioPlayer.onPositionChanged.listen((Duration position) {
        setState(() {
          _position = position;
        });
      });

      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _hasCompleted = true; // Set completion flag
        });
      });

      // Load audio file
      await _audioPlayer.setSource(audio.DeviceFileSource(widget.fileUrl));
      _isInitialized = true;
    } catch (e) {
      print('Error initializing audio player: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _playPause() async {
    if (!_isInitialized) {
      await _initAudioPlayer();
    }
    
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      // If audio has completed, treat this as a replay
      if (_hasCompleted) {
        await _replayAudio();
        setState(() {
          _hasCompleted = false; // Reset completion flag
        });
      } else {
        // Normal resume
        if (_position >= _duration - Duration(milliseconds: 100) || _duration == Duration.zero) {
          await _audioPlayer.seek(Duration.zero);
        }
        await _audioPlayer.resume();
      }
    }
  }
  Future<void> _seekAudio(double value) async {
    if (!_isInitialized) return;
    
    final position = Duration(milliseconds: (value * _duration.inMilliseconds).round());
    await _audioPlayer.seek(position);
  }

  Future<void> _replayAudio() async {
    if (!_isInitialized) return;
    
    await _audioPlayer.stop();
    await _audioPlayer.setSource(audio.DeviceFileSource(widget.fileUrl));
    await _audioPlayer.resume();
  }
  Future<void> _getFileSize() async {
    try {
      final file = File(widget.fileUrl);
      final exists = await file.exists();
      if (exists) {
        final stat = await file.stat();
        setState(() {
          _fileSize = stat.size;
        });
      }
    } catch (e) {
      print('Error getting file size: $e');
    }
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }
  
  String _getFileSizeText() {
    if (_fileSize == null) return '';
    
    if (_fileSize! < 1024) {
      return '${_fileSize} B';
    } else if (_fileSize! < 1024 * 1024) {
      return '${(_fileSize! / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(_fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Audio Preview', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Audio file name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        p.basename(widget.fileUrl),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Audio file size
                    if (_fileSize != null)
                      Text(
                        'File size: ${_getFileSizeText()}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 20),
                    
                    // Audio player controls
                    _isLoading 
                        ? const CircularProgressIndicator(color: Colors.blue)
                        : Column(
                          children: [
                            // Progress bar
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.blue,
                                inactiveTrackColor: Colors.grey[700],
                                trackHeight: 4.0,
                                thumbColor: Colors.blue,
                                overlayColor: Colors.blue.withAlpha(32),
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                              ),
                              child: Slider(
                                value: _duration.inMilliseconds == 0 
                                    ? 0 
                                    : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0),
                                onChanged: _seekAudio,
                                onChangeEnd: _seekAudio,
                              ),
                            ),
                            
                            // Time indicators
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_position),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(_duration),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: _playPause,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _hasCompleted 
                                      ? Icons.replay  // Show replay icon when completed
                                      : (_isPlaying ? Icons.pause : Icons.play_arrow), // Show play/pause otherwise
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            
                          ],
                        ),
                  ],
                ),
              ),
            ),
          ),
          if (!_hideCaption) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 4),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      widget.onSend(widget.fileUrl, _messageController.text.trim());
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
           ]else...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Pass empty string as caption for WhatsApp
                        widget.onSend(widget.fileUrl, '');
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(Icons.send, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
           ]
        ],
      ),
    );
  }
}


