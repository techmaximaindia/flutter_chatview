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
    bool _isDialogOpen = false;

    void _show_dialog_fetch_response(BuildContext context, String translatedMessage, String sourceLanguage) {
      if (_isDialogOpen) return; // Prevent multiple dialogs
      _isDialogOpen = true;
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
                    height: MediaQuery.of(context).size.height * 0.8,
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
                                  TextButton(
                                    onPressed: () {
                                      translatedMessage = '';
                                      sourceLanguage = '';
                                      _isDialogOpen = false;
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
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
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SingleChildScrollView(
                              child: Card(
                                color: Color(0xFF90CAF9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 5,
                                child: Padding(
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
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              message.translate_content = translatedMessage;
                                              message.translate_title = sourceLanguage;
                                              _isDialogOpen = false;
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
        translatedMessage = '';
        sourceLanguage = '';
        _isDialogOpen = false;
      });
    }

    Future<void> translate(BuildContext context) async {
      final prefs = await SharedPreferences.getInstance();
      if (_isDialogOpen) return;
      final String? uuid = prefs.getString('uuid');
      final String? team_alias = prefs.getString('team_alias');

      if (uuid == null) {
        print("UUID is null. Please check the stored value.");
        return;
      }

      final url = base_url + 'api/translate/';
      var headers = {
        'Authorization': "$uuid|$team_alias",
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

          _show_dialog_fetch_response(context, translated_message, source_language);
        } else {
          message.translate_content = '';
          message.translate_title = '';
          print("Translation failed: ${json_response['message']}");
        }
      } else {
        print(response.reasonPhrase);
      }
    }

    return Container(
      height: 50, // Fixed height for compact look
      decoration: BoxDecoration(
        color: Colors.grey[900], // Dark background like in the image
        borderRadius: BorderRadius.circular(25), // Rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            icon: Icons.reply,
            text: 'Reply',
            onTap: onReplyTap,
          ),
          _buildActionButton(
            icon: Icons.copy,
            text: 'Copy',
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.message));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          _buildActionButton(
            icon: Icons.translate,
            text: 'Translate',
            onTap: () => translate(context),
          ),
          _buildActionButton(
            icon: Icons.delete_outline,
            text: 'Delete',
            onTap: onUnsendTap,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: Colors.white,
            ),
            SizedBox(height: 2),
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
