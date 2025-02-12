import 'dart:convert';
import 'dart:io' if (kIsWeb) 'dart:html';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';

import '../utils/constants/constants.dart';
import '../values/typedefs.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;
/* import 'package:flutter_svg/flutter_svg.dart'; */


class profilepage extends StatefulWidget{

  
  final String chatTitle;
  final String? profilePicture;
  final String? platform;
  final String? profile_email;
  final String? mobile;
  final String?lead_id;
  
  const profilepage({
    Key? key,
    required this.chatTitle,
    this.profilePicture,
    this.platform,
    this.mobile,
    this.profile_email,
    this.lead_id
  }) : super(key: key);
   @override
  State<profilepage> createState() => _profilestate();
}

class _profilestate extends State<profilepage> 
{
  List<dynamic> conversations = [];
  int page_no=1;
  ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  @override
  void initState() 
  {
    super.initState();
    fetchConversations(widget.lead_id??'');
     _scrollController.addListener(() 
     {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) 
      {
        if (!_isLoading) 
        {
          _isLoading = true;
          fetchConversations(widget.lead_id??'');
        }
      }
    });
  }

  Future<bool> fetchConversations(String cb_lead_id) async 
  {
    final prefs = await SharedPreferences.getInstance();
    final String? email = prefs.getString('email');
    final String? password = prefs.getString('password');
    final String? uuid = prefs.getString('uuid');
    String url = base_url + 'api/chatbot_dashboard/';
    var response = await http.post
    (
      Uri.parse(url),
      headers: 
      {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "$uuid",
      },
      body: jsonEncode({'cb_lead_id':cb_lead_id,'page_no': page_no, 'per_page': 20}),
    );
    if (response.statusCode == 200) 
    {
      var jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      var conversation_map = jsonResponse['conversations'];
      if (conversation_map != null  && conversation_map is Map) 
      {
        var my_list = <dynamic>[];
        conversation_map.values.forEach((v) => my_list.add(v[0]));
        _isLoading=false;
        setState(() 
        {
          conversations.addAll(my_list);
          page_no++;
        });
      }
      return true;
    } 
    else 
    {
      print('Request failed with status: ${response.statusCode}.');
      return false;
    }
  }
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
        if (lead_name.length > 10) 
        {
          return lead_name.substring(0, 10)+ "...";
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
    return Scaffold(
      appBar: AppBar
      (
        title: Text('Profile',style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontFamily: 'Work Sans',
                fontWeight: FontWeight.w600,
              ),),
        backgroundColor:Colors.blue,
        elevation: 0, 
        leading: IconButton
        (
          icon: Icon(
              (!kIsWeb && Platform.isIOS)
                  ? Icons.arrow_back_ios
                  : Icons.arrow_back,
              color: Colors.white,
            ),
          onPressed: () 
          {
            Navigator.pop(context,);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
                height: 249,
                child: Stack(
                  children: [
                    Container(
                      color: Color(0xffC4C4C4),
                      height: 186,
                    ),
                    Positioned(
                      right: 121,
                      left: 121,
                      bottom: 0,
                      child: Container(
                        width: 150,
                        height: 150,
                        child: (widget.profilePicture != null && widget.profilePicture!.isNotEmpty)
                            ? (widget.platform == 'facebook'
                                ? FutureBuilder<bool>(
                                    future: image_url_valid(widget.profilePicture!),
                                    builder: (context, snapshot) {
                                      final isValidImage = snapshot.data ?? false;
                                      if (isValidImage) {
                                        return CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Color.fromRGBO(108, 117, 125, 2),
                                          backgroundImage: NetworkImage(widget.profilePicture!),
                                        );
                                      } else {
                                        return CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Color.fromRGBO(108, 117, 125, 2),
                                          child: Text(
                                            widget.chatTitle.isNotEmpty
                                                ? widget.chatTitle[0].toUpperCase()
                                                : 'A',
                                            style: TextStyle(color: Colors.white, fontSize: 45),
                                          ),
                                        );
                                      }
                                    },
                                  )
                                : CircleAvatar(
                                  radius: 50,
                                    backgroundColor: Color.fromRGBO(108, 117, 125, 2),
                                    backgroundImage: NetworkImage(widget.profilePicture!),
                                  ))
                            : CircleAvatar(
                              radius: 50,
                                backgroundColor: Color.fromRGBO(108, 117, 125, 2),
                                child: Text(
                                  widget.chatTitle.isNotEmpty
                                      ? widget.chatTitle[0].toUpperCase()
                                      : 'A',
                                  style: TextStyle(color: Colors.white, fontSize: 45),
                                ),
                              ),
                      ),
                    )
                  ],
                ),
              ),
            SizedBox(
              height: 20,
            ),
            Center(
              child: Text(
                 widget.chatTitle ?? '',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.black,
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                softWrap: true,
                /* maxLines:3,
                overflow: TextOverflow.ellipsis, */
              ),
            ),
            SizedBox(
              height: 10,
            ),
            Text(
              widget.profile_email??'',
              style:TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.w600,
                ),
                softWrap: true,
              /* maxLines: 2,
              overflow: TextOverflow.ellipsis, */
            ),
            SizedBox(
              height: 10,
            ),
            Text
            (
              widget.mobile??'',
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
            SizedBox(
              height: 10,
            ),
            get_platform_widget(widget.platform),
            SizedBox(
              height: 25,
            ),
            if(conversations!=[])
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: conversations.isNotEmpty 
                  ? Text(
                      "Conversations",
                      style:TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                    )
                  : SizedBox.shrink()
              ),
            ),
            SizedBox(
              height: 14,
            ),
            Card
            (  
              color: Colors.white,
              elevation: 0,
              child: _body(conversations),
            ),
            if (_isLoading) CircularProgressIndicator(),
          ],
        )
      ),
    );
  }
  Widget _body( List conversations) 
{
  var stream = Stream.fromIterable(conversations);
  return StreamBuilder
  (
    stream: stream,
    builder: (BuildContext context, AsyncSnapshot snapshot) 
    {
      return SingleChildScrollView
      (
        child: Column
        (
          children: conversations.map((conversation) 
          {
            final platform = conversation['platform'];
            final lead_name = conversation['cb_lead_name'];
            final app_name = conversation['app_name'] ?? '';
            final last_status = conversation['cb_last_status_id'] ?? '';
            dynamic laststatus_name=conversation['last_status_name']??'';
            final message_time_string = conversation['cb_message_datetime']??'';
            final status=conversation['cb_message_status']??'';
            final message_type = conversation['cb_message_type'] ?? '';
            Widget? statusWidget = get_status(status,message_type);
            final agent_name=conversation['last_agent_name']??'';
            final departname=conversation['cb_department_name']??'';
            final unread_message_count = int.parse(conversation['unread_message_count'] == null ? '0' : conversation['unread_message_count'],);
            String imageUrl = conversation['cb_lead_image_url']??'';
            final conversation_id=conversation['conversation_id'];
            String mobilenumber=conversation['cb_lead_mobile']??'';
            return ListTile
            (
              shape: RoundedRectangleBorder
              (
                borderRadius: BorderRadius.circular(10),
              ),
              title: Container
              (
                padding: EdgeInsets.all(10),
                child: Column
                (
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: 
                  [
                    Row
                    (
                      crossAxisAlignment:CrossAxisAlignment.start,
                      children:
                      [
                        GestureDetector
                        (
                            child: Container
                            (
                              margin: EdgeInsets.only(left: 3),
                              width: 60,
                              child: Stack
                              (
                                alignment: Alignment.centerLeft,
                                children: 
                                [
                                  (() 
                                  {
                                    if (conversation['cb_lead_image_url'] =='') 
                                    {
                                      if (conversation['cb_lead_name'] =='') 
                                      {
                                        return CircleAvatar
                                        (
                                          backgroundColor:Colors.grey,
                                          child: Text('A',style: TextStyle(color: Colors.white),),
                                        );
                                      } 
                                      else 
                                      {
                                        String lead_name =conversation['cb_lead_name'];
                                        return CircleAvatar
                                        (
                                          backgroundColor:Colors.grey,
                                          child: Text
                                          (
                                            lead_name[0].toUpperCase(),
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        );
                                      }
                                    } 
                                    else 
                                    {
                                      String imageUrl =conversation['cb_lead_image_url']??'';
                                      /* if (imageUrl.endsWith('.svg')) 
                                      {
                                        return CircleAvatar
                                        (
                                          backgroundColor:Colors.grey,
                                          child:SvgPicture.network
                                          (
                                            imageUrl,
                                            width: 50.0,
                                            height: 50.0,
                                            fit: BoxFit.fill
                                          ),
                                        );
                                      } 
                                      else 
                                      { */
                                        return CircleAvatar
                                        (
                                          backgroundColor:Colors.grey,
                                          backgroundImage:NetworkImage
                                          (
                                            imageUrl
                                          ),
                                        );
                                      /* } */
                                    }
                                  }()),
                                  SizedBox(height: 5),
                                  Positioned
                                  (
                                    bottom: 0,
                                    right: 15,
                                    child: ClipOval
                                    (
                                      child: CircleAvatar
                                      (
                                        backgroundColor: Colors.white,
                                        radius: 9,
                                        child: get_platform_widget
                                        (
                                          conversation['platform'],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Expanded
                        (
                          child: Column
                          (
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: 
                            [
                              Row
                              (
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: 
                                [
                                  Flexible
                                  (
                                    child: Text
                                    (
                                      (conversation['cb_lead_name'].isNotEmpty || conversation['to_mobile'].isNotEmpty)
                                        ? (conversation['cb_lead_name'].isNotEmpty ? conversation['cb_lead_name'] : conversation['to_mobile'])
                                        : 'Unknown User',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      softWrap: true,
                                    ),
                                  ),
                                  if (unread_message_count > 0)
                                  Container
                                  (
                                    padding: EdgeInsets.all(4),
                                    child: CircleAvatar
                                    (
                                      backgroundColor: Color.fromARGB(255, 12, 135, 242),
                                      radius: 10, 
                                      child: Text
                                      (
                                        "$unread_message_count",
                                        style: TextStyle
                                        (
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row
                              (
                                children: 
                                [
                                  if (statusWidget != null) statusWidget,
                                  if (statusWidget != null) SizedBox(width: 2),
                                  Text.rich
                                  (
                                    TextSpan
                                    (
                                      text: (() 
                                      {
                                        final cleanedText =conversation['cb_message_text'];
                                        return cleanedText !=null &&cleanedText.length >10
                                          ? '${cleanedText.substring(0, 5)}...'
                                          : cleanedText ?? '';
                                      })(),
                                      style: TextStyle
                                      (
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                      children: <InlineSpan>
                                      [
                                        if (conversation['cb_media_type'] =="image")
                                        WidgetSpan
                                        (
                                          child: Row
                                          (
                                            children: 
                                            [
                                              Icon
                                              (
                                                Icons.image,
                                                color:Colors.grey,
                                                size: 12,
                                              ),
                                              SizedBox(width: 2),
                                              Text
                                              (
                                                'Photo',
                                                style: TextStyle
                                                (
                                                  color:Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        else if (conversation['cb_media_type'] =="video")
                                        WidgetSpan
                                        (
                                          child: Row
                                          (
                                            children: 
                                            [
                                              Icon
                                              (
                                                Icons.videocam,
                                                color:Colors.grey,
                                                size: 12,
                                              ),
                                              SizedBox(width: 2),
                                              Text
                                              (
                                                'Video ',
                                                style: TextStyle
                                                (
                                                  color:Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        else if (conversation['cb_media_type'] =="file")
                                        const WidgetSpan
                                        (
                                          child: Row
                                          (
                                            children: 
                                            [
                                              Icon
                                              (
                                                Icons.insert_drive_file,
                                                color:Colors.grey,
                                                size: 12,
                                              ),
                                              SizedBox(width: 2),
                                              Text
                                              (
                                                'File ',
                                                style: TextStyle
                                                (
                                                  color:Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        else if (conversation['cb_media_type'] =="audio")
                                        WidgetSpan
                                        (
                                          child: Row
                                          (
                                            children: 
                                            [
                                              Icon
                                              (
                                                Icons.mic,
                                                color:Colors.grey,
                                                size: 12,
                                              ),
                                              SizedBox(width: 2),
                                              Text
                                              (
                                                'Audio ',
                                                style: TextStyle
                                                (
                                                  color:Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                              /* SizedBox(height: 5), */
                              /* Wrap
                              (
                                crossAxisAlignment: WrapCrossAlignment.start,
                                children: 
                                [
                                  build_text("$app_name"),
                                  if (agent_name != null && agent_name.isNotEmpty)
                                    build_text(" | $agent_name"),
                                  if (departname != null && departname.isNotEmpty)
                                    build_text(" | $departname"),
                                ],
                              ), */
                            ],
                          ),
                        ),
                        SizedBox(width: 5),
                        Column
                        (
                          crossAxisAlignment:CrossAxisAlignment.end,
                          children: 
                          [
                            Text
                            (
                              message_time_string,
                              style: TextStyle
                              (
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 5),
                            SizedBox(height: 5),
                            _buildStatusBadge(laststatus_name),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
    },
  );
}
Widget _buildStatusBadge(String? status_name) {
  Color badgeColor;
  String statusText;


  if (status_name == null || status_name.isEmpty || status_name == 'New') 
  {
    badgeColor = Color(0xFF17A2B8);
    statusText = 'New';
  } else if (status_name == 'Open') {
    badgeColor = Color(0xFF3B7DDD);
    statusText =status_name;
  } else if (status_name == 'Pending') {
    badgeColor = Color(0xFFFCB92C);
    statusText = status_name;
  } else if (status_name == 'Resolved') {
    badgeColor = Color(0xFF1CBB8C);
    statusText = status_name;
  } else if (status_name == 'Reopen' ||status_name == 'Unassigned' ||status_name == 'Incomplete' ||status_name == 'Spam' ||status_name == 'InProgress' ||status_name == 'Cancelled') {
    badgeColor = Color(0xFFDC3545);
    statusText = status_name;
  } else if (status_name == 'Promotions') {
    badgeColor = Color(0xFFFCB92C);
    statusText = status_name;
  } else if (status_name == 'Social' || status_name == 'Primary' || status_name == 'Updates') {
    badgeColor = Color(0xFF17A2B8);
    statusText = status_name;
  } else {
    badgeColor=Colors.green;
    statusText=status_name;
  }

  return DecoratedBox(
    decoration: BoxDecoration(
      color: badgeColor,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        statusText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    ),
  );
}
Widget account_icon(String accountPlatform) 
{
  if (accountPlatform == 'fb_whatsapp') 
  {
    return FaIcon(FontAwesomeIcons.whatsapp,color: Colors.green,);
  } 
  else if (accountPlatform == 'facebook') 
  {
    return FaIcon(FontAwesomeIcons.facebook,color: Colors.blue,);
  } 
  else if (accountPlatform == 'wa_whatsapp') 
  {
    return FaIcon(FontAwesomeIcons.whatsapp,color: Colors.green,);
  } 
  else if (accountPlatform == 'telegram') 
  {
    return FaIcon(FontAwesomeIcons.telegram,color: Colors.blue,);
  }
  else if (accountPlatform == 'livechatwidget') 
  {
    return FaIcon(FontAwesomeIcons.message,color: Colors.blue,);
  }
  else if (accountPlatform == 'sms') 
  {
    return FaIcon(FontAwesomeIcons.sms,color: Colors.blue,);
  }
  else if (accountPlatform == 'twitter') 
  {
    return FaIcon(FontAwesomeIcons.twitter,color: Colors.blue,);
  }    
  else if (accountPlatform == 'instagram') 
  {
    return FaIcon(FontAwesomeIcons.instagram,color: Color.fromARGB(255, 220, 142, 142),);
  } 
  else 
  {
    return SizedBox.shrink();
  }
}
Widget? get_status(String status, String type) 
{
  if (type == 'outgoing') 
  {
    switch (status) 
    {
      case 'sent':
        return Icon(Icons.done,color: Colors.grey,size: 12);
      case 'delivered':
        return Icon(Icons.done_all,color: Colors.grey,size: 12);
      case 'read':
        return Icon(Icons.done_all, color: Colors.green, size: 12);
      case 'failed':
        return Icon(Icons.error, color: Colors.red, size: 12);
      default:
        return null;
    }
  } 
  else 
  {
    return null;
  }
}
Widget build_text(String text) 
{
  return Text
  (
    text,
    style: TextStyle
    (
      color: Colors.grey,
      fontSize: 10,
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

/* class profilepage extends StatelessWidget {
  const profilepage({
    Key? key,
    required this.chatTitle,
    this.profilePicture,
    this.platform,
    this.mobile,
    this.profile_email,
  }) : super(key: key);

  final String chatTitle;
  final String? profilePicture;
  final String? platform;
  final String? profile_email;
  final String? mobile;

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
        if (lead_name.length > 10) 
        {
          return lead_name.substring(0, 10)+ "...";
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
    return Scaffold(
      appBar: AppBar
      (
        title: Text('Profile',style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontFamily: 'Work Sans',
                fontWeight: FontWeight.w600,
              ),),
        backgroundColor:Colors.blue,
        elevation: 0, 
        leading: IconButton
        (
          icon: Icon(
              (!kIsWeb && Platform.isIOS)
                  ? Icons.arrow_back_ios
                  : Icons.arrow_back,
              color: Colors.white,
            ),
          onPressed: () 
          {
            Navigator.pop(context,);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
                height: 249,
                child: Stack(
                  children: [
                    Container(
                      color: Color(0xffC4C4C4),
                      height: 186,
                    ),
                    Positioned(
                      right: 121,
                      left: 121,
                      bottom: 0,
                      child: Container(
                        width: 150,
                        height: 150,
                        child: (profilePicture != null && profilePicture!.isNotEmpty)
                            ? (platform == 'facebook'
                                ? FutureBuilder<bool>(
                                    future: image_url_valid(profilePicture!),
                                    builder: (context, snapshot) {
                                      final isValidImage = snapshot.data ?? false;
                                      if (isValidImage) {
                                        return CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Color.fromRGBO(108, 117, 125, 2),
                                          backgroundImage: NetworkImage(profilePicture!),
                                        );
                                      } else {
                                        return CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Color.fromRGBO(108, 117, 125, 2),
                                          child: Text(
                                            chatTitle.isNotEmpty
                                                ? chatTitle[0].toUpperCase()
                                                : 'A',
                                            style: TextStyle(color: Colors.white, fontSize: 45),
                                          ),
                                        );
                                      }
                                    },
                                  )
                                : CircleAvatar(
                                  radius: 50,
                                    backgroundColor: Color.fromRGBO(108, 117, 125, 2),
                                    backgroundImage: NetworkImage(profilePicture!),
                                  ))
                            : CircleAvatar(
                              radius: 50,
                                backgroundColor: Color.fromRGBO(108, 117, 125, 2),
                                child: Text(
                                  chatTitle.isNotEmpty
                                      ? chatTitle[0].toUpperCase()
                                      : 'A',
                                  style: TextStyle(color: Colors.white, fontSize: 45),
                                ),
                              ),
                      ),
                    )
                  ],
                ),
              ),
            SizedBox(
              height: 20,
            ),
            Center(
              child: Text(
                 chatTitle ?? '',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.black,
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                softWrap: true,
                /* maxLines:3,
                overflow: TextOverflow.ellipsis, */
              ),
            ),
            SizedBox(
              height: 10,
            ),
            Text(
              profile_email??'',
              style:TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.w600,
                ),
                softWrap: true,
              /* maxLines: 2,
              overflow: TextOverflow.ellipsis, */
            ),
            SizedBox(
              height: 10,
            ),
            Text
            (
              mobile??'',
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
            SizedBox(
              height: 10,
            ),
            get_platform_widget(platform),
            SizedBox(
              height: 25,
            ),
          ],
        )
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
class MyFormField extends StatelessWidget {
  const MyFormField({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 16,
            height: 1.38,
            fontWeight: FontWeight.w600,
            color: Color(0xffA8A8A8),
          ),
        ),
        TextFormField()
      ],
    );
  }
}
 */