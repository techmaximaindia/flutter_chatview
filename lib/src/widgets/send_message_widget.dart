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
import 'dart:io' if (kIsWeb) 'dart:html';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview/chatview.dart';
import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/utils/package_strings.dart';
import 'package:chatview/src/widgets/chatui_textfield.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../chatview.dart';
import '../utils/constants/constants.dart';

import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'chatui_textfield.dart';
import 'socket_manager.dart';

class SendMessageWidget extends StatefulWidget {
  const SendMessageWidget({
    Key? key,
    required this.onSendTap,
    required this.chatController,
    this.sendMessageConfig,
    this.backgroundColor,
    this.sendMessageBuilder,
    this.onReplyCallback,
    this.onReplyCloseCallback,
  }) : super(key: key);

  /// Provides call back when user tap on send button on text field.
  final StringMessageCallBack onSendTap;

  /// Provides configuration for text field appearance.
  final SendMessageConfiguration? sendMessageConfig;

  /// Allow user to set background colour.
  final Color? backgroundColor;

  /// Allow user to set custom text field.
  final ReplyMessageWithReturnWidget? sendMessageBuilder;

  /// Provides callback when user swipes chat bubble for reply.
  final ReplyMessageCallBack? onReplyCallback;

  /// Provides call when user tap on close button which is showed in reply pop-up.
  final VoidCallBack? onReplyCloseCallback;

  /// Provides controller for accessing few function for running chat.
  final ChatController chatController;


  @override
  State<SendMessageWidget> createState() => SendMessageWidgetState();
}

class SendMessageWidgetState extends State<SendMessageWidget> {
  final _textEditingController = TextEditingController();
  final TextEditingController _messageController = TextEditingController(text: "");
  final _ai_message_edit = TextEditingController(text:"");
  final ValueNotifier<ReplyMessage> _replyMessage =
      ValueNotifier(const ReplyMessage());

  ReplyMessage get replyMessage => _replyMessage.value;
  /* final _focusNode = FocusNode(); */
  final bool _focusNode=true;

  ChatUser? get repliedUser => replyMessage.replyTo.isNotEmpty
      ? widget.chatController.getUserFromId(replyMessage.replyTo)
      : null;

  String get _replyTo => replyMessage.replyTo == currentUser?.id
      ? PackageStrings.you
      : repliedUser?.name ?? '';

  ChatUser? currentUser;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isSendEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoadingAI = ValueNotifier<bool>(false);


