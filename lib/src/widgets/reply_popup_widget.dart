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

   void _show_dialog_fetch_response(BuildContext context, String translatedMessage, String sourceLanguage){
  
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.0),
                  topRight: Radius.circular(20.0),
              ),
              child: Container(
                height:MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
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
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                 
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  translatedMessage='';
                                  sourceLanguage='';
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row
                            (
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: 
                              [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      WidgetSpan(
                                        child: FaIcon(
                                          FontAwesomeIcons.language,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        alignment: PlaceholderAlignment.middle,
                                      ),
                                      WidgetSpan(
                                        child: SizedBox(width: 5),
                                      ),
                                      TextSpan(
                                        text: "Translate",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    /* Divider(color: Colors.white54, thickness: 1), */
                    Expanded
                    (
                      child: Padding
                      (
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView
                        (
                          child: Card
                          (
                            color: Color(0xFF90CAF9), 
                            shape: RoundedRectangleBorder
                            (
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 5,
                            child: Padding
                            (
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Translation From $sourceLanguage",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      translatedMessage,
                                      style: TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                            ),
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
                                      child:ElevatedButton
                                        (
                                          onPressed: 
                                          () async {
                                            
                                            message.translate_content=translatedMessage;
                                            message.translate_title=sourceLanguage;
                                            Navigator.of(context).pop();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            elevation: 0,
                                            shadowColor: Colors.transparent,
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
              ),
            ),
            );
          },
        );
      },
    ).whenComplete(() {
      translatedMessage='';
      sourceLanguage='';
    });
  }
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
        var response_body = await response.stream.bytesToString();
        var json_response = json.decode(response_body);
        if (json_response['success'] == "true") {

          final source_language = json_response['source_language'];
          final translated_message = json_response['translated_message_text'];

         message.translate_title = source_language;
          message.translate_content = translated_message;
          /* showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Translation from $source_language',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    translated_message,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    message.translate_title=source_language;
                    message.translate_content=translated_message;
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          ); */
          _show_dialog_fetch_response(context, translated_message, source_language);
        } else {
          message.translate_content='';
          message.translate_title='';
          print("Translation failed: ${json_response['message']}");
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
              onTap: () =>{
                translate(context),
               },
              child:  Row(
                children: [
                  Icon(
                    Icons.translate, 
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