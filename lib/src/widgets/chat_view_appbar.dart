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
import 'dart:io' if (kIsWeb) 'dart:html';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';

import '../values/typedefs.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;
import 'profile_page.dart';

class ChatViewAppBar extends StatelessWidget {
  const ChatViewAppBar({
    Key? key,
    required this.chatTitle,
    this.backGroundColor,
    this.userStatus,
    this.profilePicture,
    this.chatTitleTextStyle,
    this.userStatusTextStyle,
    this.backArrowColor,
    this.actions,
    this.elevation,
    this.onBackPress,
    this.padding,
    this.leading,
    this.showLeading = true,
    this.platform,
    this.mobile_number,
    this.email_id,
    this.lead_id,
  }) : super(key: key);

  /// Allow user to change colour of appbar.
  final Color? backGroundColor;

  /// Allow user to change title of appbar.
  final String chatTitle;

  /// Allow user to change whether user is available or offline.
  final String? userStatus;

  /// Allow user to change profile picture in appbar.
  final String? profilePicture;

  /// Allow user to change text style of chat title.
  final TextStyle? chatTitleTextStyle;

  /// Allow user to change text style of user status.
  final TextStyle? userStatusTextStyle;

  /// Allow user to change back arrow colour.
  final Color? backArrowColor;

  /// Allow user to add actions widget in right side of appbar.
  final List<Widget>? actions;

  /// Allow user to change elevation of appbar.
  final double? elevation;

  /// Provides callback when user tap on back arrow.
  final VoidCallBack? onBackPress;

  /// Allow user to change padding in appbar.
  final EdgeInsets? padding;

  /// Allow user to change leading icon of appbar.
  final Widget? leading;

  /// Allow user to turn on/off leading icon.
  final bool showLeading;

  final String? platform;

  final String? mobile_number;

  final String? email_id;

  final String? lead_id;

