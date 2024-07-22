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
/* import 'package:path_provider/path_provider.dart'; */
import 'dart:io';

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
  

  @override
  State<ChatUITextField> createState() => _ChatUITextFieldState();
}

class _ChatUITextFieldState extends State<ChatUITextField> {
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
  }
  @override
  void dispose() {
    debouncer.dispose();
    composingStatus.dispose();
    isRecording.dispose();
    _inputText.dispose();
    _suggestionOverlay?.remove();
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

    print(shortcode);
    final prefs = await SharedPreferences.getInstance();
    final String? uuid = prefs.getString('uuid');
    final url ='https://chatmaxima.com/api/canned_responses/';
    var headers = {
      'Authorization': '$uuid',
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
      /* print(responseBody); */
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

  @override
  Widget build(BuildContext context) 
  {
    return IntrinsicHeight
    (
     child: Align
     (
        alignment: Alignment.bottomCenter,
        child: SizedBox
        (
          width: MediaQuery.of(context).size.width,
          child: Stack
          (
            children: 
            [
              Positioned
              (
                right: 0,
                left: 0,
                bottom: 0,
                child: Container(
                  height: MediaQuery.of(context).size.height / ((!kIsWeb && Platform.isIOS) ? 24 : 28),
                  color: widget.sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(bottomPadding4,
                      bottomPadding4,
                      bottomPadding4,
                      bottomPadding4),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    if (suggestions.isNotEmpty)
                      Container(
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
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: 150,
                            ),
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
                                   return ListTile(
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
                                          /* child:Text
                                          (
                                            suggestion['short_code']?.isNotEmpty == true ? suggestion['short_code']! : 'No Shortcode',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ), */
                                        ),
                                        SizedBox(width: 5,),
                                        Flexible(
                                          child: mediaWidget,
                                        ),
                                         /* if (suggestion['content'] != null && suggestion['content']!="")
                                          Flexible(
                                            child: Text(
                                              suggestion['content']??'',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ), */
                                         /* if (suggestion['content'] != null && suggestion['content']!="") ...[
                                          Flexible(
                                            child: Text(
                                              suggestion['content']??'Nothing to Suggest',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ], */
                                      ],
                                    ),
                                    onTap: () async{
                                      widget.textEditingController.text = suggestion['content'] ?? '';
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
                        padding: textFieldConfig?.padding ?? const EdgeInsets.symmetric(horizontal: 4),
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
                                  builder: (_, inputTextValue, child) {
                                    if (inputTextValue.isNotEmpty ) {
                                      return IconButton(
                                        color: sendMessageConfig?.defaultSendButtonColor ?? Colors.green,
                                        onPressed: () {
                                          widget.onPressed();
                                          _inputText.value = '';
                                        },
                                        icon: sendMessageConfig?.sendButtonIcon ?? const Icon(Icons.send),
                                      );
                                    } else {
                                      return Row(
                                        children: [
                                          if (!isRecordingValue) ...[
                                            if (sendMessageConfig?.enableCameraImagePicker ?? true)
                                              IconButton(
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _onIconPressed(
                                                  ImageSource.camera,
                                                  config: sendMessageConfig?.imagePickerConfiguration,
                                                ),
                                                icon: imagePickerIconsConfig?.cameraImagePickerIcon ?? Icon(
                                                  Icons.camera_alt_outlined,
                                                  color: imagePickerIconsConfig?.cameraIconColor,
                                                ),
                                              ),
                                            if (sendMessageConfig?.enableGalleryImagePicker ?? true)
                                              IconButton(
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _onIconPressed(
                                                  ImageSource.gallery,
                                                  config: sendMessageConfig?.imagePickerConfiguration,
                                                ),
                                                icon: imagePickerIconsConfig?.galleryImagePickerIcon ?? Icon(
                                                  Icons.image,
                                                  color: imagePickerIconsConfig?.galleryIconColor,
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
                ),
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
 /*  Future<void> download_convert_path(String url) async 
 {
  try 
  {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) 
    {
      final cache_dir = await getApplicationCacheDirectory();
      final file_name = url.split('/').last;
      final image = File('${cache_dir.path}/$file_name');
       await image.writeAsBytes(response.bodyBytes);
      print("DOWNLOAD CACHE");
      print(image.path);
      ImagePickerConfiguration? config;
        String imagePath = image.path;
        if (config?.onImagePicked != null) {
          String? updatedImagePath = await config?.onImagePicked!(imagePath);
          if (updatedImagePath != null) imagePath = updatedImagePath;
        }
      widget.onImageSelected(imagePath,'');
    } 
    else 
    {
      throw Exception('Failed to download image: ${response.statusCode}');
    }
  } 
  catch (e) 
  {
    print('Error downloading image: $e');
    widget.onImageSelected('', 'Error downloading image');
  }
} */
  void _onIconPressed(
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
      print("SELECTED IMAGE ");
      print(imagePath);
      if (config?.onImagePicked != null) {
        String? updatedImagePath = await config?.onImagePicked!(imagePath);
        if (updatedImagePath != null) imagePath = updatedImagePath;
      }
      widget.onImageSelected(imagePath ?? '', '');
    } catch (e) {
      widget.onImageSelected('', e.toString());
    }
  }
  
  void _onChanged(String inputText) async 
  {
    if (inputText.startsWith('/')) 
    {
      final canned_response = await fetch_canned_responses(inputText.substring(1));
      print("CANNED_ RESPONSES");
      print(canned_response);
      setState(() {
        if (inputText.substring(1).isEmpty){
          suggestions=[{
            "short_code": "Enter the shortcode",
            "content": "",
            "media_type": "",
            "media_url": ""
          }];
        }
        else if (canned_response.isEmpty) 
        {
          suggestions = [
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
    } else {
      _removeSuggestionOverlay();
      setState(() {
        suggestions = [];
      });
    }
    if(inputText.isEmpty){
      _inputText.value='';
    }else{
      _inputText.value=inputText;
    }
    debouncer.run(() {
      composingStatus.value = TypeWriterStatus.typed;
    }, () {
      composingStatus.value = TypeWriterStatus.typing;
    });
  }
}