   @override
   void initState() {
    super.initState();
   /*  SocketManager().connectSocket(
      onMessageReceived: (incomingText) {
        setState(() {
          _messageController.text += incomingText;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        });
        _isSendEnabled.value = true;
        _scrollToBottom();
      },
      /* source: 'chat' */
    ); */
   }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (provide != null) {
      currentUser = provide!.currentUser;
    }
  }
   void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }
  Future<String> call_ai_assist(BuildContext context,String replyMessageId,String query,) async 
  {
    try{
      final prefs = await SharedPreferences.getInstance();
      final String? uuid = prefs.getString('uuid');
      final String? team_alias= prefs.getString('team_alias');
      final url = base_url + 'api/reply/';
        final String? cb_lead_id = prefs.getString('cb_lead_id');
        final String? platform = prefs.getString('platform');
        final String? conversation_id = prefs.getString('conversation_id');
        final String? cb_lead_name=prefs.getString('cb_lead_name');
        final String? ticket_id = prefs.getString('ticket_id');
        final String? ticket_name=prefs.getString('ticket_name');

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
        var headers = 
        {
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
              "suggestion": '',
              "message_id": replyMessageId,
              "query":query,
              "response_mode":'streaming',
              "ref_element":"button"
            }
        });
        request.headers.addAll(headers);
        http.StreamedResponse response = await request.send();
        if (response.statusCode == 200) {
          String responseBody = await response.stream.bytesToString();
          Map<String, dynamic> decodedResponse = json.decode(responseBody);
          //debugPrint("SEND Message AI RESPONSE :$decodedResponse",wrapWidth: 1024);
          if (decodedResponse['success'] == 'false') {
            throw Exception(decodedResponse['ai_error_message'] ?? 'Failed to generate AI response');
          } else {
            var aiResponse = json.decode(decodedResponse['ai_response']);
            //return aiResponse['answer'];
             /*return source == "ticket"
                ? json.decode(aiResponse['answer'])['response']
                : aiResponse['answer'];*/
               try {
                  if (source == "ticket") {
                    var decodedAnswer = json.decode(aiResponse['answer']);
                    if (decodedAnswer is Map && decodedAnswer.containsKey('response')) {
                      // ✅ Only return the inner value of "response"
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
      }
      catch (e) {
       throw Exception(e.toString());
      }
    }

    Future<void> send_ticket_Message(String message,) async 
    {
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
      if (response.statusCode == 200) 
      {
      } 
      else 
      {

      }
    }

  Future<List<Map<String, String>>> fetch_ai_languages() async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final String? uuid       = prefs.getString('uuid');
      final String? team_alias = prefs.getString('team_alias');
  
      final url = base_url + 'api/v2/ai/languages/';
  
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type':  'application/json',
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
  
          // Cache to prefs for offline fallback
          await prefs.setString('cached_ai_languages', json.encode(languages));
  
          return languages;
        }
      }
    } catch (e) {
      //debugPrint('fetch_ai_languages error: $e');
    }
  
    // ── Fallback 1: cached languages from prefs ────────────────────────────────
    try {
      final prefs  = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_ai_languages');
      if (cached != null) {
        final List<dynamic> decoded = json.decode(cached);
        return decoded.map<Map<String, String>>((item) => {
          'code': item['code']?.toString() ?? '',
          'name': item['name']?.toString() ?? '',
        }).toList();
      }
    } catch (e) {
      //debugPrint('fetch_ai_languages cache read error: $e');
    }
  
    // ── Fallback 2: hardcoded list if API and cache both fail ──────────────────
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
   // print('ORIGINAL RESPONSE $text');
    print('TRANSLATED RESPONSE $target_language');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success' && data['data'] != null) {
        debugPrint('call_ai_translate response: ${data['data']}', wrapWidth: 1024);
        return data['data']['translated_text'] ?? text;
      }
      // 200 but error body
      debugPrint('call_ai_translate error body: ${response.body}', wrapWidth: 1024);
      throw Exception('Translation failed');
    }

    // Non-200 — extract error message from body
    debugPrint('Statuscode: ${response.statusCode}', wrapWidth: 1024);
    debugPrint('call_ai_translate response: ${response.body}', wrapWidth: 1024);
    try {
      final errData = json.decode(response.body);
      final message = errData['error']?['message']?.toString();
      throw Exception(message ?? 'Translation failed');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Translation failed: ${response.statusCode}');
    }
  } catch (e) {
    //debugPrint('call_ai_translate error: $e');
    rethrow; // ← rethrow so _triggerTranslation catch block receives it
  }
}
 void _show_dialog_fetch_response(
  BuildContext context,
  String reply_message,
  String reply_message_id,
) async {
  // ── Reset state ────────────────────────────────────────────────────────────
  _messageController.clear();
  _isSendEnabled.value = false;
  _isLoadingAI.value   = true;
  final prefs_page = await SharedPreferences.getInstance();
  final bool _isChatPage = prefs_page.getString('page') == 'chat';
  // ── Kick off BOTH fetches in parallel ─────────────────────────────────────
  final languagesFuture = _isChatPage
      ? fetch_ai_languages()
      : Future.value(<Map<String, String>>[]);
  final aiFuture = call_ai_assist(context, reply_message_id, reply_message);

  final List<Map<String, String>> preloadedLanguages = await languagesFuture;
 
  // ── Local state ───────────────────────────────────────────────────────────
  bool   _isResponseReady  = false;
  bool   _isTranslating    = false;
  bool   _isRegenerating   = false;
  bool   _isEditing        = false;
  bool   _translationFailed = false;
  bool   _isAiError = false;
  String  originalResponse  = "";
  String  translatedText    = "";
  String? selectedLanguage;
  int     _currentPage      = 0;
 
  // Languages are already loaded — no spinner needed
  List<Map<String, String>> availableLanguages = preloadedLanguages;
 
  final PageController       _pageController      = PageController();
  final TextEditingController _translatedController = TextEditingController();
  final ScrollController      _scrollController    = ScrollController();
 
  // ── AI response resolves in the background while the sheet is open ────────
  aiFuture.then((response) {
    originalResponse            = response;
    translatedText              = response;
    _messageController.text     = response;
    _isSendEnabled.value        = response.isNotEmpty;
    _isLoadingAI.value          = false;
    _isResponseReady            = true;
  }).catchError((error) {
    final errorMsg = error.toString().replaceFirst('Exception: ', '');
    originalResponse = errorMsg;
    _isAiError = true;
    _messageController.text = errorMsg;
    _isSendEnabled.value = false;
    _isLoadingAI.value = false;
    _isResponseReady = true;
  });
 
  // ── Show sheet ────────────────────────────────────────────────────────────
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
 
          // ── Helper: language name from code ──────────────────────────────
          String _getLanguageNameFromCode(String code) {
            final lang = availableLanguages.firstWhere(
              (l) => l['code'] == code,
              orElse: () => {'name': code},
            );
            return lang['name'] ?? code;
          }
 
          // ── Regenerate AI response ───────────────────────────────────────
          Future<void> _regenerateResponse() async {
            if (_isRegenerating) return;
            setState(() {
              _isRegenerating   = true;
              _isEditing        = false;
              _isTranslating    = false;
              _translationFailed = false;
              _isAiError = false;
              selectedLanguage  = null;
              _currentPage      = 0;
            });
            _messageController.clear();
            _isSendEnabled.value = false;
 
            call_ai_assist(context, reply_message_id, reply_message).then((response) {
              if (mounted) {
                setState(() {
                  originalResponse        = response;
                  translatedText          = response;
                  _messageController.text = response;
                  _isSendEnabled.value    = response.isNotEmpty;
                  _isRegenerating         = false;
                  _translatedController.clear();
                  _pageController.jumpToPage(0);
                });
              }
            }).catchError((error) {
              final errorMsg = error.toString().replaceFirst('Exception: ', '');
              if (mounted) {
                setState(() {
                  originalResponse = errorMsg;
                  _messageController.text = errorMsg;
                  _isSendEnabled.value = false;
                  _isRegenerating = false;
                  _isAiError = true;  // ← hide button on regenerate error too
                });
              }
            });
          }
 
          // ── Listen for AI ready (drives shimmer → content swap) ──────────
          void _onLoadingChanged() {
            if (!_isResponseReady && !_isLoadingAI.value) {
              if (mounted) setState(() => _isResponseReady = true);
            }
          }
          if (!_isResponseReady) {
            _isLoadingAI.removeListener(_onLoadingChanged);
            _isLoadingAI.addListener(_onLoadingChanged);
          }
 
          // ── Trigger translation ──────────────────────────────────────────
          Future<void> _triggerTranslation(String lang) async {
            if (_isTranslating) return;
 
            // If same language already translated successfully, just flip page
            if (selectedLanguage == lang && !_translationFailed) {
              if (_currentPage != 1) {
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                );
              }
              return;
            }
 
            setState(() {
              selectedLanguage   = lang;
              _isTranslating     = true;
              _translationFailed = false;
              _currentPage       = 1;
            });
 
            _pageController.animateToPage(
              1,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
 
            try {
              final translated = await call_ai_translate(originalResponse, lang);
              if (mounted) {
                setState(() {
                  translatedText             = translated;
                  _translatedController.text = translated;
                  _isTranslating             = false;
                  _translationFailed         = false;
                  _isSendEnabled.value       = true;
                });
              }
            } catch (e) {
              // ── CHANGE 4: Show actual API error message ─────────────────
              final errorMsg = e.toString().replaceFirst('Exception: ', '');
              //debugPrint('Translation error: $e');
              if (mounted) {
                setState(() {
                  translatedText = errorMsg;
                  _translatedController.text = errorMsg;
                  _isTranslating = false;
                  _translationFailed = true;
                });
              }
            }
          }
 
          // ── Send original ────────────────────────────────────────────────
          void _sendOriginal() {
            if (_messageController.text.trim().isEmpty) return;
            widget.onSendTap.call(
              _messageController.text,
              ReplyMessage(),
              MessageType.text,
              '',
            );
            _messageController.clear();
            _pageController.dispose();
            _translatedController.dispose();
            Navigator.of(context).pop();
          }
 
          // ── Send translated ──────────────────────────────────────────────
          void _sendTranslated() {
            if (translatedText.trim().isEmpty || _isTranslating || _translationFailed) return;
            _messageController.text = translatedText;
            widget.onSendTap.call(
              _messageController.text,
              ReplyMessage(),
              MessageType.text,
              '',
            );
            _messageController.clear();
            _pageController.dispose();
            _translatedController.dispose();
            Navigator.of(context).pop();
          }
 
          // ── UI ───────────────────────────────────────────────────────────
          return SafeArea(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF820AFF)],
                    stops:  [0.0, 0.8],
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
 
                    // ── Header ─────────────────────────────────────────────
                    Container(
                      height:  60,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
 
                              // Edit / Done button
                              ValueListenableBuilder<bool>(
                                valueListenable: _isLoadingAI,
                                builder: (context, isLoading, _) {
                                  /* final bool canEdit = !isLoading &&
                                      !_isTranslating &&
                                      _isResponseReady &&
                                      !_isRegenerating &&
                                      !_translationFailed; */
                                    final bool canEdit = !isLoading &&
                                      _isResponseReady &&
                                      !_isRegenerating &&
                                      _currentPage == 0;
                                  return TextButton(
                                    onPressed: canEdit
                                        ? () => setState(() => _isEditing = !_isEditing)
                                        : null,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _isEditing ? 'Done' : 'Edit',
                                          style: TextStyle(
                                            color: canEdit
                                                ? Colors.white
                                                : Colors.white38,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (_isEditing && canEdit) ...[
                                          const SizedBox(width: 3),
                                          const Icon(Icons.check_circle,
                                              color: Colors.white, size: 18),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
 
                              // Cancel button
                              TextButton(
                                onPressed: () {
                                  _messageController.clear();
                                  _isLoadingAI.value = false;
                                  _pageController.dispose();
                                  _translatedController.dispose();
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Cancel',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
 
                          // Title
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              RichText(
                                text: const TextSpan(children: [
                                  WidgetSpan(
                                    child: FaIcon(
                                        FontAwesomeIcons.magicWandSparkles,
                                        color: Colors.white,
                                        size: 16),
                                    alignment: PlaceholderAlignment.middle,
                                  ),
                                  WidgetSpan(child: SizedBox(width: 5)),
                                  TextSpan(
                                    text: "MaxIA",
                                    style: TextStyle(
                                        color:      Colors.white,
                                        fontSize:   18,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
 
                    // ── Language dropdown (always visible, pre-populated) ───
                    if (_isChatPage)
                      Container(
                        margin:   const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color:        Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.translate, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Translate to',
                              style: TextStyle(
                                  color:      Colors.white,
                                  fontSize:   13,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:        Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                // Dropdown is immediately ready — no spinner
                                child: DropdownButton<String>(
                                  value:             selectedLanguage,
                                  hint: const Text(
                                    'Select language…',
                                    style: TextStyle(fontSize: 13, color: Colors.black54),
                                  ),
                                  isExpanded:        true,
                                  isDense:           true,
                                  dropdownColor:     Colors.white,
                                  iconEnabledColor:  Colors.black,
                                  underline:         const SizedBox(),
                                  icon: const Icon(Icons.arrow_drop_down,
                                      size: 20, color: Colors.black),
                                  style: const TextStyle(fontSize: 13, color: Colors.black),
                                  onChanged: (_isTranslating || !_isResponseReady)
                                      ? null
                                      : (String? newValue) {
                                          if (newValue != null) {
                                            _triggerTranslation(newValue);
                                          }
                                        },
                                  items: availableLanguages
                                      .map<DropdownMenuItem<String>>(
                                        (lang) => DropdownMenuItem<String>(
                                          value: lang['code'],
                                          child: Text(
                                            lang['name'] ?? lang['code'] ?? '',
                                            style: const TextStyle(
                                                fontSize: 13, color: Colors.black),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
  
                            // Spinner shown only while a translation is in flight
                            if (_isTranslating) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              ),
                            ],
                          ],
                        ),
                      ),
 
                    // ── Pager dots ─────────────────────────────────────────
                    if (_isChatPage &&_isResponseReady && selectedLanguage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(
                                    _currentPage == 0 ? 1.0 : 0.35),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(
                                    _currentPage == 1 ? 1.0 : 0.35),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currentPage == 0 ? 'Original' : 'Translated',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
 
                    // ── Body (shimmer while loading, PageView when ready) ──
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _isLoadingAI,
                          builder: (context, isLoading, _) {
 
                            // Shimmer card while AI is fetching
                            if (isLoading) {
                              return Card(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: const BorderSide(
                                      color: Color(0xFF6366F1), width: 3),
                                ),
                                elevation: 5,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: _buildLoadingShimmer(),
                                ),
                              );
                            }
 
                            // PageView once AI response is ready
                            return PageView(
                              controller: _pageController,
                              physics: (_isChatPage && selectedLanguage != null)
                                  ? const BouncingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              onPageChanged: (page) =>
                                  setState(() => _currentPage = page),
                              children: [
 
                                // ── Page 0 : Original ──────────────────────
                                Card(
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(
                                        color: Color(0xFF6366F1), width: 3),
                                  ),
                                  elevation: 5,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
 
                                        // Card header row
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(children: const [
                                              Icon(Icons.check_circle_outline,
                                                  size: 13,
                                                  color: Color(0xFF6366F1)),
                                              SizedBox(width: 5),
                                              Text('Original',
                                                  style: TextStyle(
                                                      fontSize:   11,
                                                      color:      Color(0xFF6366F1),
                                                      fontWeight: FontWeight.w500)),
                                            ]),
 
                                            // Regenerate button
                                            if (!_isRegenerating)
                                              TextButton.icon(
                                                onPressed: _regenerateResponse,
                                                icon: const Icon(Icons.refresh,
                                                    size: 16,
                                                    color: Color(0xFF6366F1)),
                                                label: const Text('Regenerate',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Color(0xFF6366F1))),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 4),
                                                  minimumSize:    Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize.shrinkWrap,
                                                ),
                                              ),
                                          ],
                                        ),
 
                                        const Divider(height: 16, thickness: 0.5),
 
                                        // Scrollable text area
                                        Expanded(
                                          child: _isRegenerating
                                              ? Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      const CircularProgressIndicator(
                                                        valueColor:
                                                            AlwaysStoppedAnimation<Color>(
                                                                Color(0xFF6366F1)),
                                                        strokeWidth: 2,
                                                      ),
                                                      const SizedBox(height: 12),
                                                      Text('Regenerating…',
                                                          style: TextStyle(
                                                              fontSize: 13,
                                                              color:
                                                                  Colors.grey[600])),
                                                    ],
                                                  ),
                                                )
                                              : SingleChildScrollView(
                                                  controller: _scrollController,
                                                  child: TextField(
                                                    controller: _messageController,
                                                    maxLines:   null,
                                                    enabled:    _isEditing && !_isRegenerating,
                                                    decoration: const InputDecoration(
                                                      border:    InputBorder.none,
                                                      hintText:  'AI response will appear here…',
                                                      hintStyle: TextStyle(
                                                          color:    Colors.grey,
                                                          fontSize: 14),
                                                    ),
                                                    style: const TextStyle(
                                                        color:    Colors.black,
                                                        fontSize: 14,
                                                        height:   1.6),
                                                    onChanged: (text) {
                                                      originalResponse     = text;
                                                      _isSendEnabled.value =
                                                          text.trim().isNotEmpty;
                                                    },
                                                  ),
                                                ),
                                        ),
 
                                        const SizedBox(height: 12),
 
                                        // Send original button
                                        if (!_isAiError)
                                          ValueListenableBuilder<bool>(
                                            valueListenable: _isSendEnabled,
                                            builder: (context, canSend, _) {
                                              return SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: canSend && !_isRegenerating
                                                      ? _sendOriginal
                                                      : null,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF6366F1),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(
                                                        vertical: 12),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(12)),
                                                  ),
                                                  child: const Text('Send Message',
                                                      style: TextStyle(
                                                          fontSize:   14,
                                                          fontWeight: FontWeight.w600)),
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
 
                                // ── Page 1 : Translated ────────────────────
                                if (_isChatPage)
                                  Card(
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: const BorderSide(
                                          color: Color(0xFF820AFF), width: 3),
                                    ),
                                    elevation: 5,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
  
                                          // Card header row
                                          Row(
                                            children: [
                                              const Icon(Icons.translate,
                                                  size: 13,
                                                  color: Color(0xFF820AFF)),
                                              const SizedBox(width: 5),
                                              Text(
                                                selectedLanguage != null
                                                    ? 'Translated to ${_getLanguageNameFromCode(selectedLanguage!)}'
                                                    : 'Translated',
                                                style: const TextStyle(
                                                    fontSize:   11,
                                                    color:      Color(0xFF820AFF),
                                                    fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
  
                                          const Divider(height: 16, thickness: 0.5),
  
                                          // Translated content area
                                          Expanded(
                                            child: _isTranslating
                                                ? Center(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.center,
                                                      children: [
                                                        const CircularProgressIndicator(
                                                          valueColor:
                                                              AlwaysStoppedAnimation<Color>(
                                                                  Color(0xFF820AFF)),
                                                          strokeWidth: 2,
                                                        ),
                                                        const SizedBox(height: 12),
                                                        Text('Translating…',
                                                            style: TextStyle(
                                                                fontSize: 13,
                                                                color:
                                                                    Colors.grey[600])),
                                                      ],
                                                    ),
                                                  )
                                                : _translationFailed
                                                    ? Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment.center,
                                                          children: [
                                                            const Icon(
                                                                Icons.error_outline,
                                                                color: Colors.red,
                                                                size: 48),
                                                            const SizedBox(height: 12),
                                                            const Text(
                                                              'Translation failed.\nPlease try again.',
                                                              textAlign: TextAlign.center,
                                                              style: TextStyle(
                                                                  fontSize: 14,
                                                                  color: Colors.red),
                                                            ),
                                                            const SizedBox(height: 16),
                                                            TextButton(
                                                              onPressed: () {
                                                                if (selectedLanguage !=
                                                                    null) {
                                                                  _triggerTranslation(
                                                                      selectedLanguage!);
                                                                }
                                                              },
                                                              child: const Text(
                                                                'Retry Translation',
                                                                style: TextStyle(
                                                                  color: Color(0xFF820AFF),
                                                                  fontWeight:
                                                                      FontWeight.w600,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                    : SingleChildScrollView(
                                                        child: TextField(
                                                          controller:
                                                              _translatedController,
                                                          maxLines: null,
                                                          enabled:  false, // always read-only
                                                          decoration:
                                                              const InputDecoration(
                                                            border:    InputBorder.none,
                                                            hintText:
                                                                'Translation will appear here…',
                                                            hintStyle: TextStyle(
                                                                color:    Colors.grey,
                                                                fontSize: 14),
                                                          ),
                                                          style: const TextStyle(
                                                              color:    Colors.black,
                                                              fontSize: 14,
                                                              height:   1.6),
                                                        ),
                                                      ),
                                          ),
  
                                          const SizedBox(height: 12),
  
                                          // Send translated button
                                          if (!_translationFailed)
                                            ValueListenableBuilder<bool>(
                                              valueListenable: _isSendEnabled,
                                              builder: (context, canSend, _) {
                                                return SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton(
                                                    onPressed: !_isTranslating &&
                                                            !_translationFailed &&
                                                            translatedText.trim().isNotEmpty
                                                        ? _sendTranslated
                                                        : null,
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF820AFF),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(
                                                          vertical: 12),
                                                      shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(12)),
                                                    ),
                                                    child: const Text('Send Translated',
                                                        style: TextStyle(
                                                            fontSize:   14,
                                                            fontWeight: FontWeight.w600)),
                                                  ),
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
 
                              ],
                            );
                          },
                        ),
                      ),
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
    _messageController.clear();
    _isSendEnabled.value = false;
    _isLoadingAI.value   = false;
    _pageController.dispose();
    _translatedController.dispose();
  });
}

// ── Language name helper ──────────────────────────────────────────────────────
String _getLanguageName(String languageCode) {
  switch (languageCode) {
    case 'es': return 'Spanish';
    case 'fr': return 'French';
    case 'de': return 'German';
    case 'it': return 'Italian';
    case 'pt': return 'Portuguese';
    case 'ru': return 'Russian';
    case 'ja': return 'Japanese';
    case 'ko': return 'Korean';
    case 'zh': return 'Chinese';
    case 'ar': return 'Arabic';
    case 'hi': return 'Hindi';
    case 'nl': return 'Dutch';
    case 'pl': return 'Polish';
    case 'tr': return 'Turkish';
    case 'vi': return 'Vietnamese';
    case 'th': return 'Thai';
    case 'sw': return 'Swahili';
    default:   return 'Language';
  }
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
  @override
  Widget build(BuildContext context) {
    final replyTitle = "${PackageStrings.replyTo} $_replyTo";
    return widget.sendMessageBuilder != null
        ? Positioned(
            right: 0,
            left: 0,
            bottom: 0,
            child: widget.sendMessageBuilder!(replyMessage),
          )
        : Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    left: 0,
                    bottom: 0,
                    child: Container(
                      height: MediaQuery.of(context).size.height /
                          ((!kIsWeb && Platform.isIOS) ? 24 : 28),
                      color: widget.backgroundColor ?? Colors.white,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      bottomPadding4,
                      bottomPadding4,
                      bottomPadding4,
                      _bottomPadding,
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        ValueListenableBuilder<ReplyMessage>(
                          builder: (_, state, child) {
                            if (state.message.isNotEmpty) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: widget.sendMessageConfig
                                          ?.textFieldBackgroundColor ??
                                      Colors.white,
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
                                    color: widget.sendMessageConfig
                                            ?.replyDialogColor ??
                                        Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            replyTitle,
                                            style: TextStyle(
                                              color: widget.sendMessageConfig
                                                      ?.replyTitleColor ??
                                                  Colors.deepPurple,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.25,
                                            ),
                                          ),
                                          IconButton(
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            icon: Icon(
                                              Icons.close,
                                              color: widget.sendMessageConfig
                                                      ?.closeIconColor ??
                                                  Colors.black,
                                              size: 16,
                                            ),
                                            onPressed: _onCloseTap,
                                          ),
                                        ],
                                      ),
                                      if (state.messageType.isVoice)
                                        _voiceReplyMessageView
                                      else if (state.messageType.isImage)
                                        _imageReplyMessageView
                                      else if(state.messageType.isCustom)
                                        _customReplyMessageView
                                      else
                                        Text(
                                          state.message,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: widget.sendMessageConfig
                                                    ?.replyMessageColor ??
                                                Colors.black,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              return const SizedBox.shrink();
                            }
                          },
                          valueListenable: _replyMessage,
                        ),
                        ChatUITextField(
                          textEditingController: _textEditingController,
                          onPressed: _onPressed,
                          sendMessageConfig: widget.sendMessageConfig,
                          onRecordingComplete: _onRecordingComplete,
                          onImageSelected: _onImageSelected,
                          onAIPressed: () {
                            print("onAI Pressed");
                              _show_dialog_fetch_response(context,_replyMessage.value.message,_replyMessage.value.messageId);
                              /* print(_textEditingController.text); */
                          },
                          messageController: _ai_message_edit,
                          ai_send_pressed: () {
                            widget.onSendTap.call(
                              _ai_message_edit.text,
                              ReplyMessage(),
                              MessageType.text,
                              '',
                            );
                          },
                          onAIStreamingResponse: (incomingText) {
                            setState(() {
                              _messageController.text += incomingText; 
                              _messageController.selection = TextSelection.fromPosition(
                                TextPosition(offset: _messageController.text.length),
                              );
                            });
                            _isSendEnabled.value = true;
                            _scrollToBottom();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  Widget get _voiceReplyMessageView {
    return Row(
      children: [
        Icon(
          Icons.mic,
          color: widget.sendMessageConfig?.micIconColor,
        ),
        const SizedBox(width: 4),
        if (replyMessage.voiceMessageDuration != null)
          Text(
            replyMessage.voiceMessageDuration!.toHHMMSS(),
            style: TextStyle(
              fontSize: 12,
              color:
                  widget.sendMessageConfig?.replyMessageColor ?? Colors.black,
            ),
          ),
      ],
    );
  }
  Widget get _imageReplyMessageView {
    return Row(
      children: [
        Icon(
          Icons.photo,
          size: 20,
          color: widget.sendMessageConfig?.replyMessageColor ??
              Colors.grey.shade700,
        ),
        Text(
          PackageStrings.photo,
          style: TextStyle(
            color: widget.sendMessageConfig?.replyMessageColor ?? Colors.black,
          ),
        ),
      ],
    );
  }
  Widget get _customReplyMessageView {
    return Row(
      children: [
        Icon(
          Icons.file_present,
          size: 20,
          color: widget.sendMessageConfig?.replyMessageColor ??
              Colors.grey.shade700,
        ),
        Text(
          'File',
          style: TextStyle(
            color: widget.sendMessageConfig?.replyMessageColor ?? Colors.black,
          ),
        ),
      ],
    );
  }

  void _onRecordingComplete(String? path) {
    if (path != null) {
      widget.onSendTap.call(path, replyMessage, MessageType.voice,'');
      _assignRepliedMessage();
    }
  }

  void _onImageSelected(String imagePath, String error,String? image_message) {
    if (imagePath.isNotEmpty) {
      widget.onSendTap.call(imagePath, replyMessage, MessageType.image,image_message);
      _assignRepliedMessage();
    }
  }

  void _assignRepliedMessage() {
    if (replyMessage.message.isNotEmpty) {
      _replyMessage.value = const ReplyMessage();
    }
  }

  void _onPressed() {
   final messageText = _textEditingController.text.trim();
    _textEditingController.clear();
    if (messageText.isEmpty) return;

    widget.onSendTap.call(
      messageText.trim(),
      replyMessage,
      MessageType.text,
      '',
    );
    print(replyMessage.messageId);
    print(replyMessage.message);
    _assignRepliedMessage();
  }

  void assignReplyMessage(Message message) {
    if (currentUser != null) {
      _replyMessage.value = ReplyMessage(
        message: message.message,
        replyBy: currentUser!.id,
        replyTo: message.sendBy,
        messageType: message.messageType,
        messageId: message.id,
        voiceMessageDuration: message.voiceMessageDuration,
      );
    }
    /* FocusScope.of(context).requestFocus(_focusNode); */
    if (widget.onReplyCallback != null) widget.onReplyCallback!(replyMessage);
  }

  void _onCloseTap() {
    _replyMessage.value = const ReplyMessage();
    if (widget.onReplyCloseCallback != null) widget.onReplyCloseCallback!();
  }

  double get _bottomPadding => (!kIsWeb && Platform.isIOS)
      ? (_focusNode==true
          ? bottomPadding1
          : View.of(context).viewPadding.bottom > 0
              ? bottomPadding2
              : bottomPadding3)
      : bottomPadding3;

  @override
  void dispose() async {
    _textEditingController.dispose();
    /* _focusNode.dispose(); */
    _replyMessage.dispose();
   /*  /* try { */
      SocketManager().disconnectSocket();
    /* } catch (e) {
      print('Socket disconnection error: $e');
    } */ */
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('conversation_id');
      prefs.remove('ticket_id');
      prefs.remove('page');
    });
    super.dispose();
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
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  late final Animation<double> _anim = Tween<double>(begin: 0.25, end: 0.7)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => FractionallySizedBox(
          widthFactor: widget.widthFactor,
          alignment: Alignment.centerLeft,
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF6366F1).withOpacity(_anim.value),
            ),
          ),
        ),
      );
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();
  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

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
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(0.0),
          const SizedBox(width: 4),
          _dot(0.2),
          const SizedBox(width: 4),
          _dot(0.4),
        ],
      );
}