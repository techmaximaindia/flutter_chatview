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
import '../values/typedefs.dart';
import '../utils/constants/constants.dart';
import '../models/message.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
    final textStyle = buttonTextStyle ?? const TextStyle(fontSize: 14, color: Colors.black);
    final deviceWidth = MediaQuery.of(context).size.width;

    Future<void> translate(BuildContext context) async 
    {
      final prefs = await SharedPreferences.getInstance();
      final String? uuid = prefs.getString('uuid');

      if (uuid == null) {
        print("UUID is null. Please check the stored value.");
        return;
      }

      final url = base_url + 'api/translate/';
      var headers = {
        'Authorization': uuid,
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
        /* final responseBody = await response.stream.bytesToString();
         final jsonResponse = json.decode(responseBody); */
        var responseBody = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseBody);
        print(responseBody);
        if (jsonResponse['success'] == "true") {
          final source_language = jsonResponse['source_language'];
          final translated_message = jsonResponse['translated_message_text'];

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Translation from $source_language',
                          style:TextStyle(color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
              content: Text(translated_message),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          print("Translation failed: ${jsonResponse['message']}");
        }
      } else {
        print(response.reasonPhrase);
      }
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
            InkWell(
              onTap: () =>{translate(context),
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
                    'Translate',
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