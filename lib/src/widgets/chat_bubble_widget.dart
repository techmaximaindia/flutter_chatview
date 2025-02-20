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
import 'dart:convert';

import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/utils/constants/constants.dart';
import 'package:chatview/src/widgets/chat_view_inherited_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../chatview.dart';
import 'chatui_textfield.dart';
import 'message_time_widget.dart';
import 'message_view.dart';
import 'profile_circle.dart';
import 'reply_message_widget.dart';
import 'swipe_to_reply.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class ChatBubbleWidget extends StatefulWidget {
  const ChatBubbleWidget({
    required GlobalKey key,
    required this.message,
    required this.onLongPress,
    required this.slideAnimation,
    required this.onSwipe,
    this.profileCircleConfig,
    this.chatBubbleConfig,
    this.repliedMessageConfig,
    this.swipeToReplyConfig,
    this.messageTimeTextStyle,
    this.messageTimeIconColor,
    this.messageConfig,
    this.onReplyTap,
    this.shouldHighlight = false,
  }) : super(key: key);

  /// Represent current instance of message.
  final Message message;

  /// Give callback once user long press on chat bubble.
  final DoubleCallBack onLongPress;

  /// Provides configuration related to user profile circle avatar.
  final ProfileCircleConfiguration? profileCircleConfig;

  /// Provides configurations related to chat bubble such as padding, margin, max
  /// width etc.
  final ChatBubbleConfiguration? chatBubbleConfig;

  /// Provides configurations related to replied message such as textstyle
  /// padding, margin etc. Also, this widget is located upon chat bubble.
  final RepliedMessageConfiguration? repliedMessageConfig;

  /// Provides configurations related to swipe chat bubble which triggers
  /// when user swipe chat bubble.
  final SwipeToReplyConfiguration? swipeToReplyConfig;

  /// Provides textStyle of message created time when user swipe whole chat.
  final TextStyle? messageTimeTextStyle;

  /// Provides default icon color of message created time view when user swipe
  /// whole chat.
  final Color? messageTimeIconColor;

  /// Provides slide animation when user swipe whole chat.
  final Animation<Offset>? slideAnimation;

  /// Provides configuration of all types of messages.
  final MessageConfiguration? messageConfig;

  /// Provides callback of when user swipe chat bubble for reply.
  final MessageCallBack onSwipe;

  /// Provides callback when user tap on replied message upon chat bubble.
  final Function(String)? onReplyTap;

  /// Flag for when user tap on replied message and highlight actual message.
  final bool shouldHighlight;

  @override
  State<ChatBubbleWidget> createState() => _ChatBubbleWidgetState();
}

class _ChatBubbleWidgetState extends State<ChatBubbleWidget> {
  String get replyMessage => widget.message.replyMessage.message;

  bool get isMessageBySender => widget.message.sendBy == currentUser?.id;

  bool get isLastMessage =>
      chatController?.initialMessageList.last.id == widget.message.id;

