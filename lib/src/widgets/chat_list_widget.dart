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
import 'dart:io' if (kIsWeb) 'dart:html';

import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/widgets/chat_groupedlist_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


import '../../chatview.dart';
import '../utils/constants/constants.dart';
import 'reaction_popup.dart';
import 'reply_popup_widget.dart';

class ChatListWidget extends StatefulWidget {
  const ChatListWidget({
    Key? key,
    required this.chatController,
    required this.chatBackgroundConfig,
    required this.showTypingIndicator,
    required this.assignReplyMessage,
    required this.replyMessage,
    this.loadingWidget,
    this.reactionPopupConfig,
    this.messageConfig,
    this.chatBubbleConfig,
    this.profileCircleConfig,
    this.swipeToReplyConfig,
    this.repliedMessageConfig,
    this.typeIndicatorConfig,
    this.replyPopupConfig,
    this.loadMoreData,
    this.isLastPage,
    this.onChatListTap,
  }) : super(key: key);

  /// Provides controller for accessing few function for running chat.
  final ChatController chatController;

  /// Provides configuration for background of chat.
  final ChatBackgroundConfiguration chatBackgroundConfig;

  /// Provides widget for loading view while pagination is enabled.
  final Widget? loadingWidget;

  /// Provides flag for turn on/off typing indicator.
  final bool showTypingIndicator;

  /// Provides configuration for reaction pop up appearance.
  final ReactionPopupConfiguration? reactionPopupConfig;

  /// Provides configuration for customisation of different types
  /// messages.
  final MessageConfiguration? messageConfig;

  /// Provides configuration of chat bubble's appearance.
  final ChatBubbleConfiguration? chatBubbleConfig;

  /// Provides configuration for profile circle avatar of user.
  final ProfileCircleConfiguration? profileCircleConfig;

  /// Provides configuration for when user swipe to chat bubble.
  final SwipeToReplyConfiguration? swipeToReplyConfig;

  /// Provides configuration for replied message view which is located upon chat
  /// bubble.
  final RepliedMessageConfiguration? repliedMessageConfig;

  /// Provides configuration of typing indicator's appearance.
  final TypeIndicatorConfiguration? typeIndicatorConfig;

  /// Provides reply message when user swipe to chat bubble.
  final ReplyMessage replyMessage;

  /// Provides configuration for reply snack bar's appearance and options.
  final ReplyPopupConfiguration? replyPopupConfig;

  /// Provides callback when user actions reaches to top and needs to load more
  /// chat
  final VoidCallBackWithFuture? loadMoreData;

  /// Provides flag if there is no more next data left in list.
  final bool? isLastPage;

  /// Provides callback for assigning reply message when user swipe to chat
  /// bubble.
  final MessageCallBack assignReplyMessage;

  /// Provides callback when user tap anywhere on whole chat.
  final VoidCallBack? onChatListTap;

  @override
  State<ChatListWidget> createState() => _ChatListWidgetState();
}

