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

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'chatui_textfield.dart';
import 'socket_manager.dart';
import 'max_ia_prompt_dialog.dart';
import 'max_ia_response_bottom_sheet.dart';

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

  final StringMessageCallBack onSendTap;
  final SendMessageConfiguration? sendMessageConfig;
  final Color? backgroundColor;
  final ReplyMessageWithReturnWidget? sendMessageBuilder;
  final ReplyMessageCallBack? onReplyCallback;
  final VoidCallBack? onReplyCloseCallback;
  final ChatController chatController;

  @override
  State<SendMessageWidget> createState() => SendMessageWidgetState();
}

class SendMessageWidgetState extends State<SendMessageWidget> {
  bool _isDisposed = false;
  bool _isBottomSheetOpen = false;
  bool _isMounted = false;

  final _textEditingController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final _ai_message_edit = TextEditingController();
  final ValueNotifier<ReplyMessage> _replyMessage =
      ValueNotifier(const ReplyMessage());

  ReplyMessage get replyMessage => _replyMessage.value;
  final bool _focusNode = true;

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
    _isMounted = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (provide != null && _isMounted && !_isDisposed) {
      currentUser = provide!.currentUser;
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && _isMounted && !_isDisposed) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Future<String> call_ai_assist(
  BuildContext context,
  String replyMessageId,
  String query,
  String originalReplyMessage,
) async {
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

    // Combine original reply message with user query for better context
    final enhancedQuery = originalReplyMessage.isNotEmpty
        ? "Original message being replied to: \"$originalReplyMessage\"\n\nInstructions: $query"
        : query;

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
        "suggestion": enhancedQuery,
        "message_id": replyMessageId,
        "query": '',
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
    await http.post(Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "$uuid|$team_alias"
        },
        body: jsonData);
  }

  Future<List<Map<String, String>>> fetch_ai_languages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? uuid = prefs.getString('uuid');
      final String? team_alias = prefs.getString('team_alias');
      final url = base_url + 'api/v2/ai/languages/';
      final response = await http.get(Uri.parse(url), headers: {
        'Content-Type': 'application/json',
        'Authorization': '$uuid|$team_alias',
      }).timeout(const Duration(seconds: 10));
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
  }

  Future<String> call_ai_translate(String text, String target_language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? uuid = prefs.getString('uuid');
      final String? team_alias = prefs.getString('team_alias');
      final url = base_url + 'api/v2/ai/translate/';
      final response = await http
          .post(Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': '$uuid|$team_alias',
              },
              body: json
                  .encode({'text': text, 'target_language': target_language}))
          .timeout(const Duration(seconds: 15));
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
        throw Exception('Translation failed: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed || !_isMounted) return const SizedBox.shrink();
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
                    padding: EdgeInsets.fromLTRB(bottomPadding4,
                        bottomPadding4, bottomPadding4, _bottomPadding),
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
                                      top: Radius.circular(14)),
                                ),
                                margin: const EdgeInsets.only(
                                    bottom: 17, right: 0.4, left: 0.4),
                                padding: const EdgeInsets.fromLTRB(
                                    leftPadding,
                                    leftPadding,
                                    leftPadding,
                                    30),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 2),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 6),
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
                                          Text(replyTitle,
                                              style: TextStyle(
                                                  color: widget
                                                          .sendMessageConfig
                                                          ?.replyTitleColor ??
                                                      Colors.deepPurple,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.25)),
                                          IconButton(
                                            constraints:
                                                const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            icon: Icon(Icons.close,
                                                color: widget
                                                        .sendMessageConfig
                                                        ?.closeIconColor ??
                                                    Colors.black,
                                                size: 16),
                                            onPressed: _onCloseTap,
                                          ),
                                        ],
                                      ),
                                      if (state.messageType.isVoice)
                                        _voiceReplyMessageView
                                      else if (state.messageType.isImage)
                                        _imageReplyMessageView
                                      else if (state.messageType.isCustom)
                                        _customReplyMessageView
                                      else
                                        Text(state.message,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: widget
                                                        .sendMessageConfig
                                                        ?.replyMessageColor ??
                                                    Colors.black)),
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
                            /* if (_isDisposed || !_isMounted) return;
                            _showMaxIAPromptDialog(
                              context,
                              _replyMessage.value.message,
                              _replyMessage.value.messageId,
                            ); */
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
                            if (!_isMounted || _isDisposed) return;
                            setState(() {
                              _messageController.text += incomingText;
                              _messageController.selection =
                                  TextSelection.fromPosition(TextPosition(
                                      offset: _messageController.text.length));
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
    return Row(children: [
      Icon(Icons.mic, color: widget.sendMessageConfig?.micIconColor),
      const SizedBox(width: 4),
      if (replyMessage.voiceMessageDuration != null)
        Text(replyMessage.voiceMessageDuration!.toHHMMSS(),
            style: TextStyle(
                fontSize: 12,
                color: widget.sendMessageConfig?.replyMessageColor ??
                    Colors.black)),
    ]);
  }

  Widget get _imageReplyMessageView {
    return Row(children: [
      Icon(Icons.photo,
          size: 20,
          color: widget.sendMessageConfig?.replyMessageColor ??
              Colors.grey.shade700),
      Text(PackageStrings.photo,
          style: TextStyle(
              color: widget.sendMessageConfig?.replyMessageColor ??
                  Colors.black)),
    ]);
  }

  Widget get _customReplyMessageView {
    return Row(children: [
      Icon(Icons.file_present,
          size: 20,
          color: widget.sendMessageConfig?.replyMessageColor ??
              Colors.grey.shade700),
      Text('File',
          style: TextStyle(
              color: widget.sendMessageConfig?.replyMessageColor ??
                  Colors.black)),
    ]);
  }

  void _onRecordingComplete(String? path) {
    if (path != null) {
      widget.onSendTap.call(path, replyMessage, MessageType.voice, '');
      _assignRepliedMessage();
    }
  }

  void _onImageSelected(
      String imagePath, String error, String? image_message) {
    if (imagePath.isNotEmpty) {
      widget.onSendTap
          .call(imagePath, replyMessage, MessageType.image, image_message);
      _assignRepliedMessage();
    }
  }

  void _assignRepliedMessage() {
    if (replyMessage.message.isNotEmpty && _isMounted && !_isDisposed) {
      _replyMessage.value = const ReplyMessage();
    }
  }

  void _onPressed() {
    final messageText = _textEditingController.text.trim();
    _textEditingController.clear();
    if (messageText.isEmpty) return;
    widget.onSendTap
        .call(messageText.trim(), replyMessage, MessageType.text, '');
    _assignRepliedMessage();
  }

  void assignReplyMessage(Message message) {
    if (!_isMounted || _isDisposed) return;
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
    if (widget.onReplyCallback != null && _isMounted && !_isDisposed) {
      widget.onReplyCallback!(replyMessage);
    }
  }

  void _onCloseTap() {
    if (!_isMounted || _isDisposed) return;
    _replyMessage.value = const ReplyMessage();
    if (widget.onReplyCloseCallback != null) widget.onReplyCloseCallback!();
  }

  double get _bottomPadding => (!kIsWeb && Platform.isIOS)
      ? (_focusNode == true
          ? bottomPadding1
          : View.of(context).viewPadding.bottom > 0
              ? bottomPadding2
              : bottomPadding3)
      : bottomPadding3;

  @override
  void dispose() {
    _isMounted = false;
    _isDisposed = true;
    _textEditingController.dispose();
    _messageController.dispose();
    _ai_message_edit.dispose();
    _replyMessage.dispose();
    _scrollController.dispose();
    _isSendEnabled.dispose();
    _isLoadingAI.dispose();
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('conversation_id');
      prefs.remove('ticket_id');
      prefs.remove('page');
    });
    super.dispose();
  }
}

// Shimmer + Pulsing dots
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
  late final Animation<double> _anim = Tween<double>(begin: 0.25, end: 0.7)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  
  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
                  color:
                      const Color(0xFF6366F1).withOpacity(_anim.value)))));
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
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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