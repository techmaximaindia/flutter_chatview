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
import 'package:chatview/chatview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/* enum  chatmaximamessage{
  incoming,outgoing
} */
class Message {
  /// Provides id
  final String id;

  /// Used for accessing widget's render box.
  final GlobalKey key;

  /// Provides actual message it will be text or image/audio file path.
  final String message;

  /// Provides message created date time.
  final DateTime createdAt;

  /// Provides id of sender of message.
  final String sendBy;

  /// Provides reply message if user triggers any reply on any message.
  final ReplyMessage replyMessage;

  /// Represents reaction on message.
  final Reaction reaction;

  /// Provides message type.
  final MessageType messageType;

  /// Status of the message.
  final ValueNotifier<MessageStatus> _status;

  /// Provides max duration for recorded voice message.
  Duration? voiceMessageDuration;

  final String profilename;
  final String chatmaximatype;
  final String chatmaxima_profile_image;
  final String message_id;

  final String image_text_message;
  String? translate_title;
  String? translate_content;
  String? bubble_message_options;
  String? bubble_header_text;
  String? bubble_footer_text;
  final Map<String, dynamic>? cb_message_options_full;
  String? pagetype;

  Message({
    this.id = '',
    required this.message,
    required this.createdAt,
    required this.sendBy,
    this.profilename='',
    this.chatmaximatype='',
    this.chatmaxima_profile_image='',
    this.replyMessage = const ReplyMessage(),
    Reaction? reaction,
    this.messageType = MessageType.text,
    this.voiceMessageDuration,
    this.image_text_message='',
    this.message_id='',
    this.translate_title,
    this.translate_content,
    this.bubble_message_options,
    this.bubble_header_text,
    this.bubble_footer_text,
    this.cb_message_options_full,
    this.pagetype,
    MessageStatus status = MessageStatus.pending,
  })  : reaction = reaction ?? Reaction(reactions: [], reactedUserIds: []),
        key = GlobalKey(),
        _status = ValueNotifier(status),
        assert(
          (messageType.isVoice
              ? ((defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.android))
              : true),
          "Voice messages are only supported with android and ios platform",
        );

  /// curret messageStatus
  MessageStatus get status => _status.value;

  /// For [MessageStatus] ValueNotfier which is used to for rebuilds
  /// when state changes.
  /// Using ValueNotfier to avoid usage of setState((){}) in order
  /// rerender messages with new receipts.
  ValueNotifier<MessageStatus> get statusNotifier => _status;

  /// This setter can be used to update message receipts, after which the configured
  /// builders will be updated.
  set setStatus(MessageStatus messageStatus) {
    _status.value = messageStatus;
  }

  factory Message.fromJson(Map<String, dynamic> json) => Message(
      id: json["id"],
      message: json["message"],
      createdAt: json["createdAt"],
      sendBy: json["sendBy"],
      replyMessage: ReplyMessage.fromJson(json["reply_message"]),
      reaction: Reaction.fromJson(json["reaction"]),
      messageType: json["message_type"],
      voiceMessageDuration: json["voice_message_duration"],
      image_text_message: json["image_text_message"],
      message_id: json["message_id"],
      translate_title: json["translate_title"],
      translate_content: json["translate_content"],
      bubble_message_options: json["bubble_message_options"],
      bubble_header_text: json["bubble_header_text"],
      bubble_footer_text: json["bubble_footer_text"],
      cb_message_options_full: json["cb_message_options_full"],
      pagetype: json["pagetype"],
      status: json['status'],
    );

  Map<String, dynamic> toJson() => {
        'id': id,
        'message': message,
        'createdAt': createdAt,
        'sendBy': sendBy,
        'reply_message': replyMessage.toJson(),
        'reaction': reaction.toJson(),
        'message_type': messageType,
        'voice_message_duration': voiceMessageDuration,
        'image_text_message':image_text_message,
        'message_id':message_id,
        'translate_title':translate_title,
        'translate_content':translate_content,
        'bubble_message_options':bubble_message_options,
        'bubble_header_text':bubble_header_text,
        'bubble_footer_text':bubble_footer_text,
        'cb_message_options_full':cb_message_options_full,
        'pagetype':pagetype,
        'status': status.name
      };
}