class _ChatListWidgetState extends State<ChatListWidget>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<bool> _isNextPageLoading = ValueNotifier<bool>(false);
  ValueNotifier<bool> showPopUp = ValueNotifier(false);
  final GlobalKey<ReactionPopupState> _reactionPopupKey = GlobalKey();

  ChatController get chatController => widget.chatController;

  List<Message> get messageList => chatController.initialMessageList;

  ScrollController get scrollController => chatController.scrollController;

  bool get showTypingIndicator => widget.showTypingIndicator;

  ChatBackgroundConfiguration get chatBackgroundConfig =>
      widget.chatBackgroundConfig;

  FeatureActiveConfig? featureActiveConfig;
  ChatUser? currentUser;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (provide != null) {
      featureActiveConfig = provide!.featureActiveConfig;
      currentUser = provide!.currentUser;
    }
    if (featureActiveConfig?.enablePagination ?? false) {
      // When flag is on then it will include pagination logic to scroll
      // controller.
      scrollController.addListener(_pagination);
    }
  }

   void _initialize() {
    chatController.messageStreamController = StreamController();
    if (!chatController.messageStreamController.isClosed) {
      chatController.messageStreamController.sink.add(messageList);
    }
    if (messageList.isNotEmpty) chatController.scrollToLastMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _isNextPageLoading,
          builder: (_, isNextPageLoading, child) {
            if (isNextPageLoading &&
                (featureActiveConfig?.enablePagination ?? false)) {
              return SizedBox(
                height: Scaffold.of(context).appBarMaxHeight,
                 //height:50,
                child: Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                ),
              );
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: showPopUp,
            builder: (_, showPopupValue, child) {
              return Stack(
                children: [
                  ChatGroupedListWidget(
                    showPopUp: showPopupValue,
                    showTypingIndicator: showTypingIndicator,
                    scrollController: scrollController,
                    isEnableSwipeToSeeTime:
                        featureActiveConfig?.enableSwipeToSeeTime ?? true,
                    chatBackgroundConfig: widget.chatBackgroundConfig,
                    assignReplyMessage: widget.assignReplyMessage,
                    replyMessage: widget.replyMessage,
                    swipeToReplyConfig: widget.swipeToReplyConfig,
                    repliedMessageConfig: widget.repliedMessageConfig,
                    profileCircleConfig: widget.profileCircleConfig,
                    messageConfig: widget.messageConfig,
                    chatBubbleConfig: widget.chatBubbleConfig,
                    typeIndicatorConfig: widget.typeIndicatorConfig,
                    onChatBubbleLongPress: (yCoordinate, xCoordinate, message) {
                      if (featureActiveConfig?.enableReactionPopup ?? false) {
                        _reactionPopupKey.currentState?.refreshWidget(
                          message: message,
                          xCoordinate: xCoordinate,
                          yCoordinate: yCoordinate < 0
                              ? -(yCoordinate) - 5
                              : yCoordinate,
                        );
                        showPopUp.value = true;
                      }
                      if (featureActiveConfig?.enableReplySnackBar ?? false) {
                        _showReplyPopup(
                          message: message,
                          sendByCurrentUser: message.sendBy == currentUser?.id,
                        );
                      }
                    },
                    onChatListTap: _onChatListTap,
                  ),
                  if (featureActiveConfig?.enableReactionPopup ?? false)
                    ReactionPopup(
                      key: _reactionPopupKey,
                      reactionPopupConfig: widget.reactionPopupConfig,
                      onTap: _onChatListTap,
                      showPopUp: showPopupValue,
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _pagination() {
    if (widget.loadMoreData == null || widget.isLastPage == true) return;
    if ((scrollController.position.pixels ==
            scrollController.position.maxScrollExtent) &&
        !_isNextPageLoading.value) {
      _isNextPageLoading.value = true;
      widget.loadMoreData!()
          .whenComplete(() => _isNextPageLoading.value = false);
    }
  }

  /*void _showReplyPopup({
    required Message message,
    required bool sendByCurrentUser,
  }) async {
    final replyPopup = widget.replyPopupConfig;
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            backgroundColor: Colors.blue/* replyPopup?.backgroundColor */ ?? Colors.white,
            content: replyPopup?.replyPopupBuilder != null
                ? replyPopup!.replyPopupBuilder!(message, sendByCurrentUser)
                : ReplyPopupWidget(
                  message: message,
                    buttonTextStyle: replyPopup?.buttonTextStyle,
                    topBorderColor: replyPopup?.topBorderColor,
                    onMoreTap: () {
                      _onChatListTap();
                      if (replyPopup?.onMoreTap != null) {
                        replyPopup?.onMoreTap!();
                      }
                    },
                    onReportTap: () {
                      _onChatListTap();
                      if (replyPopup?.onReportTap != null) {
                        replyPopup?.onReportTap!();
                      }
                    },
                    onUnsendTap: () {
                      _onChatListTap();
                      if (replyPopup?.onUnsendTap != null) {
                        /* replyPopup?.onUnsendTap!(message); */
                      }
                    },
                    onReplyTap: () {
                      widget.assignReplyMessage(message);
                      if (featureActiveConfig?.enableReactionPopup ?? false) {
                        showPopUp.value = false;
                      }
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      if (replyPopup?.onReplyTap != null) {
                        replyPopup?.onReplyTap!(message);
                      }
                    },
                    sendByCurrentUser: sendByCurrentUser,
                  ),
            padding: EdgeInsets.zero,
          ),
        )
        .closed;
  }*/
 /*  void _showReplyPopup({
  required Message message,
  required bool sendByCurrentUser,
}) {
  final replyPopup = widget.replyPopupConfig;
  final BuildContext? context = this.context;
  if (context == null) return;

  _showCustomMessagePopup(
    context: context,
    message: message,
    sendByCurrentUser: sendByCurrentUser,
    replyPopup: replyPopup,
  );
} */
void _showReplyPopup({
  required Message message,
  required bool sendByCurrentUser,
}) {
  final replyPopup = widget.replyPopupConfig;
  final BuildContext? context = this.context;
  if (context == null) return;

  _showCustomMessagePopup(
    context: context,
    message: message,
    sendByCurrentUser: sendByCurrentUser,
    replyPopup: replyPopup,
  );
}

void _showCustomMessagePopup({
  required BuildContext context,
  required Message message,
  required bool sendByCurrentUser,
  required ReplyPopupConfiguration? replyPopup,
}) {
  // Calculate position - you might need to adjust this based on your message widget position
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  
  showDialog(
    context: context,
    barrierColor: Colors.transparent, // Make background transparent
    builder: (context) {
      return Stack(
        children: [
          // Background overlay that closes when tapped
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                _onChatListTap();
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // Custom popup positioned near the center/bottom
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.3, // Adjust this value to position vertically
            left: 20,
            right: 20,
            child: Center(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  width: 300,
                  //height:screenHeight,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   decoration: BoxDecoration(
                    //color:Color(0xFF90CAF9),
                    color:Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    /* boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ], */
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPopupAction(
                        icon: Icons.reply,
                        text: 'Reply',
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.assignReplyMessage(message);
                          if (featureActiveConfig?.enableReactionPopup ?? false) {
                            showPopUp.value = false;
                          }
                          if (replyPopup?.onReplyTap != null) {
                            replyPopup?.onReplyTap!(message);
                          }
                        },
                      ),
                      _buildPopupAction(
                        icon: Icons.copy,
                        text: 'Copy',
                        onTap: () {
                          Navigator.of(context).pop();
                          Clipboard.setData(ClipboardData(text: message.message));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      /* _buildPopupAction(
                        icon: Icons.confirmation_num, // Ticket icon
                        text: 'Create Ticket',
                        onTap: () {
                          Navigator.of(context).pop();
                          //_createTicket(context, message);
                        },
                      ), */
                      _buildPopupAction(
                        icon: Icons.translate,
                        text: 'Translate',
                        onTap: () {
                          Navigator.of(context).pop();
                          _translateMessage(message);
                        },
                      ),
                      /* _buildPopupAction(
                        icon: Icons.delete_outline,
                        text: 'Delete',
                        onTap: () {
                          Navigator.of(context).pop();
                          if (replyPopup?.onUnsendTap != null) {
                            // Handle delete action
                          }
                        },
                      ), */
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/*Widget _buildPopupAction({
  required IconData icon,
  required String text,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
          SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
} */
/* void _showCustomMessagePopup({
  required BuildContext context,
  required Message message,
  required bool sendByCurrentUser,
  required ReplyPopupConfiguration? replyPopup,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  

  showDialog(
    context: context,
    barrierColor: Colors.transparent,
    builder: (context) {
      return Stack(
        children: [
          // Tap outside to close
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                _onChatListTap();
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          // Popup UI
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.3,
            left: 20,
            right: 20,
            child: Center(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: 280,
                    maxWidth: screenWidth - 32,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPopupAction(
                        icon: Icons.reply,
                        text: 'Reply',
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.assignReplyMessage(message);
                          if (featureActiveConfig?.enableReactionPopup ??
                              false) {
                            showPopUp.value = false;
                          }
                          if (replyPopup?.onReplyTap != null) {
                            replyPopup?.onReplyTap!(message);
                          }
                        },
                      ),
                      _buildPopupAction(
                        icon: Icons.copy,
                        text: 'Copy',
                        onTap: () {
                          Navigator.of(context).pop();
                          Clipboard.setData(
                              ClipboardData(text: message.message));
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      _buildPopupAction(
                        icon: Icons.translate,
                        text: 'Translate',
                        onTap: () {
                          Navigator.of(context).pop();
                          _translateMessage(message);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
} */

void _createTicket(BuildContext context, Message message) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return CreateTicketBottomSheet(
        message: message,
      );
    },
  );
}

Widget _buildPopupAction({
  required IconData icon,
  required String text,
  required VoidCallback onTap,
}) {
  return Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.black),
            const SizedBox(height: 2),
            Text(
              text,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                letterSpacing: 0.25,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _translateMessage(Message message) async {
  final prefs = await SharedPreferences.getInstance();
  final String? uuid = prefs.getString('uuid');
  final String? team_alias = prefs.getString('team_alias');

  if (uuid == null) {
    print("UUID is null. Please check the stored value.");
    return;
  }

  final url = base_url + 'api/translate/';
  var headers = {
    'Authorization': "$uuid|$team_alias",
    'Content-Type': 'application/json',
  };
  var request = http.Request('POST', Uri.parse(url));
  request.body = json.encode({
    "source": "mobileapp",
    "message_id": message.message_id,
  });
  request.headers.addAll(headers);

  http.StreamedResponse response = await request.send();

  if (response.statusCode == 200) {
    var responseBody = await response.stream.bytesToString();
    var jsonResponse = json.decode(responseBody);
    if (jsonResponse['success'] == "true") {
      final sourceLanguage = jsonResponse['source_language'];
      final translatedMessage = jsonResponse['translated_message_text'];

      if (mounted) {
        // ✅ Use root context (this.context)
        _showTranslationDialog(this.context, translatedMessage, sourceLanguage, message);
      }
    } else {
      print("Translation failed: ${jsonResponse['message']}");
    }
  } else {
    print(response.reasonPhrase);
  }
}

void _showTranslationDialog(
  BuildContext context,
  String translatedMessage,
  String sourceLanguage,
  Message message,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0059FC), Color(0xFF820AFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.language, color: Colors.white, size: 18),
                              SizedBox(width: 5),
                              Text(
                                "Translate",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Translated content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          child: Card(
                            color: const Color(0xFF90CAF9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 5,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Translation From $sourceLanguage",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    translatedMessage,
                                    style: const TextStyle(color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // OK Button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: () {
                          message.translate_content = translatedMessage;
                          message.translate_title = sourceLanguage;
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 58),
                        ),
                        child: const Text(
                          'Ok',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
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
  );
}
  void _onChatListTap() {
    widget.onChatListTap?.call();
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      FocusScope.of(context).unfocus();
    }
    showPopUp.value = false;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  @override
  void dispose() {
    chatController.messageStreamController.close();
    scrollController.dispose();
    _isNextPageLoading.dispose();
    showPopUp.dispose();
    super.dispose();
  }
}

class CreateTicketBottomSheet extends StatefulWidget {
  final Message message;

  const CreateTicketBottomSheet({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  State<CreateTicketBottomSheet> createState() => _CreateTicketBottomSheetState();
}

class _CreateTicketBottomSheetState extends State<CreateTicketBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedAgent;
  String? _selectedDepartment;
  String? _selectedLabel;
  List<String> _attachments = [];

  List<String> agents = ['John Doe', 'Jane Smith', 'Mike Johnson', 'Sarah Wilson'];
  List<String> departments = ['Technical Support', 'Sales', 'Billing', 'General Inquiry'];
  List<String> labels = ['Urgent', 'High', 'Medium', 'Low', 'Bug', 'Feature Request'];

  @override
  void initState() {
    super.initState();
    // Pre-fill description with message content
    _descriptionController.text = widget.message.message;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Header
            Container(
              height: 60,
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Create New Ticket',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '0', // You can make this dynamic
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description text
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          'Create and manage customer support tickets by providing a clear title, detailed description, and uploading any necessary files. Assign the ticket to the right contact and team to ensure a quick resolution.',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      // Ticket Title
                      Text(
                        'Ticket Title *',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'Enter a brief and clear title that summarizes the issue or request',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a ticket title';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      
                      // Ticket Description
                      Text(
                        'Ticket Description *',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Provide details of the issue or request, including any necessary context or specifics to help resolve it.',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a ticket description';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      
                      // Assigning Agent
                      Text(
                        'Assigning Agent',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedAgent,
                          hint: Text('Select the agent responsible for addressing this ticket'),
                          isExpanded: true,
                          underline: SizedBox(),
                          items: agents.map((String agent) {
                            return DropdownMenuItem<String>(
                              value: agent,
                              child: Text(agent),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedAgent = newValue;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      // Upload Attachment
                      Text(
                        'Upload Attachment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.attach_file, size: 40, color: Colors.grey[500]),
                            SizedBox(height: 8),
                            Text(
                              'Attach any supporting files, such as screenshots or documents, to help explain the issue or request.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _uploadAttachment,
                              icon: Icon(Icons.add),
                              label: Text('Add Attachment'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      // Assigning Department
                      Text(
                        'Assigning Department',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedDepartment,
                          hint: Text('Choose the department best suited to handle this ticket'),
                          isExpanded: true,
                          underline: SizedBox(),
                          items: departments.map((String department) {
                            return DropdownMenuItem<String>(
                              value: department,
                              child: Text(department),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedDepartment = newValue;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      // Assigning Label
                      Text(
                        'Assigning Label',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedLabel,
                          hint: Text('Add a relevant label to categorize or prioritize the ticket for better tracking'),
                          isExpanded: true,
                          underline: SizedBox(),
                          items: labels.map((String label) {
                            return DropdownMenuItem<String>(
                              value: label,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedLabel = newValue;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 30),
                      
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _submitTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _uploadAttachment() {
    // Implement file upload logic here
    // This could use file_picker package or image_picker
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upload Attachment'),
        content: Text('Choose attachment type:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement camera
            },
            child: Text('Camera'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement gallery
            },
            child: Text('Gallery'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement file picker
            },
            child: Text('Files'),
          ),
        ],
      ),
    );
  }

  void _submitTicket() {
    if (_formKey.currentState!.validate()) {
      // Process ticket creation
      final ticketData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'agent': _selectedAgent,
        'department': _selectedDepartment,
        'label': _selectedLabel,
        'attachments': _attachments,
        'original_message': widget.message.toJson(),
      };
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop();
      
      // You can also call your API here to create the ticket
      // _createTicketAPI(ticketData);
    }
  }
}
