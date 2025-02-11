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
import 'dart:io';

import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/models/models.dart';
import 'package:flutter/material.dart';

import '../../chatview.dart';
import '../utils/constants/constants.dart';
import 'reaction_widget.dart';
import 'share_icon.dart';
import 'package:intl/intl.dart';
import 'text_message_view.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ImageMessageView extends StatelessWidget {
  const ImageMessageView({
    Key? key,
    required this.message,
    required this.isMessageBySender,
    this.imageMessageConfig,
    this.messageReactionConfig,
    this.highlightImage = false,
    this.highlightScale = 1.2,
    this.currentUser,
    this.inComingChatBubbleConfig,
    this.outgoingChatBubbleConfig,
    this.chatBubbleMaxWidth,
  }) : super(key: key);

  /// Provides message instance of chat.
  final Message message;

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  /// Provides configuration for image message appearance.
  final ImageMessageConfiguration? imageMessageConfig;

  /// Provides configuration of reaction appearance in chat bubble.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Represents flag of highlighting image when user taps on replied image.
  final bool highlightImage;

  /// Provides scale of highlighted image when user taps on replied image.
  final double highlightScale;
  final ChatUser? currentUser;
  String get imageUrl => message.message;
  /// Provides configuration of chat bubble appearance from other user of chat.
  final ChatBubble? inComingChatBubbleConfig;

  /// Provides configuration of chat bubble appearance from current user of chat.
  final ChatBubble? outgoingChatBubbleConfig;

  final double? chatBubbleMaxWidth;
  
  Widget get iconButton => ShareIcon(
        shareIconConfig: imageMessageConfig?.shareIconConfig,
        imageUrl: imageUrl,
      );
    void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageView(imageUrl: imageUrl),
      ),
    );
  }    
  
  @override
  Widget build(BuildContext context) {
    String formattedTime = DateFormat('hh:mm a').format(message.createdAt);
    String image_text_message=message.image_text_message;
    String translated_title = message.translate_title??'';
    String translated_content = message.translate_content??'';
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:isMessageBySender ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment:isMessageBySender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: _color,
                borderRadius: _borderRadius(image_text_message),
              ),
              padding: imageMessageConfig?.padding ?? EdgeInsets.zero,

              child: Column
              (
                crossAxisAlignment: isMessageBySender ? CrossAxisAlignment.start : CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _showFullScreenImage(context, imageUrl),
                    child: Transform.scale(
                      scale: highlightImage ? highlightScale : 1.0,
                      alignment: isMessageBySender
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        padding: imageMessageConfig?.padding ?? EdgeInsets.zero,
                        margin: imageMessageConfig?.margin ??
                            EdgeInsets.only(
                              top: 6,
                              right: isMessageBySender ? 6 : 0,
                              left: isMessageBySender ? 0 : 6,
                              bottom:1,
                                  /* message.reaction.reactions.isNotEmpty ? 8 : 0, */
                            ),
                        height: imageMessageConfig?.height ?? 200,
                        width: imageMessageConfig?.width ?? 200,
                        child: ClipRRect(
                          borderRadius: imageMessageConfig?.borderRadius ??
                              BorderRadius.circular(14),
                          child: (() {
                            if (imageUrl.isUrl) {
                              return Image.network(
                                imageUrl,
                                fit: BoxFit.fitHeight,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes !=
                                              null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                              );
                            } else if (imageUrl.fromMemory) {
                              return Image.memory(
                                base64Decode(imageUrl
                                    .substring(imageUrl.indexOf('base64') + 7)),
                                fit: BoxFit.fill,
                              );
                            } else {
                              return Image.file(
                                File(imageUrl),
                                fit: BoxFit.fill,
                              );
                            }
                          })(),
                        ),
                      ),
                    ),
                  ),
                  if (image_text_message != null && image_text_message.isNotEmpty)
                    Container(
                      constraints: BoxConstraints
                      (
                        maxWidth: chatBubbleMaxWidth ?? MediaQuery.of(context).size.width * 0.65
                      ),
                      padding: _padding ?? const EdgeInsets.symmetric(horizontal: 12,vertical: 2),
                      margin: _margin ?? EdgeInsets.fromLTRB(5, 0, 6, /* message.reaction.reactions.isNotEmpty ? 8 : */ 1),
                      child: _buildMessageContent(context,image_text_message, textTheme),
                    ),
                ],
              ),
          ),
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                if (isMessageBySender) ...[
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
                ],
                SizedBox(width: 5),
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
      ),
    ],
  );
}
 Widget _buildMessageContent(context,String textMessage, TextTheme textTheme) 
  {
    final String translated_title = message.translate_title??'';
    final String translated_content = message.translate_content??'';
    
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

          if (buttonValues.isNotEmpty) 
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
    /* else if (message.bubble_message_options != null &&
      message.bubble_message_options!.contains('|') && (message.bubble_header_text!='' || message.bubble_header_text!=null) &&(message.bubble_footer_text!=''|| message.bubble_footer_text!=null)) {
        List<String> bubbleOptions = message.bubble_message_options!.split('|');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.bubble_header_text??'',
              style:textTheme.bodyMedium?.copyWith(
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
              message.bubble_footer_text??'',
              style: textTheme.bodyLarge?.copyWith(
                fontSize:13,
                color: Color.fromARGB(255, 52, 58, 64)
              ),
            ),
            const SizedBox(height: 8),
            Column(
            children: bubbleOptions.map((option) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ElevatedButton(
                  onPressed: () {
                    // Handle button click action here
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: Size(double.infinity, 48),
                  ),
                  child: Text(
                    option.trim(),
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          ],
        );
      }  */
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
  }
  EdgeInsetsGeometry? get _margin => isMessageBySender
      ? outgoingChatBubbleConfig?.margin
      : inComingChatBubbleConfig?.margin;
  TextStyle? get _textStyle => isMessageBySender
      ? outgoingChatBubbleConfig?.textStyle
      : inComingChatBubbleConfig?.textStyle;
  EdgeInsetsGeometry? get _padding => isMessageBySender
      ? outgoingChatBubbleConfig?.padding
      : inComingChatBubbleConfig?.padding;
  BorderRadiusGeometry _borderRadius(String message) => isMessageBySender
      ? (message.length < 30
              ? BorderRadius.circular(17)
              : BorderRadius.circular(replyBorderRadius2))
      : (message.length < 29
              ? BorderRadius.circular(17)
              : BorderRadius.circular(replyBorderRadius2));
 Color get _color {
      if (message.profilename == 'Summary') {
        return Color.fromRGBO(255, 193, 7, 1.0);
      }
      return isMessageBySender
          ? Color(0xFF90CAF9)
          : Colors.white;
    }

}
class FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageView({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          scaleEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: _buildImageProvider(),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  ImageProvider _buildImageProvider() {
    if (imageUrl.isUrl) {
      return NetworkImage(imageUrl);
    } else if (imageUrl.fromMemory) {
      return MemoryImage(base64Decode(imageUrl.substring(imageUrl.indexOf('base64') + 7)));
    } else {
      return FileImage(File(imageUrl));
    }
  }
}