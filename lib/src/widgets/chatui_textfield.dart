
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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'socket_manager.dart';
import 'send_message_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'max_ia_prompt_dialog.dart';
import 'max_ia_response_bottom_sheet.dart';

class ChatUITextField extends StatefulWidget {
  const ChatUITextField({
    Key? key,
    this.sendMessageConfig,
    this.autofocus = false,
    required this.textEditingController,
    required this.onPressed,
    required this.onRecordingComplete,
    required this.onImageSelected,
    required this.onAIPressed,
    required this.messageController,
    required this.ai_send_pressed,
    this.onAIStreamingResponse,
  }) : super(key: key);

  final SendMessageConfiguration? sendMessageConfig;
  final TextEditingController textEditingController;
  final Function(String)? onAIStreamingResponse;
  final VoidCallBack onPressed;
  final Function(String?) onRecordingComplete;
  final StringsCallBack onImageSelected;
  final bool autofocus;
  final VoidCallBack onAIPressed;
  final TextEditingController messageController;
  final VoidCallBack ai_send_pressed;

  @override
  State<ChatUITextField> createState() => _ChatUITextFieldState();
}

class _ChatUITextFieldState extends State<ChatUITextField>
    with WidgetsBindingObserver {
  final ValueNotifier<String> _inputText = ValueNotifier('');
  final ImagePicker _imagePicker = ImagePicker();
  late final RecorderController recorderController;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  String _timerText = "00:00";
  ValueNotifier<bool> isRecording = ValueNotifier(false);
  
  // Add this flag to track if widget is still mounted
  bool _isMounted = false;

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

  bool _isDisposed = false;

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
  final ValueNotifier<bool> _isLoadingAI = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    WidgetsBinding.instance.addObserver(this);
    attachListeners();
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      recorderController = RecorderController()
        ..androidEncoder = AndroidEncoder.aac
        ..androidOutputFormat = AndroidOutputFormat.mpeg4
        ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
        ..sampleRate = 16000;
    }
    debouncer = Debouncer(
        sendMessageConfig?.textFieldConfig?.compositionThresholdTime ??
            const Duration(seconds: 1));
    _loadPreferences();
  }

  @override
  void didUpdateWidget(ChatUITextField oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  void _startTimer() {
    _recordingTimer?.cancel();
    _recordingSeconds = 0;
    _updateTimerText();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isMounted || _isDisposed) {
        timer.cancel();
        return;
      }
      _recordingSeconds++;
      _updateTimerText();
    });
  }

  void _updateTimerText() {
    if (_isDisposed || !_isMounted) return;
    final minutes = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingSeconds % 60).toString().padLeft(2, '0');
    if (_isMounted) {
      setState(() => _timerText = "$minutes:$seconds");
    }
  }

  void _stopTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingSeconds = 0;
    if (_isMounted && !_isDisposed) {
      setState(() => _timerText = "00:00");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopRecordingIfActive();
    }
  }

  Future<void> _stopRecordingIfActive() async {
    if (isRecording.value) {
      try {
        await recorderController.stop();
        isRecording.value = false;
      } catch (e) {
        isRecording.value = false;
      }
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_isDisposed && _isMounted) {
      current_page = prefs.getString('page') ?? '';
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    _isDisposed = true;
    debouncer.dispose();
    composingStatus.dispose();
    isRecording.dispose();
    _inputText.dispose();
    _isSendEnabled.dispose();
    _isLoadingAI.dispose();
    recorderController.stop();
    WidgetsBinding.instance.removeObserver(this);
    _stopRecordingIfActive();
    _suggestionOverlay?.remove();
    _suggestionOverlay = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('conversation_id');
      prefs.remove('ticket_id');
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

  Future<List<Map<String, String>>> fetch_canned_responses(
      String? shortcode) async {
    if (shortcode == null) return Future.value([]);
    final prefs = await SharedPreferences.getInstance();
    final String? uuid = prefs.getString('uuid');
    final String? team_alias = prefs.getString('team_alias');
    final url = base_url + 'api/canned_responses/';
    var headers = {
      'Authorization': '$uuid|$team_alias',
      'Content-Type': 'application/json',
    };
    var request = http.Request('POST', Uri.parse(url));
    request.body =
        json.encode({"short_code": shortcode, "source": "mobileapp"});
    request.headers.addAll(headers);
    http.StreamedResponse response = await request.send();
    if (response.statusCode == 200) {
      String responseBody = await response.stream.bytesToString();
      Map<String, dynamic> decodedResponse = json.decode(responseBody);
      if (decodedResponse.containsKey('data') &&
          decodedResponse['data'] != null) {
        List<Map<String, String>> todos = (decodedResponse['data'] as List)
            .map((item) => {
                  "short_code": item['short_code'].toString(),
                  "content": item['content'].toString(),
                  "media_type": item['media_type']?.toString() ?? '',
                  "media_url": item['media_url']?.toString() ?? '',
                })
            .toList();
        return todos;
      } else {
        return [];
      }
    } else if (response.statusCode == 404) {
      return Future.value([]);
    } else {
      return [];
    }
  }

  void _removeSuggestionOverlay() {
    _suggestionOverlay?.remove();
    _suggestionOverlay = null;
  }

  Future<String> call_ai_assist(BuildContext context, String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? uuid = prefs.getString('uuid');
      final String? team_alias = prefs.getString('team_alias');
      final url = base_url + 'api/reply/';
      final String? conversation_id = prefs.getString('conversation_id');
      final String? cb_lead_name = prefs.getString('cb_lead_name');
      final String? ticket_id = prefs.getString('ticket_id');
      final String? ticket_name = prefs.getString('ticket_name');
      final String? page = prefs.getString('page');

      String source;
      String? alias;
      String? from_name;

      if (page == 'chat') {
        source = "chat";
        alias = conversation_id;
        from_name = cb_lead_name;
      } else {
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
          "response_mode": 'streaming',
          "ref_element": "button"
        }
      });
      request.headers.addAll(headers);
      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        Map<String, dynamic> decodedResponse = json.decode(responseBody);
        if (decodedResponse['success'] == 'false') {
          throw Exception(decodedResponse['ai_error_message'] ??
              'Failed to generate AI response');
        } else {
          var aiResponse = json.decode(decodedResponse['ai_response']);
          try {
            if (source == "ticket") {
              var decodedAnswer = json.decode(aiResponse['answer']);
              if (decodedAnswer is Map &&
                  decodedAnswer.containsKey('response')) {
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
        throw Exception("Failed to generate AI response");
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> sendMessage(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cb_lead_id = prefs.getString('cb_lead_id');
    final String? platform = prefs.getString('platform');
    final String? conversation_id = prefs.getString('conversation_id');
    Map<String, dynamic> data = {
      "cb_lead_id": cb_lead_id,
      "platform": platform,
      "message_body": message,
      "conversation_id": conversation_id,
      "cb_message_source": 'android',
      "reply_message_id": '',
    };
    String jsonData = json.encode(data);
    final String? uuid = prefs.getString('uuid');
    final String? team_alias = prefs.getString('team_alias');
    String url = base_url + 'api/send_message/';
    await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "$uuid|$team_alias",
      },
      body: jsonData,
    );
  }

  Future<void> send_ticket_Message(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final String? ticket_id = prefs.getString('ticket_id');
    Map<String, dynamic> data = {
      "ticket_alias": ticket_id,
      "message_body": message,
      "source": 'mobileapp'
    };
    String jsonData = json.encode(data);
    final String? uuid = prefs.getString('uuid');
    final String? team_alias = prefs.getString('team_alias');
    String url = base_url + 'api/ticket/response/';
    await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "$uuid|$team_alias"
      },
      body: jsonData,
    );
  }

  /* Future<List<Map<String, String>>> fetch_ai_languages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? uuid = prefs.getString('uuid');
      final String? team_alias = prefs.getString('team_alias');
      final url = base_url + 'api/v2/ai/languages/';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$uuid|$team_alias',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final List<Map<String, String>> languages = [];
          for (var lang in data['data']) {
            languages.add({
              'code': lang['language_code']?.toString() ?? '',
              'name': lang['language_name']?.toString() ?? '',
            });
          }
          await prefs.setString('cached_ai_languages', json.encode(languages));
          return languages;
        }
      }
    } catch (e) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_ai_languages');
      if (cached != null) {
        final List<dynamic> decoded = json.decode(cached);
        return decoded
            .map<Map<String, String>>((item) => {
                  'code': item['code']?.toString() ?? '',
                  'name': item['name']?.toString() ?? '',
                })
            .toList();
      }
    } catch (e) {}
    return [
      {'code': 'en', 'name': 'English'},
      {'code': 'es', 'name': 'Spanish'},
      {'code': 'fr', 'name': 'French'},
      {'code': 'de', 'name': 'German'},
      {'code': 'it', 'name': 'Italian'},
      {'code': 'pt', 'name': 'Portuguese'},
      {'code': 'ru', 'name': 'Russian'},
      {'code': 'ja', 'name': 'Japanese'},
      {'code': 'ko', 'name': 'Korean'},
      {'code': 'zh', 'name': 'Chinese'},
      {'code': 'ar', 'name': 'Arabic'},
      {'code': 'hi', 'name': 'Hindi'},
      {'code': 'nl', 'name': 'Dutch'},
      {'code': 'pl', 'name': 'Polish'},
      {'code': 'tr', 'name': 'Turkish'},
      {'code': 'vi', 'name': 'Vietnamese'},
      {'code': 'th', 'name': 'Thai'},
      {'code': 'sw', 'name': 'Swahili'},
    ];
  }  */

  Future<String> call_ai_translate(String text, String target_language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? uuid = prefs.getString('uuid');
      final String? team_alias = prefs.getString('team_alias');
      final url = base_url + 'api/v2/ai/translate/';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$uuid|$team_alias',
        },
        body: json.encode({
          'text': text,
          'target_language': target_language,
        }),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return data['data']['translated_text'] ?? text;
        }
        throw Exception('Translation failed');
      }
      try {
        final errData = json.decode(response.body);
        final message = errData['error']?['message']?.toString();
        throw Exception(message ?? 'Translation failed');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Translation failed');
      }
    } catch (e) {
      rethrow;
    }
  }
  Future<List<Map<String, String>>> fetch_ai_languages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? uuid = prefs.getString('uuid');
      final String? team_alias = prefs.getString('team_alias');
      final url = base_url + 'api/v2/ai/languages/';
      
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$uuid|$team_alias',
        },
      ).timeout(const Duration(seconds: 10));
    
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final List<Map<String, String>> languages = [];
          for (var lang in data['data']) {
            languages.add({
              'code': lang['language_code']?.toString() ?? '',
              'name': lang['language_name']?.toString() ?? '',
            });
          }
          await prefs.setString('cached_ai_languages', json.encode(languages));
          return languages;
        }
      }
    } catch (e) {
      print('Error fetching languages: $e');
    }
    
    // Return cached languages or default
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_ai_languages');
      if (cached != null) {
        final List<dynamic> decoded = json.decode(cached);
        final languages = decoded.map<Map<String, String>>((item) => {
          'code': item['code']?.toString() ?? '',
          'name': item['name']?.toString() ?? '',
        }).toList();
        return languages;
      }
    } catch (e) {
      print('Error loading cached languages: $e');
    }
    
    return [
      {'code': 'en', 'name': 'English'},
      {'code': 'es', 'name': 'Spanish'},
      {'code': 'fr', 'name': 'French'},
      {'code': 'de', 'name': 'German'},
      {'code': 'it', 'name': 'Italian'},
      {'code': 'pt', 'name': 'Portuguese'},
      {'code': 'ru', 'name': 'Russian'},
      {'code': 'ja', 'name': 'Japanese'},
      {'code': 'ko', 'name': 'Korean'},
      {'code': 'zh', 'name': 'Chinese'},
      {'code': 'ar', 'name': 'Arabic'},
      {'code': 'hi', 'name': 'Hindi'},
      {'code': 'nl', 'name': 'Dutch'},
      {'code': 'pl', 'name': 'Polish'},
      {'code': 'tr', 'name': 'Turkish'},
      {'code': 'vi', 'name': 'Vietnamese'},
      {'code': 'th', 'name': 'Thai'},
      {'code': 'sw', 'name': 'Swahili'},
    ];
  }
  
  void _showMaxIAPromptDialog(BuildContext outerContext, String inputText) {
    if (_isDisposed || !_isMounted) return;
    
    showDialog(
      context: outerContext,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) => MaxIAPromptDialog(
        typedText: inputText, // Pass the input text to the dialog
        onGenerate: (promptText) {
          // When user clicks generate, show the bottom sheet with API calls
          _showMaxIAResponseSheet(outerContext, promptText);
        },
      ),
    );
  }
  
  void _showMaxIAResponseSheet(BuildContext outerContext, String promptText) async {
    if (_isDisposed || !_isMounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed || !_isMounted) return;

    final bool isChatPage = prefs.getString('page') == 'chat';
    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      useRootNavigator: true,
      builder: (BuildContext sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: MaxIAResponseBottomSheet(
          promptText: promptText,
          aiAssistCall: (text) => call_ai_assist(outerContext, text),
          fetchLanguagesCall: fetch_ai_languages,
          translateCall: (text, lang) => call_ai_translate(text, lang),
          onSendPressed: () {
            if (_isDisposed || !_isMounted) return;
            final text = widget.messageController.text;
            if (text.trim().isEmpty) return;
            widget.textEditingController.text = text;
            _inputText.value = text;
            widget.onPressed();
            // Clear both controllers after send
            widget.messageController.clear();
            _inputText.value = '';
          },
          /* onSendPressed: () {
            if (_isDisposed || !_isMounted) return;
            final text = widget.messageController.text.trim();
            if (text.isEmpty) return;

            // Just populate the visible input field — do NOT send
            widget.textEditingController.text = text;
            _inputText.value = text;

            // Place cursor at end
            widget.textEditingController.selection = TextSelection.fromPosition(
              TextPosition(offset: text.length),
            );

            // Clean up the AI controller
            widget.messageController.clear();
          }, */
          messageController: widget.messageController,
          sendEnabledNotifier: _isSendEnabled,
          loadingAINotifier: _isLoadingAI,
          isChatPage: isChatPage,
        ),
      ),
    );
  }
  Widget _buildLoadingShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const _PulsingDots(),
            const SizedBox(width: 10),
            Text(
              'Generating response...',
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF6366F1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...[0.95, 1.0, 0.78, 1.0, 0.62, 0.88, 0.45].map(
          (w) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ShimmerLine(widthFactor: w),
          ),
        ),
      ],
    );
  }

  Future<String?> _validateFileForPlatform(
      String fileUrl, String platform, String page) async {
    if (page != 'chat') return null;
    String extension = ".${fileUrl.split('.').last}".toLowerCase();
    if (platform == 'fb_whatsapp' || platform == 'whatsapp') {
      if (['.jpg', '.jpeg', '.png', '.mp4', '.3gp', '.aac', '.amr', '.mp3',
           '.m4a', '.ogg', '.oga', '.txt', '.xls', '.xlsx', '.doc', '.docx',
           '.ppt', '.pptx', '.pdf'].contains(extension)) return null;
      return 'WhatsApp does not support this file format.';
    } else if (platform == 'instagram' || platform == 'Instagram') {
      if (['.jpeg', '.png', '.jpg', '.mp4', '.mov', '.ogg', '.avi', '.webm',
           '.wav', '.aac', '.m4a'].contains(extension)) return null;
      return 'Instagram does not support this file format.';
    } else if (platform == 'telegram' || platform == 'Telegram') {
      if (['.png', '.jpeg', '.jpg', '.gif', '.webp', '.bmp', '.mp4', '.avi',
           '.mov', '.mkv', '.webm', '.mp3', '.ogg', '.opus', '.m4a', '.flac',
           '.txt', '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt',
           '.pptx'].contains(extension)) return null;
      return 'Telegram does not support this file format.';
    } else if (platform == 'facebook' || platform == 'Facebook') {
      if (['.png', '.jpeg', '.jpg', '.gif', '.mp4', '.mov', '.avi', '.mkv',
           '.webm', '.mp3', '.m4a', '.ogg'].contains(extension)) return null;
      return 'Facebook does not support this file format.';
    }
    return null;
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    if (!_isMounted || _isDisposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(fontSize: 14, color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFFFF6B35),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  bool _isFileSupportedForPlatform(
      String fileUrl, String platform, String page) {
    if (page != 'chat') return true;
    String extension = ".${fileUrl.split('.').last}".toLowerCase();
    if (platform == 'fb_whatsapp' || platform == 'whatsapp') {
      return ['.jpg', '.jpeg', '.png', '.mp4', '.3gp', '.aac', '.amr', '.mp3',
              '.m4a', '.ogg', '.oga', '.txt', '.xls', '.xlsx', '.doc', '.docx',
              '.ppt', '.pptx', '.pdf'].contains(extension);
    } else if (platform == 'instagram' || platform == 'Instagram') {
      return ['.jpeg', '.png', '.jpg', '.mp4', '.mov', '.avi', '.webm', '.wav',
              '.aac', '.m4a'].contains(extension);
    } else if (platform == 'telegram' || platform == 'Telegram') {
      return ['.png', '.jpeg', '.jpg', '.gif', '.webp', '.bmp', '.mp4', '.avi',
              '.mov', '.mkv', '.webm', '.mp3', '.ogg', '.opus', '.m4a', '.txt',
              '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt',
              '.pptx'].contains(extension);
    } else if (platform == 'facebook' || platform == 'Facebook') {
      return ['.png', '.jpeg', '.jpg', '.gif', '.mp4', '.mov', '.avi', '.mkv',
              '.webm', '.mp3', '.m4a', '.ogg'].contains(extension);
    }
    return true;
  }

  void send_file_canned_responses(
      BuildContext context, String filePath, String? message) async {
    if (filePath == '') return;
    final prefs = await SharedPreferences.getInstance();
    final String? platform = prefs.getString('platform');
    final String? page = prefs.getString('page');
    String? validationError =
        await _validateFileForPlatform(filePath, platform ?? '', page ?? '');
    if (validationError != null) {
      _showErrorSnackbar(context, validationError);
      return;
    }
    final String? uuid = prefs.getString('uuid');
    final String? team_alias = prefs.getString('team_alias');
    final String? cb_lead_id = prefs.getString('cb_lead_id');
    final String? conversation_id = prefs.getString('conversation_id');
    String url = base_url + 'api/send_image_message/';
    Map<String, String> headers = {"Authorization": "$uuid|$team_alias"};
    var postUri = Uri.parse(url);
    var request = http.MultipartRequest("POST", postUri);
    request.fields['cb_lead_id'] = cb_lead_id ?? '';
    request.fields['platform'] = platform ?? '';
    request.fields['message_body'] = message ?? '';
    request.fields['conversation_id'] = conversation_id ?? '';
    request.fields['cb_message_source'] = 'android';
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    try {
      final response = await request.send();
      if (response.statusCode != 200) {
        _showErrorSnackbar(context, 'Failed to send file. Please try again.');
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Failed to send file. Please try again.');
    }
    if (_isMounted && !_isDisposed) setState(() {});
  }

  void _showCustomNotification(BuildContext context, String message) {
    if (!_isMounted || _isDisposed) return;
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 20,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFFF6B35),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10)
                ]),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Unsupported File Format',
                          style: TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: 16,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(message,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () {
                    if (overlayEntry != null && overlayEntry!.mounted) {
                      overlayEntry!.remove();
                      overlayEntry = null;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(overlayEntry!);
    Future.delayed(const Duration(seconds: 5), () {
      if (overlayEntry != null && overlayEntry!.mounted) {
        overlayEntry!.remove();
        overlayEntry = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick Replies
        if (suggestions.isNotEmpty)
          Container(
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14), bottom: Radius.circular(14)),
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text('Quick Replies',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                ),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = suggestions[index];
                      Widget? trailingWidget;
                      Widget? contentWidget;

                      switch (suggestion['media_type']) {
                        case 'image':
                          trailingWidget = Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.grey.shade200),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                  suggestion['media_url'] ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.image,
                                      color: Colors.grey,
                                      size: 14)),
                            ),
                          );
                          break;
                        default:
                          contentWidget = Text(
                            suggestion['content'] ?? '',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                height: 1.3),
                          );
                          trailingWidget = const Icon(
                              Icons.subdirectory_arrow_left,
                              color: Colors.black,
                              size: 14);
                          break;
                      }

                      if (suggestion['media_url'] == null ||
                          suggestion['media_url']!.isEmpty) {
                        return InkWell(
                          onTap: () {
                            widget.textEditingController.text =
                                suggestion['content'] ?? '';
                            _inputText.value = suggestion['content'] ?? '';
                            if (_isMounted && !_isDisposed) {
                              setState(() => suggestions = []);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 0.5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        suggestion['short_code'] ??
                                            'No Shortcode',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF1E88E5)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (contentWidget != null) ...[
                                        const SizedBox(height: 2),
                                        contentWidget,
                                      ],
                                    ],
                                  ),
                                ),
                                if (trailingWidget != null) ...[
                                  const SizedBox(width: 12),
                                  trailingWidget,
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      return FutureBuilder<Map<String, dynamic>>(
                        future: SharedPreferences.getInstance().then((prefs) {
                          final platform =
                              prefs.getString('platform') ?? '';
                          final page = prefs.getString('page') ?? '';
                          final isSupported = _isFileSupportedForPlatform(
                              suggestion['media_url']!, platform, page);
                          return {
                            'isSupported': isSupported,
                            'platform': platform
                          };
                        }),
                        builder: (context, snapshot) {
                          bool isSupported =
                              snapshot.data?['isSupported'] ?? true;
                          String platform =
                              snapshot.data?['platform'] ?? '';
                          return InkWell(
                            onTap: isSupported
                                ? () async {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    final String? platform =
                                        prefs.getString('platform');
                                    final String? page =
                                        prefs.getString('page');
                                    String? validationError =
                                        await _validateFileForPlatform(
                                            suggestion['media_url'] ?? '',
                                            platform ?? '',
                                            page ?? '');
                                    if (validationError != null) {
                                      _showErrorSnackbar(
                                          context, validationError);
                                      return;
                                    }
                                    try {
                                      final fileName =
                                          suggestion['media_url']!
                                              .split('/')
                                              .last;
                                      final response = await http.get(Uri
                                          .parse(suggestion['media_url']!));
                                      if (response.statusCode == 200) {
                                        final documentDirectory =
                                            await getApplicationDocumentsDirectory();
                                        final file = File(p.join(
                                            documentDirectory.path,
                                            fileName));
                                        await file.writeAsBytes(
                                            response.bodyBytes);
                                        send_file_canned_responses(
                                            context, file.path, '');
                                        widget.textEditingController.clear();
                                        _inputText.value = '';
                                      } else {
                                        widget.textEditingController.clear();
                                        _inputText.value = '';
                                      }
                                    } catch (e) {
                                      widget.textEditingController.clear();
                                      _inputText.value = '';
                                      _showErrorSnackbar(context,
                                          'Failed to download media. Please try again.');
                                    }
                                    if (_isMounted && !_isDisposed) {
                                      setState(() {
                                        suggestions = [];
                                        _inputText.value = widget
                                            .textEditingController.text;
                                      });
                                    }
                                  }
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 0.5)),
                                color: isSupported
                                    ? Colors.transparent
                                    : Colors.grey.shade50,
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          suggestion['short_code'] ??
                                              'No Shortcode',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: isSupported
                                                  ? const Color(0xFF1E88E5)
                                                  : Colors.grey.shade400),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (contentWidget != null) ...[
                                          const SizedBox(height: 2),
                                          contentWidget,
                                        ],
                                        if (!isSupported) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'This file is not supported on $platform',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade500,
                                                fontStyle:
                                                    FontStyle.italic),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (trailingWidget != null) ...[
                                    const SizedBox(width: 12),
                                    Opacity(
                                        opacity:
                                            isSupported ? 1.0 : 0.4,
                                        child: trailingWidget),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        // Input bar
        IntrinsicHeight(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: SafeArea(
                bottom: true,
                left: false,
                right: false,
                top: false,
                child: Container(
                  padding: textFieldConfig?.padding ??
                      const EdgeInsets.symmetric(horizontal: 4),
                  margin: textFieldConfig?.margin,
                  decoration: BoxDecoration(
                    borderRadius: textFieldConfig?.borderRadius ??
                        BorderRadius.circular(textFieldBorderRadius),
                    color: sendMessageConfig?.textFieldBackgroundColor ??
                        Colors.white,
                  ),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isRecording,
                    builder: (context, isRecordingValue, child) {
                      return Column(
                        children: [
                          if (isRecordingValue)
                            Container(
                              padding: const EdgeInsets.only(
                                  left: 16, top: 8, bottom: 2),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.fiber_manual_record,
                                      color: Colors.red, size: 16),
                                  const SizedBox(width: 8),
                                  Text(_timerText,
                                      style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              if (isRecordingValue && !kIsWeb)
                                AudioWaveforms(
                                  size: Size(
                                      MediaQuery.of(context).size.width *
                                          0.75,
                                      50),
                                  recorderController: recorderController,
                                  margin: voiceRecordingConfig?.margin,
                                  padding:
                                      voiceRecordingConfig?.padding ??
                                          const EdgeInsets.symmetric(
                                              horizontal: 8),
                                  decoration:
                                      voiceRecordingConfig?.decoration ??
                                          BoxDecoration(
                                            color: voiceRecordingConfig
                                                ?.backgroundColor,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    12.0),
                                          ),
                                  waveStyle:
                                      voiceRecordingConfig?.waveStyle ??
                                          WaveStyle(
                                            extendWaveform: true,
                                            showMiddleLine: false,
                                            waveColor: voiceRecordingConfig
                                                    ?.waveStyle?.waveColor ??
                                                Colors.black,
                                          ),
                                )
                              else
                                Expanded(
                                  child: TextField(
                                    cursorColor: Colors.black,
                                    autofocus: widget.autofocus,
                                    controller:
                                        widget.textEditingController,
                                    style: textFieldConfig?.textStyle ??
                                        const TextStyle(
                                            color: Colors.white),
                                    maxLines:
                                        textFieldConfig?.maxLines ?? 5,
                                    minLines:
                                        textFieldConfig?.minLines ?? 1,
                                    keyboardType:
                                        textFieldConfig?.textInputType,
                                    inputFormatters:
                                        textFieldConfig?.inputFormatters,
                                    onChanged: _onChanged,
                                    textCapitalization:
                                        textFieldConfig
                                                ?.textCapitalization ??
                                            TextCapitalization.sentences,
                                    decoration: InputDecoration(
                                      hintText:
                                          textFieldConfig?.hintText ??
                                              PackageStrings.message,
                                      fillColor: sendMessageConfig
                                              ?.textFieldBackgroundColor ??
                                          Colors.white,
                                      filled: true,
                                      hintStyle:
                                          textFieldConfig?.hintStyle ??
                                              TextStyle(
                                                fontSize: 16,
                                                fontWeight:
                                                    FontWeight.w400,
                                                color:
                                                    Colors.grey.shade600,
                                                letterSpacing: 0.25,
                                              ),
                                      contentPadding:
                                          textFieldConfig?.contentPadding ??
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6),
                                      border: _outLineBorder,
                                      focusedBorder: _outLineBorder,
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                            color: Colors.transparent),
                                        borderRadius:
                                            textFieldConfig?.borderRadius ??
                                                BorderRadius.circular(
                                                    textFieldBorderRadius),
                                      ),
                                    ),
                                  ),
                                ),
                              ValueListenableBuilder<String>(
                                valueListenable: _inputText,
                                builder: (_, inputTextValue, child) {
                                  if (inputTextValue.isNotEmpty) {
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            if (!_isMounted || _isDisposed) return;
                                              _showMaxIAPromptDialog(context, _inputText.value);
                                          },
                                          icon: const FaIcon(
                                            FontAwesomeIcons
                                                .magicWandSparkles,
                                            size: 18,
                                            color: Colors.black,
                                          ),
                                        ),
                                        IconButton(
                                          color: sendMessageConfig
                                                  ?.defaultSendButtonColor ??
                                              Colors.green,
                                          onPressed: () {
                                            widget.onPressed();
                                            _inputText.value = '';
                                          },
                                          icon: sendMessageConfig
                                                  ?.sendButtonIcon ??
                                              const Icon(Icons.send),
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Row(
                                      children: [
                                        if (!isRecordingValue) ...[
                                          if (sendMessageConfig
                                                  ?.enableCameraImagePicker ??
                                              true)
                                            IconButton(
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () {},
                                              icon: imagePickerIconsConfig
                                                      ?.cameraImagePickerIcon ??
                                                  Icon(
                                                      Icons
                                                          .camera_alt_outlined,
                                                      color:
                                                          imagePickerIconsConfig
                                                              ?.cameraIconColor),
                                            ),
                                          if (sendMessageConfig
                                                  ?.enableGalleryImagePicker ??
                                              true)
                                            IconButton(
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () => _onIconPressed(
                                                context,
                                                ImageSource.gallery,
                                                config: sendMessageConfig
                                                    ?.imagePickerConfiguration,
                                              ),
                                              icon: imagePickerIconsConfig
                                                      ?.galleryImagePickerIcon ??
                                                  Icon(Icons.image,
                                                      color:
                                                          imagePickerIconsConfig
                                                              ?.galleryIconColor),
                                            ),
                                          IconButton(
                                            onPressed: () {
                                              if (!_isMounted || _isDisposed) return;
                                               _showMaxIAPromptDialog(context, '');
                                               /*  return;
                                              _showMaxIAPromptDialog(
                                                  context); */
                                            },
                                            icon: const FaIcon(
                                              FontAwesomeIcons
                                                  .magicWandSparkles,
                                              size: 18,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                        if (sendMessageConfig
                                                    ?.allowRecordingVoice ??
                                                true &&
                                                    (Platform.isIOS ||
                                                        Platform.isAndroid) &&
                                                    !kIsWeb)
                                          IconButton(
                                            onPressed: () =>
                                                _recordOrStop(context),
                                            icon: (isRecordingValue
                                                        ? voiceRecordingConfig
                                                            ?.micIcon
                                                        : voiceRecordingConfig
                                                            ?.stopIcon) ??
                                                Icon(isRecordingValue
                                                    ? Icons.stop
                                                    : Icons.mic),
                                            color: voiceRecordingConfig
                                                ?.recorderIconColor,
                                          )
                                      ],
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
      final filePath =
          '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorderController.record(path: filePath);
      isRecording.value = true;
      _startTimer();
    } else {
      final recordedPath = await recorderController.stop();
      isRecording.value = false;
      _stopTimer();
      if (recordedPath != null && recordedPath.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final String? platform = prefs.getString('platform');
        FocusManager.instance.primaryFocus?.unfocus();
        await Future.delayed(const Duration(milliseconds: 100));
        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (ctx) => AudioViewerPage(
              fileUrl: recordedPath,
              onSend: (fileUrl, caption, onComplete) {
                send_file_tap(fileUrl, caption ?? '', onComplete);
              },
              platform: platform ?? '',
            ),
          ),
        );
      }
    }
  }

  void send_file_tap(
      String filePath, String? message, VoidCallback onComplete) async {
    ProcessingOverlay.show(context);
    if (filePath != '') {
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
      request.fields['message_body'] = message ?? '';
      request.fields['conversation_id'] = "$conversation_id";
      request.fields['cb_message_source'] = 'android';
      request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      final response = await request.send();
      if (response.statusCode == 200) {
        ProcessingOverlay.hide();
        onComplete();
      } else {
        ProcessingOverlay.hide();
        onComplete();
        if (_isMounted && !_isDisposed) {
          _showErrorSnackbar(context, 'Failed to send file.');
        }
      }
      if (_isMounted && !_isDisposed) setState(() {});
    }
  }

  void _onIconPressed(
    BuildContext ctx,
    ImageSource imageSource, {
    ImagePickerConfiguration? config,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? platform = prefs.getString('platform');
      final String? page = prefs.getString('page');
      bool needsWhatsAppValidation = page == 'chat' &&
          (platform == 'fb_whatsapp' || platform == 'whatsapp');
      bool needsInstagramValidation = page == 'chat' &&
          (platform == 'instagram' || platform == 'Instagram');
      bool needsTelegramValidation = page == 'chat' &&
          (platform == 'telegram' || platform == 'Telegram');
      bool needsFacebookValidation = page == 'chat' &&
          (platform == 'facebook' || platform == 'Facebook');
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
      if (imagePath != null && imagePath.isNotEmpty) {
        String lowerPath = imagePath.toLowerCase();
        if (needsWhatsAppValidation) {
          bool isValidFormat = lowerPath.endsWith('.jpg') ||
              lowerPath.endsWith('.jpeg') ||
              lowerPath.endsWith('.png');
          if (!isValidFormat) {
            _showCustomNotification(
                ctx, 'WhatsApp only supports JPG, JPEG, and PNG images.');
            return;
          }
        } else if (needsInstagramValidation) {
          bool isValidFormat = lowerPath.endsWith('.jpeg') ||
              lowerPath.endsWith('.png') ||
              lowerPath.endsWith('.jpg');
          if (!isValidFormat) {
            _showCustomNotification(
                ctx, 'Instagram only supports JPEG and PNG images.');
            return;
          }
        } else if (needsTelegramValidation) {
          bool isValidFormat = lowerPath.endsWith('.png') ||
              lowerPath.endsWith('.jpeg') ||
              lowerPath.endsWith('.jpg') ||
              lowerPath.endsWith('.gif') ||
              lowerPath.endsWith('.webp') ||
              lowerPath.endsWith('.bmp');
          if (!isValidFormat) {
            _showCustomNotification(ctx,
                'Telegram supports PNG, JPEG, GIF, and WEBP images.');
            return;
          }
        } else if (needsFacebookValidation) {
          bool isValidFormat = lowerPath.endsWith('.png') ||
              lowerPath.endsWith('.jpeg') ||
              lowerPath.endsWith('.jpg') ||
              lowerPath.endsWith('.gif');
          if (!isValidFormat) {
            _showCustomNotification(
                ctx, 'Facebook supports PNG, JPEG, and GIF images.');
            return;
          }
        }
        Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (context) => ImageViewerPage(
              imagePath: imagePath ?? '',
              onSend: (sentImagePath, message, completed) {
                widget.onImageSelected(sentImagePath, '', message ?? '');
              },
              padding: const EdgeInsets.fromLTRB(
                  bottomPadding4, bottomPadding4, bottomPadding4,
                  bottomPadding4),
              platform: platform ?? '',
            ),
          ),
        );
      }
    } catch (e) {
      widget.onImageSelected('', e.toString(), '');
    }
  }

  void _onChanged(String inputText) async {
    if (inputText.startsWith('/')) {
      String searchText =
          inputText == '/' ? '/' : inputText.substring(1);
      final canned_response = await fetch_canned_responses(searchText);
      if (_isMounted && !_isDisposed) {
        setState(() {
          if (inputText == '/') {
            suggestions = canned_response.isEmpty
                ? [
                    {
                      "short_code": "Please Enter Short code",
                      "content": "",
                      "media_type": "",
                      "media_url": ""
                    }
                  ]
                : canned_response;
          } else if (canned_response.isEmpty) {
            suggestions = [
              {
                "short_code": "Nothing to Suggest",
                "content": "",
                "media_type": "",
                "media_url": ""
              }
            ];
          } else {
            suggestions = canned_response;
          }
        });
      }
    } else {
      _removeSuggestionOverlay();
      if (_isMounted && !_isDisposed) setState(() => suggestions = []);
    }
    _inputText.value = inputText.isEmpty ? '' : inputText;
    debouncer.run(
      () { if (!_isDisposed) composingStatus.value = TypeWriterStatus.typed; },
      () { if (!_isDisposed) composingStatus.value = TypeWriterStatus.typing; },
    );
  }
}

// Rest of the supporting widgets remain the same...
class ImageViewerPage extends StatefulWidget {
  final String? imagePath;
  final Function(String, String?, VoidCallback) onSend;
  final String platform;
  final EdgeInsetsGeometry padding;
  const ImageViewerPage(
      {Key? key,
      required this.imagePath,
      required this.onSend,
      required this.padding,
      required this.platform})
      : super(key: key);
  @override
  _ImageViewerPageState createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isMounted = false;
  
  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _focusNode.addListener(() { if (_isMounted) setState(() {}); });
  }
  
  @override
  void dispose() {
    _isMounted = false;
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final hasCaption =
        widget.platform != 'facebook' && widget.platform != 'instagram';
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Image Preview',
            style: TextStyle(color: Colors.white)),
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
                      child: Image.file(File(widget.imagePath!),
                          fit: BoxFit.contain))
                  : const Text('No image selected',
                      style: TextStyle(color: Colors.white70)),
            ),
          ),
          Container(
            margin: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: mediaQuery.padding.bottom + 10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(15)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (hasCaption)
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16),
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: "Add a caption...",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                      ),
                    ),
                  if (!hasCaption) const Spacer(),
                  GestureDetector(
                    onTap: () {
                      widget.onSend(widget.imagePath ?? '',
                          _messageController.text.trim(), () {});
                      _messageController.clear();
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(30)),
                      child: const Icon(Icons.send,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AudioViewerPage extends StatefulWidget {
  final String fileUrl;
  final Function(String, String?, VoidCallback) onSend;
  final String platform;
  const AudioViewerPage(
      {Key? key,
      required this.fileUrl,
      required this.onSend,
      required this.platform})
      : super(key: key);
  @override
  _AudioViewerPageState createState() => _AudioViewerPageState();
}

class _AudioViewerPageState extends State<AudioViewerPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late audio.AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;
  bool _isInitialized = false;
  int? _fileSize;
  bool _hasCompleted = false;
  late bool _hideCaption;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _hideCaption = widget.platform == 'fb_whatsapp' ||
        widget.platform == 'whatsapp' ||
        widget.platform == 'facebook' ||
        widget.platform == 'instagram';
    _audioPlayer = audio.AudioPlayer();
    _initAudioPlayer();
    _getFileSize();
    _focusNode.addListener(() { if (_isMounted) setState(() {}); });
  }

  Future<void> _initAudioPlayer() async {
    try {
      await _audioPlayer.stop();
      if (_isMounted) {
        setState(() {
          _isLoading = true;
          _isPlaying = false;
          _position = Duration.zero;
          _duration = Duration.zero;
        });
      }
      _audioPlayer.onPlayerStateChanged.listen((s) {
        if (_isMounted) setState(() => _isPlaying = s == audio.PlayerState.playing);
      });
      _audioPlayer.onDurationChanged.listen((d) {
        if (_isMounted) setState(() { _duration = d; _isLoading = false; });
      });
      _audioPlayer.onPositionChanged.listen((p) {
        if (_isMounted) setState(() => _position = p);
      });
      _audioPlayer.onPlayerComplete.listen((_) {
        if (_isMounted) setState(() { _isPlaying = false; _position = Duration.zero; _hasCompleted = true; });
      });
      await _audioPlayer.setSource(audio.DeviceFileSource(widget.fileUrl));
      _isInitialized = true;
    } catch (e) {
      if (_isMounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _playPause() async {
    if (!_isInitialized) await _initAudioPlayer();
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_hasCompleted) {
        await _replayAudio();
        if (_isMounted) setState(() => _hasCompleted = false);
      } else {
        if (_position >= _duration - const Duration(milliseconds: 100) ||
            _duration == Duration.zero) {
          await _audioPlayer.seek(Duration.zero);
        }
        await _audioPlayer.resume();
      }
    }
  }

  Future<void> _seekAudio(double value) async {
    if (!_isInitialized) return;
    await _audioPlayer.seek(
        Duration(milliseconds: (value * _duration.inMilliseconds).round()));
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
      if (await file.exists()) {
        final stat = await file.stat();
        if (_isMounted) setState(() => _fileSize = stat.size);
      }
    } catch (e) {}
  }

  String _formatDuration(Duration d) {
    String n(int n) => n.toString().padLeft(2, '0');
    final h = n(d.inHours);
    final m = n(d.inMinutes.remainder(60));
    final s = n(d.inSeconds.remainder(60));
    return h == '00' ? '$m:$s' : '$h:$m:$s';
  }

  String _getFileSizeText() {
    if (_fileSize == null) return '';
    if (_fileSize! < 1024) return '$_fileSize B';
    if (_fileSize! < 1024 * 1024)
      return '${(_fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(_fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  void dispose() {
    _isMounted = false;
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Audio Preview',
              style: TextStyle(color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white)),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(20)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p.basename(widget.fileUrl),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    if (_fileSize != null)
                      Text('File size: ${_getFileSizeText()}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.blue)
                        : Column(children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: Colors.blue,
                                  inactiveTrackColor: Colors.grey[700],
                                  trackHeight: 4.0,
                                  thumbColor: Colors.blue,
                                  overlayColor:
                                      Colors.blue.withAlpha(32),
                                  thumbShape:
                                      const RoundSliderThumbShape(
                                          enabledThumbRadius: 8.0),
                                  overlayShape:
                                      const RoundSliderOverlayShape(
                                          overlayRadius: 14.0)),
                              child: Slider(
                                  value: _duration.inMilliseconds == 0
                                      ? 0
                                      : (_position.inMilliseconds /
                                              _duration.inMilliseconds)
                                          .clamp(0.0, 1.0),
                                  onChanged: _seekAudio,
                                  onChangeEnd: _seekAudio),
                            ),
                            Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatDuration(_position),
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12)),
                                      Text(_formatDuration(_duration),
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12))
                                    ])),
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
                                              color: Colors.blue
                                                  .withOpacity(0.5),
                                              blurRadius: 10,
                                              spreadRadius: 2)
                                        ]),
                                    child: Icon(
                                        _hasCompleted
                                            ? Icons.replay
                                            : (_isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow),
                                        color: Colors.white,
                                        size: 30))),
                          ]),
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: mediaQuery.padding.bottom + 10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(15)),
              child: _hideCaption
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                            onTap: () {
                              widget.onSend(widget.fileUrl, '', () {});
                              Navigator.pop(context);
                            },
                            child: Container(
                                margin: const EdgeInsets.all(4),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius:
                                        BorderRadius.circular(30)),
                                child: const Icon(Icons.send,
                                    color: Colors.white, size: 22)))
                      ])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                            child: TextField(
                                controller: _messageController,
                                focusNode: _focusNode,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                                maxLines: 3,
                                minLines: 1,
                                decoration: const InputDecoration(
                                    hintText: "Add a caption...",
                                    hintStyle:
                                        TextStyle(color: Colors.white54),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    isDense: true))),
                        GestureDetector(
                            onTap: () {
                              widget.onSend(widget.fileUrl,
                                  _messageController.text.trim(), () {});
                              _messageController.clear();
                              Navigator.pop(context);
                            },
                            child: Container(
                                margin: const EdgeInsets.all(4),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius:
                                        BorderRadius.circular(30)),
                                child: const Icon(Icons.send,
                                    color: Colors.white, size: 22))),
                      ]),
            ),
          ),
        ],
      ),
    );
  }
}

