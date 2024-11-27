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
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../values/typedefs.dart';
import '../utils/constants/constants.dart';
import '../models/message.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
   void _show_dialog_fetch_response(BuildContext context,String message) {
      final TextEditingController _messageController = TextEditingController(text: "Loading...");
      bool _isEditing = false;
      call_ai_assist(context,message).then((response) {
        _messageController.text = response; 
      }).catchError((error) {
        _messageController.text = "Failed to fetch response.";
      });
        
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Container(
                  width: double.infinity,
                  height: 480.0,
                  decoration: BoxDecoration(
                    color: Color(0xFFF4F4F4),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 2,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      /// Top
                      Column(
                        children: [
                          Container(
                            height: 50,
                            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    onPressed: () {},
                                    icon: const FaIcon(
                                      FontAwesomeIcons.magicWandSparkles, 
                                      color: Colors.black,
                                    ),
                                  ),
                                  const Expanded(
                                    child: Center(
                                      child: Text(
                                        'MaxIA',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontFamily: 'Work Sans',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _isEditing = !_isEditing;
                                      });
                                    },
                                    /* icon: Icon(
                                      Icons.edit,
                                      color: _isEditing ? Colors.blue : Colors.grey,
                                    ), */
                                    icon:FaIcon(
                                      FontAwesomeIcons.edit, 
                                      color: _isEditing ? Colors.blue : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(
                            thickness: 1,
                            color: Color(0xFFA8A8A8),
                          ),
                        ],
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _messageController,
                                  maxLines: null,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                  enabled: _isEditing,
                                  style: TextStyle(
                                    color: Colors.black, 
                                  ),
                                ),
                              ],
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
                );
              },
            ),
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
                _show_dialog_fetch_response(context, message.message);
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