  @override
  Widget build(BuildContext context) {
    Future<bool> image_url_valid(String url) async {              
      try {
        final response = await http.get(Uri.parse(url));
        if(response.statusCode==200){
          return true;
        } 
        else if(response.statusCode==404){
          return false;
        }
        else {
          return false;
        }
      } 
      catch (e) {
        return false;
      }
    }
    String truncate_lead_name(String lead_name) 
    {
      if (lead_name != null && lead_name.isNotEmpty) 
      {
        if (lead_name.length > 20) 
        {
          return lead_name.substring(0, 20)+ "...";
        } 
        else 
        {
          return lead_name;
        }
      }
      else{
        return 'Anonymous';
      } 
    }
    return Material(
      elevation: elevation ?? 1,
      child: InkWell( // Add InkWell for tap effect
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          String? current_page = prefs.getString('page') ?? '';
          if (current_page == 'chat') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => profilepage(chatTitle: chatTitle,profilePicture: profilePicture,platform: platform,mobile: mobile_number,profile_email: email_id,lead_id: lead_id),
              ),
            );
          }
          else if(current_page=='ticket'){
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => profilepage(chatTitle: chatTitle,profilePicture: profilePicture,platform: '',mobile: '',profile_email:email_id,lead_id: '',page: current_page,),
              ),
            );
          }
        },
      child: Container(
        padding: padding ??
            EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              bottom: 4,
            ),
        color: backGroundColor ?? Colors.white,
        child: Row(
          children: [
            if (showLeading)
              leading ??
                  IconButton(
                    onPressed: onBackPress ?? () async{ 
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('page'); 
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      (!kIsWeb && Platform.isIOS)
                          ? Icons.arrow_back_ios
                          : Icons.arrow_back,
                      color: backArrowColor,
                    ),
                  ),
            Expanded(
              child: Row(
                children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Stack(
                        children: [
                          if (profilePicture != null&& profilePicture!='')
                            if(platform=='facebook')
                              FutureBuilder<bool>(
                                future: image_url_valid(profilePicture!),
                                builder: (context, snapshot) {
                                  final isValidImage = snapshot.data ?? false;
                                  if (isValidImage) {
                                    return CircleAvatar(

                                      /* backgroundColor: Color.fromRGBO(108, 117, 125,2), */
                                      backgroundColor:Color(0xFF6C757D),
                                      backgroundImage: NetworkImage(profilePicture!),
                                    );
                                  } else {
                                    return CircleAvatar(
                                      /* backgroundColor: Color.fromRGBO(108, 117, 125,2), */
                                      backgroundColor:Color(0xFF6C757D),
                                      child: Text(
                                        chatTitle[0].toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          /* fontWeight: FontWeight.bold, */
                                        ),
                                      ),
                                    );
                                  }
                                },
                              )
                            else  
                              CircleAvatar(
                                /* backgroundColor: Color.fromRGBO(108, 117, 125,2), */
                                backgroundColor:Color(0xFF6C757D),
                                backgroundImage: NetworkImage(profilePicture!),
                              )
                          else if(chatTitle!=null&& chatTitle!='')
                            CircleAvatar(
                             /*  backgroundColor: Color.fromRGBO(108, 117, 125,2), */
                             backgroundColor:Color(0xFF6C757D),
                              child: Text(
                                chatTitle[0].toUpperCase(),
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          else
                            CircleAvatar(
                              /* backgroundColor: Color.fromRGBO(108, 117, 125,2), */
                              backgroundColor:Color(0xFF6C757D),
                              child: Text('Anonymous'[0].toUpperCase(),style: TextStyle(color: Colors.white),),
                            ),
                          if(platform!=null && platform!='')
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: ClipOval(
                              child: CircleAvatar(
                                backgroundColor: Colors.white,
                                radius: 9,
                                child: get_platform_widget(platform),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        truncate_lead_name(chatTitle),
                        style: chatTitleTextStyle ??
                            const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.25,
                            ),
                      ),
                      if (userStatus != null)
                        Text(
                          userStatus!,
                          style: userStatusTextStyle,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (actions != null) ...actions!,
          ],
        ),
      ),
      ),
    );
  }
  get_platform_widget(platform) 
  {
    if (platform == 'livechatwidget') 
    {
      return Icon
      (
        FontAwesomeIcons.message,
        size: 13,
        color: Colors.blueAccent,
      );
    } 
    else if (platform == 'fb_whatsapp') 
    {
      return Icon
      (
        FontAwesomeIcons.whatsapp,
        size: 13,
        color: Colors.green,
      );
    } 
    else if (platform == "telegram") 
    {
      return Icon
      (
        FontAwesomeIcons.telegram, 
        size: 13, 
        color: Colors.blue
      );
    } 
    else if (platform == "facebook") 
    {
      return Icon
      (
        FontAwesomeIcons.facebook, 
        size: 13, 
        color: Colors.blue
      );
    } 
    else if (platform == "twitter") 
    {
      return Icon
      (
        FontAwesomeIcons.twitter, 
        size: 13, 
        color: Colors.blue
      );
    } 
    else if (platform == "wa_whatsapp") 
    {
      return Icon
      (
        FontAwesomeIcons.whatsapp,
        size: 13,
        color: Colors.green,
      );
    } 
    else if (platform == "sms") 
    {
      return Icon
      (
        FontAwesomeIcons.sms, 
        size: 13, 
        color: Colors.blue
      );
    } 
    else if (platform == "email") 
    {
      return Icon
      (
        FontAwesomeIcons.envelope, 
        size: 13, 
        color: Colors.blue
      );
    } 
    else if (platform == "instagram") 
    {
      return Icon
      (
        FontAwesomeIcons.instagram,
        size: 13, 
        color: Color.fromARGB(255, 220, 142, 142)
      );
    } 
    else 
    {
      return SizedBox.shrink();
    }
  }
}
