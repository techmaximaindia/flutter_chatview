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
import 'package:chatview/src/utils/constants/constants.dart';
import 'package:chatview/src/models/models.dart';
import 'package:chatview/src/models/chat_user.dart';
import 'chat_view_appbar.dart';
import 'package:http/http.dart' as http;
import 'chat_view_appbar.dart';

class ProfileCircle extends StatelessWidget {
  const ProfileCircle({
    Key? key,
    required this.bottomPadding,
    this.user_names,
    this.imageUrl,
    this.profileCirclePadding,
    this.circleRadius,
    this.onTap,
    this.onLongPress,
    this.platform,
  }) : super(key: key);

  /// Allow users to give  default bottom padding according to user case.
  final double bottomPadding;

  /// Allow user to pass image url of user's profile picture.
  final String? imageUrl;

  /// Allow user to set whole padding of profile circle view.
  final EdgeInsetsGeometry? profileCirclePadding;

  /// Allow user to set radius of circle avatar.
  final double? circleRadius;

  /// Allow user to do operation when user tap on profile circle.
  final VoidCallback? onTap;

  /// Allow user to do operation when user long press on profile circle.
  final VoidCallback? onLongPress;
  final String? user_names;
  final String? platform;

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: profileCirclePadding ??
          EdgeInsets.only(left: 6.0, right: 4, bottom: bottomPadding),
      child: InkWell(
        onLongPress: onLongPress,
        onTap: onTap,
        child:imageUrl != null && imageUrl !=''
            ? CircleAvatar(
                backgroundColor: Color.fromRGBO(108, 117, 125,2),
                radius: circleRadius ?? 16,
                backgroundImage: NetworkImage(imageUrl!),
              )
            : CircleAvatar(
                backgroundColor: Color.fromRGBO(108, 117, 125,2),
                radius: circleRadius ?? 16,
                child: Text(
                  user_names != null && user_names!.isNotEmpty 
                      ? user_names![0].toUpperCase()
                      : '', 
                  style: TextStyle(color: Colors.white),
                ),
              ),
      ),
    );
  }
}
