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

import 'package:chatview/src/utils/package_strings.dart';
import 'package:flutter/services.dart';

import '../values/typedefs.dart';

import '../models/message.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants/constants.dart';

class ReplyPopupWidget extends StatelessWidget {
  const ReplyPopupWidget({
    Key? key,
    required this.sendByCurrentUser,
    required this.onUnsendTap,
    required this.onReplyTap,
    required this.onReportTap,
    required this.onMoreTap,
    this.buttonTextStyle,
    this.topBorderColor,
    required this.message,
  }) : super(key: key);

  /// Represents message is sent by current user or not.
  final bool sendByCurrentUser;

  /// Provides call back when user tap on unsend button.
  final VoidCallBack onUnsendTap;

  /// Provides call back when user tap on reply button.
  final VoidCallBack onReplyTap;

  /// Provides call back when user tap on report button.
  final VoidCallBack onReportTap;

  /// Provides call back when user tap on more button.
  final VoidCallBack onMoreTap;

  /// Allow user to set text style of button are showed in reply snack bar.
  final TextStyle? buttonTextStyle;

  /// Allow user to set color of top border of reply snack bar.
  final Color? topBorderColor;

  final Message message;


  @override
  Widget build(BuildContext context) {
    final textStyle =
        buttonTextStyle ?? const TextStyle(fontSize: 14, color: Colors.black);
    final deviceWidth = MediaQuery.of(context).size.width;
    Future<String> call_ai_assist(BuildContext context, String message) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? uuid = prefs.getString('uuid');
        final url = base_url + 'api/ai_assist/';

        var headers = {
          'Content-Type': 'application/json',
          'Authorization': '$uuid',
        };

        var request = http.Request('POST', Uri.parse(url));
        request.body = json.encode({
          "source": "mobileapp",
          "type": "reply",
          "conversation_attributes": {
            "query": message,
          },
        });
        request.headers.addAll(headers);

        http.StreamedResponse response = await request.send();
        if (response.statusCode == 200) {
          String responseBody = await response.stream.bytesToString();
          Map<String, dynamic> decodedResponse = json.decode(responseBody);
          return json.decode(decodedResponse['ai_response'])['answer'];
        } else {
          return "Error: Unable to fetch AI response.";
        }
      } catch (e) {
        return "Error: $e";
      }
    }
    Future<void> sendMessage(String message,) async {
      final prefs = await SharedPreferences.getInstance();

      final String? cb_lead_id = prefs.getString('cb_lead_id');
      final String? platform = prefs.getString('platform');
      final String? conversation_id = prefs.getString('conversation_id');

      Map<String, dynamic> data = {
        "cb_lead_id": cb_lead_id,
        "platform": platform,
        "message_body": message,
        "conversation_id":conversation_id,
        "cb_message_source": 'android',
        "reply_message_id": '', 
      };

      String jsonData = json.encode(data);

      final String? uuid = prefs.getString('uuid');

      String url = base_url + 'api/send_message/';
      var response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "$uuid",
        },
        body: jsonData,
      );
      if (response.statusCode == 200) {
        print("Message sent successfully: ${response.body}");
      } else {
        print("Failed to send message: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    }
   void _show_dialog_fetch_response(BuildContext context, String title, String message) {
      final TextEditingController _messageController = TextEditingController(text: "Loading...");
     
      call_ai_assist(context,message).then((response) {
        _messageController.text = response; 
      }).catchError((error) {
        _messageController.text = "Failed to fetch response.";
      });
       
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            contentPadding: const EdgeInsets.only(left: 26, right: 26, top: 10, bottom: 15),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10.0)),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.of(context).pop(); 
                  },
                ),
              ],
            ),
            content: SizedBox(
              height: 350.0,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _messageController,
                      maxLines: null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: () async {
                    sendMessage(_messageController.text);
                    Navigator.of(context).pop(); 
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(200, 0, 138, 255),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 58),
                  ),
                  child: const Text(
                    'Send',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return Container(
      height: deviceWidth > 600 ? deviceWidth * 0.05 : deviceWidth * 0.16,
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: topBorderColor ?? Colors.grey.shade400, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          InkWell(
              onTap: () async{
                _show_dialog_fetch_response(context, "AI Response", message.message);
               },
              child: Row(
                children: [
                  Icon(
                    Icons.smart_toy, 
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'AI Assist',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ), 
          InkWell(
            onTap: onReplyTap,
            child: Row(
                children: [
                  Icon(
                    Icons.reply, 
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Reply',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
          ),
            InkWell(
              onTap: () async{Clipboard.setData(ClipboardData(text: message.message));
               },
              child:  Row(
                children: [
                  Icon(
                    Icons.copy, 
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Copy',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
