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
import 'reply_popup_overlay.dart';
import 'package:file_picker/file_picker.dart';

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

  ValueNotifier<bool> replyshowPopUp = ValueNotifier(false);
  
  final GlobalKey<ReplyPopupState> _replyPopupKey = GlobalKey();
  
  final ValueNotifier<bool> _showScrollToBottomButton = ValueNotifier<bool>(false);
  bool _isScrolling = false;

  ChatController get chatController => widget.chatController;

  List<Message> get messageList => chatController.initialMessageList;

  ScrollController get scrollController => chatController.scrollController;

  bool get showTypingIndicator => widget.showTypingIndicator;

  ChatBackgroundConfiguration get chatBackgroundConfig =>
      widget.chatBackgroundConfig;

  FeatureActiveConfig? featureActiveConfig;
  ChatUser? currentUser;
  Message? _selectedMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showScrollToBottomButton.value = true;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (provide != null) {
      featureActiveConfig = provide!.featureActiveConfig;
      currentUser = provide!.currentUser;
    }
    if (featureActiveConfig?.enablePagination ?? false) {
      scrollController.addListener(_pagination);
    }
    scrollController.addListener(_scrollListener);
  }
  void _scrollListener() {
    if (!mounted) return;
    
    final isScrollToBottomEnabled = featureActiveConfig?.enableScrollToBottomButton ?? true;
    if (!isScrollToBottomEnabled) {
      _showScrollToBottomButton.value = false;
      return;
    }
    
    final isAtBottom = scrollController.position.pixels <= 
        scrollController.position.minScrollExtent + 100; 
    
    if (!isAtBottom && !_showScrollToBottomButton.value) {
      _showScrollToBottomButton.value = true;
    } else if (isAtBottom && _showScrollToBottomButton.value) {
      _showScrollToBottomButton.value = false;
    }
  }

  void _scrollToBottom() {
    if (_isScrolling || !scrollController.hasClients) return;
    
    _isScrolling = true;
    
    scrollController.animateTo(
      scrollController.position.minScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    ).then((_) {
      if (mounted) {
        _isScrolling = false;
        _showScrollToBottomButton.value = false;
      }
    });
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
                        _replyPopupKey.currentState?.refreshWidget(
                          message: message,
                          xCoordinate: xCoordinate,
                          yCoordinate: yCoordinate < 0
                              ? -(yCoordinate) - 5
                              : yCoordinate,
                        );
                        replyshowPopUp.value = true;
                      }
                      
                    },
                    onChatListTap:_onChatListTap,
                  ),
                  //if (featureActiveConfig?.enableScrollToBottomButton ?? true)
                    ValueListenableBuilder<bool>(
                      valueListenable: _showScrollToBottomButton,
                      builder: (_, showButton, __) {
                        return Positioned(
                          bottom: showButton ? 80 : -100,
                          right: 20,
                          child: GestureDetector( 
                            onTap: () {
                              _scrollToBottom();
                            },
                            child: Container(
                              width: 40,
                              height: 35,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.keyboard_double_arrow_down_outlined,
                                color: Colors.black,
                                size: 25,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                  if (featureActiveConfig?.enableReplySnackBar ?? false)
                      ValueListenableBuilder<bool>(
                        valueListenable: replyshowPopUp,
                        builder: (_, showReplyValue, __) {
                          return ReplyPopup(
                            key: _replyPopupKey,
                            onTap: () {
                              replyshowPopUp.value = false;
                              _onChatListTap();
                            },
                            replyshowPopUp: showReplyValue,
                            onReplyTap: (message) {
                              
                              widget.assignReplyMessage(message);
                            },
                            onCopyTap: (message) {
                              
                              Clipboard.setData(ClipboardData(text: message.message));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Copied to clipboard'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            onTranslateTap: (message) {
                              _translateMessage(message);
                            },
                            onTicketTap: (message) {
                              _createTicket(context, message);
                            },
                            onDeleteTap: (message) {
                              _showDeleteConfirmationDialog(message);
                            },
                          );
                        },
                      ),
                    
                  /* if (featureActiveConfig?.enableReactionPopup ?? false)
                    ReactionPopup(
                      key: _reactionPopupKey,
                      reactionPopupConfig: widget.reactionPopupConfig,
                      onTap: _onChatListTap,
                      showPopUp: showPopupValue,
                    ), */
                ],
              );
            },
          ),
        ),
      ],
    );
  }
  void _showDeleteConfirmationDialog(Message message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            constraints: BoxConstraints(minWidth: 400), 
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        "Delete Message – Confirmation",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        softWrap: true, 
                      ),
                    ),
                    SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 20),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                
               
                Text("Are you sure you want to delete this message?"),
                SizedBox(height: 16),
                
            
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Warning",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "This action is permanent and cannot be reversed. Please confirm if you wish to proceed.",
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                
               
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deleteMessage(message);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text(
                      "Delete",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<void> _deleteMessage(Message message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? uuid = prefs.getString('uuid');
      final String? team_alias = prefs.getString('team_alias');
      final String? conversation_id = prefs.getString('conversation_id');

      var headers = {
        'Authorization': '$uuid|$team_alias',
        'Content-Type': 'application/json',
      };

      var request = http.Request('POST', Uri.parse(base_url+'/api/delete_message/'));
      request.body = json.encode({
        "source": "mobileapp",
        "cb_reference_messsage_sid":message.id ?? '',
        "conversation_alias": conversation_id ?? '',
      });
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        print('Message deleted successfully: $responseBody');

        Map<String, dynamic> responseData = json.decode(responseBody);
        
        if (responseData['success'] == "true") {
          chatController.removeMessageById(message.message_id ?? '');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Message deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting message: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  void _createTicket(BuildContext context, Message message,) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return CreateTicketBottomSheet(
          message: message,
          messageId: message.message_id,
        );
      },
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
    replyshowPopUp.value = false;
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
  final String messageId;
  const CreateTicketBottomSheet({
    Key? key,
    required this.message,
     required this.messageId,
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
  List<String> _selectedLabels = [];
  List<PlatformFile> _attachments = []; 
  
  List<String> agentname_list = [];
  List<String> agentid_list = [];
  List<String> departmentname_list = [];
  List<String> departmentid_list = [];
  List<String> labelnamelist = [];
  List<String> labelnameid = [];

  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.message.message;
     _loadData();
  }
  Future<void> _loadData() async {
    await Future.wait([
      getagent(),
      getdepartment(),
      getlabel(),
    ]);
    setState(() {
      _isLoading = false;
    });
  }
  Future<void> getagent() async {
    final prefs = await SharedPreferences.getInstance();
    final String? uuid = prefs.getString('uuid');
    final String? team_alias = prefs.getString('team_alias');

    String url = base_url+'/api/agent/'; 

    try {
      var client = http.Client();
      var request = http.Request('GET', Uri.parse(url))
        ..headers.addAll({
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "$uuid|$team_alias",
        })
        ..body = jsonEncode({
          "source": "mobileapp"
        });

      var response = await client.send(request);
      var httpResponse = await http.Response.fromStream(response);
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(httpResponse.body) as Map<String, dynamic>;
        List<dynamic> agentlist = jsonResponse['data'];
        List<String> agentname = agentlist
            .map<String>((agent) => agent['name'] as String)
            .toList();
        List<String> agentid = agentlist
            .map<String>((agent) => agent['user_id'] as String)
            .toList();
        setState(() {
          agentname_list = agentname;
          agentid_list = agentid;
        });
      } else {
        print('Failed to load agents. Status Code: ${response.statusCode}');
      }
    } catch (error) {
      print('Error loading agents: $error');
    }
  }

  Future<void> getdepartment() async {
    final prefs = await SharedPreferences.getInstance();
    final String? uuid = prefs.getString('uuid');
    final String? team_alias = prefs.getString('team_alias');
    String url = base_url+'/api/department/'; 

    try {
      var client = http.Client();
      var request = http.Request('GET', Uri.parse(url))
        ..headers.addAll({
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "$uuid|$team_alias",
        })
        ..body = jsonEncode({
          "source": "mobileapp"
        });

      var response = await client.send(request);
      var httpResponse = await http.Response.fromStream(response);
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(httpResponse.body) as Map<String, dynamic>;
        List<dynamic> departmentList = jsonResponse['data'];
        List<String> departmentid = departmentList
            .map<String>((dept) => dept['cb_department_id'] as String)
            .toList();
        List<String> departmentNames = departmentList
            .map<String>((dept) => dept['cb_department_name'] as String)
            .toList();
        setState(() {
          departmentname_list = departmentNames;
          departmentid_list = departmentid;
        });
      } else {
        print('Failed to load departments. Status Code: ${response.statusCode}');
      }
    } catch (error) {
      print('Error loading departments: $error');
    }
  }

  Future<void> getlabel() async {
    final prefs = await SharedPreferences.getInstance();
    final String? uuid = prefs.getString('uuid');
    final String? team_alias = prefs.getString('team_alias');
    String url = base_url+'/api/label/'; 
    try {
      var response = await http.get(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "$uuid|$team_alias",
        },
      );
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        List<dynamic> labellist = jsonResponse['data'];
        List<String> labelname = labellist
            .map<String>((labels) => labels['cb_label_name'] as String)
            .toList();
        List<String> label_id = labellist
            .map<String>((labels) => labels['cb_label_id'] as String)
            .toList();
        setState(() {
          labelnamelist = labelname;
          labelnameid = label_id;
        });
      } else {
        print('Failed to load labels. Status Code: ${response.statusCode}');
      }
    } catch (error) {
      print('Error loading labels: $error');
    }
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
                  Container(width: 40),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Create New Ticket',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white), 
                    onPressed: () =>Navigator.of(context).pop()
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
                          items: agentname_list.map((String agent) {
                            return DropdownMenuItem<String>(
                              value: agent,
                              child: Text(agent),
                            );
                          }).toList(),
                          onChanged: agentname_list.isEmpty ? null : (String? newValue) {
                            setState(() {
                              _selectedAgent = newValue;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      Text(
                        'Upload Attachment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      
                      if (_attachments.isNotEmpty) ...[
                        Column(
                          children: _attachments.map((file) => ListTile(
                            leading: _getFileIcon(file),
                            title: Text(
                              file.name,
                              style: TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${(file.size / 1024 / 1024).toStringAsFixed(2)} MB',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeAttachment(file),
                            ),
                          )).toList(),
                        ),
                        SizedBox(height: 10),
                      ],
                      
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
                              'Attach a supporting file (max 1 file), such as screenshot or document, to help explain the issue.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _attachments.isNotEmpty ? null : _pickFiles, 
                                  icon: Icon(Icons.folder_open, color: _attachments.isNotEmpty ? Colors.grey : Colors.white),
                                  label: Text(
                                    'Files',
                                    style: TextStyle(color: _attachments.isNotEmpty ? Colors.grey : Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _attachments.isNotEmpty ? Colors.grey[400] : Colors.blue[700],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _attachments.isNotEmpty ? null : _pickImages,
                                  icon: Icon(Icons.photo, color: _attachments.isNotEmpty ? Colors.grey : Colors.white),
                                  label: Text(
                                    'Images',
                                    style: TextStyle(color: _attachments.isNotEmpty ? Colors.grey : Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _attachments.isNotEmpty ? Colors.grey[400] : Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                            /* Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _pickFiles(),
                                  icon: Icon(Icons.folder_open, color: Colors.white),
                                  label: Text(
                                    'Files',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _pickImages(),
                                  icon: Icon(Icons.photo, color: Colors.white),
                                  label: Text(
                                    'Images',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[700],
                                  ),
                                ),
                              ],
                            ), */
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      
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
                          items:departmentname_list.map((String department) {
                            return DropdownMenuItem<String>(
                              value: department,
                              child: Text(department),
                            );
                          }).toList(),
                          onChanged: departmentname_list.isEmpty ? null :(String? newValue) {
                            setState(() {
                              _selectedDepartment = newValue;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      Text(
                        'Assigning Label',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      
                      if (labelnamelist.isNotEmpty) ...[
                        SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 180, // Maximum height before scrolling
                          ),
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: labelnamelist.map((label) {
                                bool isSelected = _selectedLabels.contains(label);
                                return FilterChip(
                                  label: Text(label),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedLabels.add(label);
                                      } else {
                                        _selectedLabels.remove(label);
                                      }
                                    });
                                  },
                                  selectedColor: Colors.blue[100],
                                  checkmarkColor: Colors.blue,
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 30),
                      
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

  Widget _getFileIcon(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    if (extension == 'pdf') {
      return Icon(Icons.picture_as_pdf, color: Colors.red);
    } else if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      return Icon(Icons.image, color: Colors.green);
    } else if (['doc', 'docx'].contains(extension)) {
      return Icon(Icons.description, color: Colors.blue);
    } else if (['xls', 'xlsx'].contains(extension)) {
      return Icon(Icons.table_chart, color: Colors.green);
    } else {
      return Icon(Icons.insert_drive_file, color: Colors.grey);
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png', 'gif', 'txt'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachments = [result.files.first]; // Replace instead of add
        });
      }  
      /* if (result != null) {
        setState(() {
          _attachments.addAll(result.files);
        });
      } */
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImages() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachments = [result.files.first]; // Replace instead of add
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeAttachment(PlatformFile file) {
    setState(() {
      _attachments.remove(file);
    });
  }
    Future<void> _submitTicket() async {
    if (_formKey.currentState!.validate()) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? uuid = prefs.getString('uuid');
        final String? team_alias = prefs.getString('team_alias');

        String? selectedAgentId;
        String? selectedDepartmentId;
        String? selectedLabelIds;

        if (_selectedAgent != null) {
          int agentIndex = agentname_list.indexOf(_selectedAgent!);
          if (agentIndex != -1 && agentIndex < agentid_list.length) {
            selectedAgentId = agentid_list[agentIndex];
          }
        }

        if (_selectedDepartment != null) {
          int deptIndex = departmentname_list.indexOf(_selectedDepartment!);
          if (deptIndex != -1 && deptIndex < departmentid_list.length) {
            selectedDepartmentId = departmentid_list[deptIndex];
          }
        }

        if (_selectedLabels.isNotEmpty) {
          List<String> selectedLabelIdsList = [];
          for (String labelName in _selectedLabels) {
            int labelIndex = labelnamelist.indexOf(labelName);
            if (labelIndex != -1 && labelIndex < labelnameid.length) {
              selectedLabelIdsList.add(labelnameid[labelIndex]);
            }
          }
          selectedLabelIds = selectedLabelIdsList.join(',');
        }

        var headers = {
          'Authorization': '$uuid|$team_alias',
        };

        var request = http.MultipartRequest(
          'POST', 
          Uri.parse(base_url+'/api/ticket/create_ticket/')
        );

        request.fields.addAll({
          'source': 'mobileapp',
          'ticket_title': _titleController.text,
          'ticket_description': _descriptionController.text,
          'cb_message_id': widget.messageId??'',
          'cb_last_agent_id': selectedAgentId ?? '',
          'cb_last_dept_id': selectedDepartmentId ?? '',
          'cb_label_id': selectedLabelIds ?? '',
        });

        for (PlatformFile file in _attachments) {
          if (file.path != null) {
            request.files.add(await http.MultipartFile.fromPath(
              'file', 
              file.path!,
              filename: file.name,
            ));
          }
        }

        request.headers.addAll(headers);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 20),
                    Text("Creating Ticket..."),
                  ],
                ),
              ),
            );
          },
        );

        http.StreamedResponse response = await request.send();

        Navigator.of(context).pop();

        if (response.statusCode == 200) {
          String responseBody = await response.stream.bytesToString();
          Map<String, dynamic> responseData = json.decode(responseBody);
          if (responseData['status'] == "true") {
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text("Success"),
                  ],
                ),
                content: Text("Ticket created successfully!"),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); 
                      Navigator.of(context).pop();
                      
                    },
                    child: Text("OK"),
                  ),
                ],
              );
            },
          );
        } else {
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create ticket:'),
              backgroundColor: Colors.red,
            ),
          );
        }
          
         // Navigator.of(context).pop();
        } else {
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create ticket'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (error) {
        
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating ticket'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
