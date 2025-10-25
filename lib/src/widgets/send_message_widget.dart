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


   @override
   void initState() {
    super.initState();
    SocketManager().connectSocket(
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
    );
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
          if (decodedResponse['success'] == 'false') {
            return decodedResponse['ai_error_message'];
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
          throw "Failed to generate AI response";
        }
      }
      catch (e) {
        return "";
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

  void _show_dialog_fetch_response(BuildContext context,String reply_message,String reply_message_id) 
  {
    bool _isEditing = false;
    bool _isExpanded = false; 
    _messageController.clear();
    _isSendEnabled.value = false;
    call_ai_assist(context,reply_message_id,reply_message).then((response) {
        _messageController.text = response; 
         _isSendEnabled.value = response.isNotEmpty;
      }).catchError((error) {
        _messageController.text = "";
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
                    //colors: [Color(0xFF0059FC), Color(0xFF820AFF)],
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
                                    _messageController.clear();
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
                                    controller: _messageController,
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
                                      child: ValueListenableBuilder<bool>
                                      (
                                        valueListenable: _isSendEnabled,
                                        builder: (context, isSendEnabled, child) {
                                         return ElevatedButton(
                                            onPressed: _isSendEnabled.value==true
                                            ?() async {
                                                final value = await SharedPreferences.getInstance();
                                                final String? page = value.getString('page');

                                                /* if (page == 'chat') { */
                                                 /*  sendMessage(_messageController.text); */
                                                  widget.onSendTap.call(
                                                    _messageController.text,
                                                    ReplyMessage(),
                                                    MessageType.text,
                                                    '',
                                                  );
                                                /* } else {
                                                  send_ticket_Message(_messageController.text);
                                                } */
                                                _messageController.clear();
                                                Navigator.of(context).pop();
                                              }
                                            : null,
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
      _messageController.clear();
      _isSendEnabled.value = false;
    });
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
      ''
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
    try {
      SocketManager().disconnectSocket();
    } catch (e) {
      print('Socket disconnection error: $e');
    }
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('conversation_id');
      prefs.remove('ticket_id');
      prefs.remove('page');
    });
    super.dispose();
  }
}
