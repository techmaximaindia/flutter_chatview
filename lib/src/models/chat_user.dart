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
class ChatUser {
  /// Provides id of user.
  final String id;

  /// Provides name of user.
  final String name;

  /// Provides profile picture URL of user.
  final String? profilePhoto;
  
  final String? chatmaxima_user_name; 
  final String? platform;


  ChatUser({
    required this.id,
    required this.name,
    this.profilePhoto,
    required this.chatmaxima_user_name,
    this.platform,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) => ChatUser(
        id: json["id"],
        name: json["name"],
        profilePhoto: json["profilePhoto"],
        chatmaxima_user_name: json["chatmaxima_user_name"],
        platform: json["platform"],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'profilePhoto': profilePhoto,
        'chatmaxima_user_name':chatmaxima_user_name,
        'platform':platform
      };
}