  ProfileCircleConfiguration? get profileCircleConfig =>
      widget.profileCircleConfig;
  FeatureActiveConfig? featureActiveConfig;
  ChatController? chatController;
  ChatUser? currentUser;
  int? maxDuration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (provide != null) {
      featureActiveConfig = provide!.featureActiveConfig;
      chatController = provide!.chatController;
      currentUser = provide!.currentUser;
    }
  }
  @override
  Widget build(BuildContext context) {

    // Get user from id.
    final messagedUser = chatController?.getUserFromId(widget.message.sendBy);
    return Stack(
      children: [
        if (featureActiveConfig?.enableSwipeToSeeTime ?? true) ...[
          Visibility(
            visible: widget.slideAnimation?.value.dx == 0.0 ? false : true,
            child: Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: MessageTimeWidget(
                  messageTime: widget.message.createdAt,
                  isCurrentUser: isMessageBySender,
                  messageTimeIconColor: widget.messageTimeIconColor,
                  messageTimeTextStyle: widget.messageTimeTextStyle,
                ),
              ),
            ),
          ),
          SlideTransition(
            position: widget.slideAnimation!,
            child: _chatBubbleWidget(messagedUser),
          ),
        ] else
          _chatBubbleWidget(messagedUser),
      ],
    );
  }
  Future<String> _getValidatedImageUrl(ChatUser? messagedUser) async {
    if (messagedUser == null) return '';

    String constructedUrl;
    if (messagedUser.platform == "facebook") {
      constructedUrl = messagedUser.profilePhoto??'';
    } else {
      constructedUrl = messagedUser.profilePhoto ?? '';
    }

    // Validate the URL
    try {
      final response = await http.get(Uri.parse(constructedUrl));
      if (response.statusCode == 200) {
        return constructedUrl; // Return the valid URL
      } else {
        return ''; // Return empty string for invalid URLs
      }
    } catch (e) {
      return ''; // Return empty string if an error occurs
    }
  }

  Widget _chatBubbleWidget(ChatUser? messagedUser) {
  
    return Container(
      padding:
          widget.chatBubbleConfig?.padding ?? const EdgeInsets.only(left: 5.0),
      margin:
          widget.chatBubbleConfig?.margin ?? const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            isMessageBySender ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMessageBySender &&
              (featureActiveConfig?.enableOtherUserProfileAvatar ?? true))
              FutureBuilder<String>(
                future: _getValidatedImageUrl(messagedUser),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                    return ProfileCircle(
                      bottomPadding: widget.message.reaction.reactions.isNotEmpty
                          ? profileCircleConfig?.bottomPadding ?? 15
                          : profileCircleConfig?.bottomPadding ?? 2,
                      profileCirclePadding: profileCircleConfig?.padding,
                      imageUrl: snapshot.data!,
                      user_names: messagedUser?.chatmaxima_user_name ?? '',
                      platform: messagedUser?.platform,
                      circleRadius: profileCircleConfig?.circleRadius,
                      onTap: () => _onAvatarTap(messagedUser),
                      onLongPress: () => _onAvatarLongPress(messagedUser),
                    );
                  } else {
                    return ProfileCircle(
                      bottomPadding: widget.message.reaction.reactions.isNotEmpty
                          ? profileCircleConfig?.bottomPadding ?? 15
                          : profileCircleConfig?.bottomPadding ?? 2,
                      profileCirclePadding: profileCircleConfig?.padding,
                      imageUrl: '', // Use a placeholder image URL here
                      user_names: messagedUser?.chatmaxima_user_name ?? '',
                      platform: messagedUser?.platform,
                      circleRadius: profileCircleConfig?.circleRadius,
                      onTap: () => _onAvatarTap(messagedUser),
                      onLongPress: () => _onAvatarLongPress(messagedUser),
                    );
                  }
                },
              ),
            /* ProfileCircle(
              bottomPadding: widget.message.reaction.reactions.isNotEmpty
                  ? profileCircleConfig?.bottomPadding ?? 15
                  : profileCircleConfig?.bottomPadding ?? 2,
              profileCirclePadding: profileCircleConfig?.padding,
              imageUrl: messagedUser?.profilePhoto??'',
              user_names: messagedUser?.chatmaxima_user_name??'',
              platform: messagedUser?.platform,
              circleRadius: profileCircleConfig?.circleRadius,
              onTap: () => _onAvatarTap(messagedUser),
              onLongPress: () => _onAvatarLongPress(messagedUser),
            ),  */        
          Expanded(
            child: isMessageBySender
                ? SwipeToReply(
                      onLeftSwipe: featureActiveConfig?.enableSwipeToReply ?? true
                          ? () {
                              if (maxDuration != null) {
                                widget.message.voiceMessageDuration =
                                    Duration(milliseconds: maxDuration!);
                              }
                              if (widget.swipeToReplyConfig?.onLeftSwipe !=
                                  null) {
                                widget.swipeToReplyConfig?.onLeftSwipe!(
                                    widget.message.message,
                                    widget.message.sendBy);
                              }
                              widget.onSwipe(widget.message);
                            }
                          : null,
                      replyIconColor: widget.swipeToReplyConfig?.replyIconColor,
                      swipeToReplyAnimationDuration:
                          widget.swipeToReplyConfig?.animationDuration,
                          /* child: Row(
                            mainAxisSize: MainAxisSize.min,
                          children: [
                           /*  _buildPopupMenu(),
                            Expanded(child: _messagesWidgetColumn(messagedUser)), */
                          ],
                        ), */
                      child: _messagesWidgetColumn(messagedUser),
                    )
                : SwipeToReply(
                    onRightSwipe:
                        featureActiveConfig?.enableSwipeToReply ?? true
                            ? () {
                                if (maxDuration != null) {
                                  widget.message.voiceMessageDuration =
                                      Duration(milliseconds: maxDuration!);
                                }
                                if (widget.swipeToReplyConfig?.onRightSwipe !=
                                    null) {
                                  widget.swipeToReplyConfig?.onRightSwipe!(
                                      widget.message.message,
                                      widget.message.sendBy);
                                }
                                widget.onSwipe(widget.message);
                              }
                            : null,
                    replyIconColor: widget.swipeToReplyConfig?.replyIconColor,
                    swipeToReplyAnimationDuration:
                        widget.swipeToReplyConfig?.animationDuration,
                    child: _messagesWidgetColumn(messagedUser),
                  ),
                 
          ),
          if (isMessageBySender) ...[getReciept(),],
          if (isMessageBySender &&
              (featureActiveConfig?.enableCurrentUserProfileAvatar ?? true))
            ProfileCircle(
              bottomPadding: widget.message.reaction.reactions.isNotEmpty
                  ? profileCircleConfig?.bottomPadding ?? 15
                  : profileCircleConfig?.bottomPadding ?? 2,
              profileCirclePadding: profileCircleConfig?.padding,
              imageUrl: widget.message.chatmaxima_profile_image??'',
              user_names: widget.message.profilename??'',
              circleRadius: profileCircleConfig?.circleRadius,
              onTap: () => _onAvatarTap(messagedUser),
              onLongPress: () => _onAvatarLongPress(messagedUser),
            ),
        ],
      ),
    );
  }
  
  void _onAvatarTap(ChatUser? user) {
    if (profileCircleConfig?.onAvatarTap != null && user != null) {
      profileCircleConfig?.onAvatarTap!(user);
    }
  }

  Widget getReciept() {
    final showReceipts = widget.chatBubbleConfig?.outgoingChatBubbleConfig
            ?.receiptsWidgetConfig?.showReceiptsIn ??
        ShowReceiptsIn.lastMessage;
    if (showReceipts == ShowReceiptsIn.all) {
      return ValueListenableBuilder(
        valueListenable: widget.message.statusNotifier,
        builder: (context, value, child) {
          if (ChatViewInheritedWidget.of(context)
                  ?.featureActiveConfig
                  .receiptsBuilderVisibility ??
              true) {
            return widget.chatBubbleConfig?.outgoingChatBubbleConfig
                    ?.receiptsWidgetConfig?.receiptsBuilder
                    ?.call(value) ??
                sendMessageAnimationBuilder(value);
          }
          return const SizedBox();
        },
      );
    } else if (showReceipts == ShowReceiptsIn.lastMessage && isLastMessage) {
      return ValueListenableBuilder(
          valueListenable:
              chatController!.initialMessageList.last.statusNotifier,
          builder: (context, value, child) {
            if (ChatViewInheritedWidget.of(context)
                    ?.featureActiveConfig
                    .receiptsBuilderVisibility ??
                true) {
              return widget.chatBubbleConfig?.outgoingChatBubbleConfig
                      ?.receiptsWidgetConfig?.receiptsBuilder
                      ?.call(value) ??
                  sendMessageAnimationBuilder(value);
            }
            return sendMessageAnimationBuilder(value);
          });
    }
    return const SizedBox();
  }

  void _onAvatarLongPress(ChatUser? user) {
    if (profileCircleConfig?.onAvatarLongPress != null && user != null) {
      profileCircleConfig?.onAvatarLongPress!(user);
    }
  }

  Widget _messagesWidgetColumn(ChatUser? messagedUser) {
    DateTime createdAt = widget.message.createdAt;
    String formattedTime = DateFormat('hh:mm a').format(createdAt);
    return Column(
      crossAxisAlignment:
          isMessageBySender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [ 
        if (replyMessage.isNotEmpty)
          widget.repliedMessageConfig?.repliedMessageWidgetBuilder != null
              ? widget.repliedMessageConfig!
                  .repliedMessageWidgetBuilder!(widget.message.replyMessage)
              : ReplyMessageWidget(
                  message: widget.message,
                  repliedMessageConfig: widget.repliedMessageConfig,
                  onTap: () => widget.onReplyTap
                      ?.call(widget.message.replyMessage.messageId),
                ),
        MessageView(
          outgoingChatBubbleConfig:
              widget.chatBubbleConfig?.outgoingChatBubbleConfig,
          isLongPressEnable:
              (featureActiveConfig?.enableReactionPopup ?? true) ||
                  (featureActiveConfig?.enableReplySnackBar ?? true),
          inComingChatBubbleConfig:
              widget.chatBubbleConfig?.inComingChatBubbleConfig,
          message: widget.message,
          isMessageBySender: isMessageBySender,
          messageConfig: widget.messageConfig,
          onLongPress: widget.onLongPress,
          chatBubbleMaxWidth: widget.chatBubbleConfig?.maxWidth,
          longPressAnimationDuration:
              widget.chatBubbleConfig?.longPressAnimationDuration,
          onDoubleTap: featureActiveConfig?.enableDoubleTapToLike ?? false
              ? widget.chatBubbleConfig?.onDoubleTap ??
                  (message) => currentUser != null
                      ? chatController?.setReaction(
                          emoji: heart,
                          messageId: message.id,
                          userId: currentUser!.id,
                        )
                      : null
              : null,
          shouldHighlight: widget.shouldHighlight,
          controller: chatController,
          highlightColor: widget.repliedMessageConfig
                  ?.repliedMsgAutoScrollConfig.highlightColor ??
              Colors.grey,
          highlightScale: widget.repliedMessageConfig
                  ?.repliedMsgAutoScrollConfig.highlightScale ??
              1.1,
          onMaxDuration: _onMaxDuration,
        ),
      ],
    );
  }

  void _onMaxDuration(int duration) => maxDuration = duration;
}
