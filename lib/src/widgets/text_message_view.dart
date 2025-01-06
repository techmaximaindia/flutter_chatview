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
import 'package:flutter/material.dart';

import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/models/models.dart';
import 'package:chatview/src/models/chat_user.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/models.dart';
import '../utils/constants/constants.dart';
import '../values/typedefs.dart';
import 'link_preview.dart';
import 'reaction_widget.dart';
import 'package:intl/intl.dart';
import 'reply_popup_widget.dart';
import 'reply_message_widget.dart';
import 'package:flutter/services.dart';
import 'chat_list_widget.dart';
import 'send_message_widget.dart';
import 'swipe_to_reply.dart';

class TextMessageView extends StatelessWidget {
  const TextMessageView({
    Key? key,
    required this.isMessageBySender,
    required this.message,
    this.chatBubbleMaxWidth,
    this.inComingChatBubbleConfig,
    this.outgoingChatBubbleConfig,
    this.messageReactionConfig,
    this.highlightMessage = false,
    this.highlightColor,
    this.currentUser,
    
/*     this.replyPopupConfig,
    this.repliedMessageConfig, */
  }) : super(key: key);

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  /// Provides message instance of chat.
  final Message message;

  /// Allow users to give max width of chat bubble.
  final double? chatBubbleMaxWidth;

  /// Provides configuration of chat bubble appearance from other user of chat.
  final ChatBubble? inComingChatBubbleConfig;

  /// Provides configuration of chat bubble appearance from current user of chat.
  final ChatBubble? outgoingChatBubbleConfig;

  /// Provides configuration of reaction appearance in chat bubble.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Represents message should highlight.
  final bool highlightMessage;

  /// Allow user to set color of highlighted message.
  final Color? highlightColor;

  /// Represents the current user.
  final ChatUser? currentUser;
  /* final ReplyMessageCallBack? onReplyTap; */
/* 
  final RepliedMessageConfiguration? repliedMessageConfig;

  final ReplyPopupConfiguration? replyPopupConfig; */

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textMessage = message.message;
    DateTime createdAt = message.createdAt;
    String formattedTime = DateFormat('hh:mm a').format(createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              constraints: BoxConstraints(
                  maxWidth: chatBubbleMaxWidth ??
                      MediaQuery.of(context).size.width * 0.75),
              padding: _padding ??
                  const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
              margin: _margin ??
                  EdgeInsets.fromLTRB(
                      5, 0, 6, message.reaction.reactions.isNotEmpty ? 15 : 2),
              decoration: BoxDecoration(
                color: highlightMessage ? highlightColor : _color,
                borderRadius: _borderRadius(textMessage),
              ),
              child:textMessage.isUrl
                      ? LinkPreview(
                          linkPreviewConfig: _linkPreviewConfig,
                          url: textMessage,
                        )
                      : _buildMessageContent(textMessage, textTheme),/* Text(
                          textMessage,
                          style: _textStyle ??
                            textTheme.bodyMedium!.copyWith(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                        ), */
            ),
            if (message.reaction.reactions.isNotEmpty)
              ReactionWidget(
                key: key,
                isMessageBySender: isMessageBySender,
                reaction: message.reaction,
                messageReactionConfig: messageReactionConfig,
              ),
          ],
        ),
        
        SizedBox(height: 3),
         if (isMessageBySender) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.profilename == 'Bot') ...[
                Icon(
                  Icons.smart_toy_outlined,
                  size: 10,
                  color: Colors.black54,
                ),
                SizedBox(width: 4),
                Text(
                  'Bot',
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
                SizedBox(width: 4),
              ] else ...[
                Icon(
                  Icons.person,
                  size: 10,
                  color: Colors.black54,
                ),
                SizedBox(width: 4),
                Text(
                  message.profilename ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(width: 4),
              ],
              Icon(
                Icons.access_time,
                size: 10,
                color: Colors.black54,
              ),
              SizedBox(width: 4),
              Text(
                formattedTime,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time,
                size: 10,
                color: Colors.black54,
              ),
              SizedBox(width: 4),
              Text(
                formattedTime,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
  Widget _buildMessageContent(String textMessage, TextTheme textTheme) 
  {
    final document = html_parser.parse(textMessage);
    final String parsedString = document.body?.text ?? '';
    final String translated_title = message.translate_title??'';
    final String translated_content = message.translate_content??'';

    if (translated_title != '' && translated_content != '') 
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            textMessage,
            style: _textStyle ??
              textTheme.bodyMedium!.copyWith(
                color: Colors.black,
                fontSize: 16,
              ),
          ),
          SizedBox(height:4),
          Text(
            "Translation From $translated_title",
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            translated_content,
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
            ),
          ),
        ],
      );
    }
    else if (parsedString.isNotEmpty && parsedString != textMessage) 
    {
      return Html(
        data: textMessage,
        style: {
          'body': Style(
            fontSize: FontSize(16),
            color: Colors.black,
          ),
        },
        onLinkTap: (url, _, __) async{
          if (url != null && url !='') {
            final uri = Uri.parse(url!);
            if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
            }
          }
        },
      );
    } 
    else 
    {
      return Text(
        textMessage,
        style: _textStyle ??
            textTheme.bodyMedium!.copyWith(
              color: Colors.black,
              fontSize: 16,
            ),
      );
    }
  }

  EdgeInsetsGeometry? get _padding => isMessageBySender
      ? outgoingChatBubbleConfig?.padding
      : inComingChatBubbleConfig?.padding;

  EdgeInsetsGeometry? get _margin => isMessageBySender
      ? outgoingChatBubbleConfig?.margin
      : inComingChatBubbleConfig?.margin;

  LinkPreviewConfiguration? get _linkPreviewConfig => isMessageBySender
      ? outgoingChatBubbleConfig?.linkPreviewConfig
      : inComingChatBubbleConfig?.linkPreviewConfig;

  TextStyle? get _textStyle => isMessageBySender
      ? outgoingChatBubbleConfig?.textStyle
      : inComingChatBubbleConfig?.textStyle;

  BorderRadiusGeometry _borderRadius(String message) => isMessageBySender
      ? outgoingChatBubbleConfig?.borderRadius ??
          (message.length < 37
              ? BorderRadius.circular(17)
              : BorderRadius.circular(replyBorderRadius2))
      : inComingChatBubbleConfig?.borderRadius ??
          (message.length < 29
              ? BorderRadius.circular(17)
              : BorderRadius.circular(replyBorderRadius2));

  Color get _color => isMessageBySender
      ? outgoingChatBubbleConfig?.color ?? Colors.purple
      : inComingChatBubbleConfig?.color ?? Colors.white;
}