class ProcessingOverlay {
  static OverlayEntry? _overlayEntry;
  static void show(BuildContext context) {
    if (_overlayEntry != null) return;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                  backgroundColor: Colors.grey[300],
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.blue)),
              Container(
                  width: double.infinity,
                  color: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: const Text('Processing...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500))),
            ],
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _ShimmerLine extends StatefulWidget {
  final double widthFactor;
  const _ShimmerLine({required this.widthFactor});
  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);
  late final Animation<double> _anim =
      Tween<double>(begin: 0.2, end: 0.65).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => FractionallySizedBox(
          widthFactor: widget.widthFactor,
          alignment: Alignment.centerLeft,
          child: Container(
              height: 13,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF6366F1).withOpacity(_anim.value)))));
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();
  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  Widget _dot(double delay) => AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = ((_ctrl.value - delay) % 1.0);
        final scale = t < 0.4
            ? 0.6 + (t / 0.4) * 0.4
            : t < 0.8
                ? 1.0 - ((t - 0.4) / 0.4) * 0.4
                : 0.6;
        return Transform.scale(
            scale: scale,
            child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle)));
      });
  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(0.0),
        const SizedBox(width: 4),
        _dot(0.2),
        const SizedBox(width: 4),
        _dot(0.4)
      ]);
}