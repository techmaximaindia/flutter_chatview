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
import '../extensions/extensions.dart';
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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'WebViewExample.dart';

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
                      : _buildMessageContent(context,textMessage, textTheme),/* Text(
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
              ] else if(message.profilename=='Summary') ...[
                FaIcon(
                  FontAwesomeIcons.magicWandSparkles,
                  color: Colors.black,
                  size: 10,
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
              ] 
              else ...[
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
  Widget _buildMessageContent(context,String textMessage, TextTheme textTheme) {
  final document = html_parser.parse(textMessage);
  final String parsedString = document.body?.text ?? '';
  String translated_title = message.translate_title ?? '';
  String translated_content = message.translate_content ?? '';

  final urlPattern = r'http[s]?://[^\s]+';
  final urlRegExp = RegExp(urlPattern);

  // Check for embedded iframe tags (extract the src URL)
  final iframeTags = document.getElementsByTagName('iframe');
  final iframeUrls = iframeTags.map((iframe) => iframe.attributes['src']).toList();

  var message_options_full = message.cb_message_options_full;
    String? type = message_options_full?['type'];
    /* List<String> buttonValues = List<String>.from(message_options_full?['button_values'] ?? []); */
    List<String> buttonValues = (message_options_full?['button_values'] as List<dynamic>?)
    ?.map((e) => e.toString())
    .toList() ?? [];

    
    /* List<String> listDesc = List<String>.from(message_options_full?['list_desc'] ?? []); */
    List<String> listDesc = (message_options_full?['list_desc'] as List<dynamic>?)
    ?.map((e) => e.toString())
    .toList() ?? [];

    String? list_menu_header=message_options_full?['list_menu_header']??'';
    String? list_header=message_options_full?['list_header']??'';
    String? header=message_options_full?['header']??'';
    String? footer=message_options_full?['footer']??'';
    final bool containsHtmlTags = RegExp(r'<[^>]+>').hasMatch(textMessage);

  if (translated_title.isNotEmpty && translated_content.isNotEmpty) {
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
        SizedBox(height: 4),
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
  } else if (iframeUrls.isNotEmpty) {
    return Column(
      children: iframeUrls.map((url) {
        if (url != null) {
          final uri = Uri.parse(url);
          return GestureDetector(
            onTap: () async {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: Text(
              uri.toString(),
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          );
        }
        return SizedBox.shrink();
      }).toList(),
    );
  }/*else if (containsHtmlTags) {
    return Stack(
      children: [
        SizedBox(
          height: 300,
          child: IgnorePointer( 
            child: WebViewExample(htmlContent: textMessage),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExpandedWebView(htmlContent: textMessage),
                ),
              );
            },
            child: Container(color: Colors.transparent), 
          ),
        ),
      ],
    );
  }*/
   else if(containsHtmlTags){
     return Html(
        data: textMessage,
        
        onLinkTap: (url, _, __) async {
          if (url != null && url.isNotEmpty) {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          }
        },
        style: {
          "*": Style(
            color: Colors.black, 
          ),
          "a": Style(
            color: Colors.blue, 
            textDecoration: TextDecoration.underline,
          ),
        },
      );
   }
    else if (parsedString.isNotEmpty && parsedString != textMessage && !urlRegExp.hasMatch(parsedString)) {
    return Text(
      parsedString, // Display stripped text
      style: textTheme.bodyMedium?.copyWith(
        color: Colors.black,
        fontSize: 14,
      ),
    );
  } else if (parsedString != textMessage) {
    final textStyle = textTheme.bodyMedium!.copyWith(
    color: Colors.black,
    fontSize: 14,
  );
    return Html(
      data: textMessage,
      style: {
        'body': Style.fromTextStyle(textStyle),
        'a': Style.fromTextStyle(
          textStyle.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
        ),
      },
      onLinkTap: (url, _, __) async {
        if (url != null && url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
      },
    );
  }  
 else if (message.cb_message_options_full != null && type == "button") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header??'',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            textMessage,
            style: textTheme.bodyMedium!.copyWith(
              color: Colors.black,
              fontSize: 14,
            ),
          ),
          Text(
            footer??'',
            style: textTheme.bodyLarge?.copyWith(
              fontSize: 13,
              color: Color.fromARGB(255, 52, 58, 64),
            ),
          ),
          const SizedBox(height: 8),

          if (buttonValues.isNotEmpty && buttonValues!=[] && buttonValues!=null) 
            ...buttonValues.map((option) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ElevatedButton(
                  onPressed: () {
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.list,
                        color: Colors.blue,
                        size: 10, 
                      ),
                      const SizedBox(width: 4),
                      Text(
                        option.trim(),
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize:12
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      );
    } 
    else if (message.cb_message_options_full != null && type == "list") {
    
    void showCustomDialog(BuildContext buildcontext, String title, List<String> button, List<String> list) {
      showDialog(
        context: buildcontext,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                titlePadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                contentPadding: const EdgeInsets.all(5),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 3,
                          right: 0,
                          bottom: 1,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.black, size: 18),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 300,
                      width: 250,
                      child: SingleChildScrollView(
                        child: Column(
                          children: List.generate(button.length, (index) {
                            return InkWell(
                              onTap: () {},
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.0),
                                  color: Colors.grey[200],
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            button[index],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.visible,
                                            maxLines: null,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            list.isNotEmpty && index < list.length ? list[index] : "",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                            overflow: TextOverflow.visible,
                                            maxLines: null,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Radio(
                                        value: index,
                                        groupValue: null,
                                        onChanged: (value) {},
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(12.0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(10.0)),
                    ),
                    child: const Text("Tap to select an item", style: TextStyle(color: Colors.black)),
                  ),
                ],
              );
            },
          );
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header?? '',
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text(
          textMessage,
          style: textTheme.bodyMedium!.copyWith(
            color: Colors.black,
            fontSize: 14,
          ),
        ),
        Text(
          footer?? '',
          style: textTheme.bodyLarge?.copyWith(
            fontSize: 13,
            color: Color.fromARGB(255, 52, 58, 64),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: ElevatedButton(
            onPressed: () {
              showCustomDialog(context, list_menu_header!, buttonValues, listDesc);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min, 
              children: [
                const FaIcon(
                  FontAwesomeIcons.list,
                  color: Colors.blue,
                  size: 10,
                ),
                const SizedBox(width: 4), 
                Text(
                  list_menu_header ?? '',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize:12
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  else{
    return Text(
      textMessage,
      style: _textStyle ??
          textTheme.bodyMedium!.copyWith(
            color: Colors.black,
            fontSize: 14,
          ),
    );
  }
}

  /* Widget _buildMessageContent(String textMessage, TextTheme textTheme) 
  {
    final document = html_parser.parse(textMessage);
    final String parsedString = document.body?.text ?? '';
    final String translated_title = message.translate_title??'';
    final String translated_content = message.translate_content??'';

    final urlPattern = r'http[s]?://[^\s]+';
    final urlRegExp = RegExp(urlPattern);

    // Check for embedded iframe tags (extract the src URL)
    final iframeTags = document.getElementsByTagName('iframe');
    final iframeUrls = iframeTags.map((iframe) => iframe.attributes['src']).toList();
  
    
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
    else if (iframeUrls.isNotEmpty) 
    {
      return Column(
        children: iframeUrls.map((url) {
          if (url != null) {
            final uri = Uri.parse(url);
            return GestureDetector(
              onTap: () async {
                if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                }
              },
              child: Text(
                uri.toString(),
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            );
          }
          return SizedBox.shrink();
        }).toList(),
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
    } else if (message.cb_message_options_full != null && type == "button") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header??'',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            textMessage,
            style: textTheme.bodyMedium!.copyWith(
              color: Colors.black,
              fontSize: 14,
            ),
          ),
          Text(
            footer??'',
            style: textTheme.bodyLarge?.copyWith(
              fontSize: 13,
              color: Color.fromARGB(255, 52, 58, 64),
            ),
          ),
          const SizedBox(height: 8),

          if (buttonValues.isNotEmpty && buttonValues!=[] && buttonValues!=null) 
            ...buttonValues.map((option) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ElevatedButton(
                  onPressed: () {
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.list,
                        color: Colors.blue,
                        size: 10, 
                      ),
                      const SizedBox(width: 4),
                      Text(
                        option.trim(),
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize:12
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      );
    } 
     else if (message.cb_message_options_full != null && type == "list") {
    
     void showCustomDialog(BuildContext buildcontext, String title ,List<String> button, List<String> list) {
      showDialog(
        context: buildcontext,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                contentPadding: const EdgeInsets.all(10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                content: Container(
                  height: 300,
                  width: 200,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(button.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12.0),
                                  child: Text(
                                    button[index],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12.0),
                                  child:Text(
                                    list.isNotEmpty && index < list.length ? list[index] : "",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header?? '',
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text(
          textMessage,
          style: textTheme.bodyMedium!.copyWith(
            color: Colors.black,
            fontSize: 14,
          ),
        ),
        Text(
          footer?? '',
          style: textTheme.bodyLarge?.copyWith(
            fontSize: 13,
            color: Color.fromARGB(255, 52, 58, 64),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: ElevatedButton(
            onPressed: () {
              showCustomDialog(context, list_header!, buttonValues, listDesc);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min, 
              children: [
                const FaIcon(
                  FontAwesomeIcons.list,
                  color: Colors.blue,
                  size: 10,
                ),
                const SizedBox(width: 4), 
                Text(
                  list_menu_header ?? '',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize:12
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
    
    else 
    {
      return Text(
        textMessage,
        style: _textStyle ??
            textTheme.bodyMedium!.copyWith(
              color: Colors.black,
              fontSize: 14,
            ),
      );
    }
  } */

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

  /* Color get _color => isMessageBySender
      ? outgoingChatBubbleConfig?.color ?? Colors.purple
      : inComingChatBubbleConfig?.color ?? Colors.white; */
    Color get _color {
      if (message.profilename == 'Summary') {
        return Color.fromRGBO(255, 193, 7, 1.0);
      }
      return isMessageBySender
          ? outgoingChatBubbleConfig?.color ?? Color(0xFF90CAF9)
          : inComingChatBubbleConfig?.color ?? Colors.white;
    }

}
