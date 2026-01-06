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
import 'package:any_link_preview/any_link_preview.dart';
import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/models/link_preview_configuration.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/constants/constants.dart';
import 'package:flutter/gestures.dart';
class LinkPreview extends StatelessWidget {
  const LinkPreview({
    Key? key,
    required this.url,
    this.linkPreviewConfig,
  }) : super(key: key);

  /// Provides url which is passed in message.
  final String url;

  /// Provides configuration of chat bubble appearance when link/URL is passed
  /// in message.
  final LinkPreviewConfiguration? linkPreviewConfig;
  // Function to extract URLs from text and make them clickable
    InlineSpan _buildTextWithLinks(String text, [TextStyle? baseStyle]) {
      // URL pattern to match http/https links
      final urlPattern = RegExp(
        r'(?:(?:https?|ftp):\/\/)?(?:www\.)?[\w\-]+\.[\w\-]+(?:\/[^\s]*)?',
        caseSensitive: false,
        multiLine: false,
      );
      
      final matches = urlPattern.allMatches(text);
      if (matches.isEmpty) {
        // No URLs found, return plain text
        return TextSpan(text: text, style: baseStyle);
      }
      
      List<TextSpan> spans = [];
      int currentIndex = 0;
      
      for (final match in matches) {
        // Add text before the URL (black color)
        if (match.start > currentIndex) {
          spans.add(
            TextSpan(
              text: text.substring(currentIndex, match.start),
              style: baseStyle ?? const TextStyle(color: Colors.black),
            ),
          );
        }
        
        // Get the URL
        String urlText = match.group(0)!;
        
        // Add the clickable URL (blue color)
        spans.add(
          TextSpan(
            text: urlText,
            style: (baseStyle ?? const TextStyle()).copyWith(
              color: Colors.blue,
              decoration: TextDecoration.underline,
              decorationColor: Colors.black,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                try {
                  final uri = Uri.parse(urlText);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                } catch (e) {
                  print('Error launching URL: $e');
                }
              },
          ),
        );
        
        currentIndex = match.end;
      }
      
      // Add any remaining text after the last URL (black color)
      if (currentIndex < text.length) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex),
            style: const TextStyle(color: Colors.black),
          ),
        );
      }
      
      return TextSpan(children: spans);
    }
  @override
  Widget build(BuildContext context) {
    // Check if the message contains ONLY a URL (no other text)
    final urlPattern = RegExp(r'^https?:\/\/[^\s]+$', caseSensitive: false);
    final isPureUrl = urlPattern.hasMatch(url.trim());
    return Padding(
      padding: linkPreviewConfig?.padding ??
          const EdgeInsets.symmetric(horizontal: 6, vertical: verticalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPureUrl)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: verticalPadding),
              child: url.isImageUrl
                  ? InkWell(
                      onTap: _onLinkTap,
                      child: Image.network(
                        url,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                      ),
                    )
                  : AnyLinkPreview(
                      link: url,
                      removeElevation: true,
                      proxyUrl: linkPreviewConfig?.proxyUrl,
                      onTap: _onLinkTap,
                      placeholderWidget: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.25,
                        width: double.infinity,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 1,
                            color: linkPreviewConfig?.loadingColor,
                          ),
                        ),
                      ),
                      backgroundColor: linkPreviewConfig?.backgroundColor ?? Colors.grey.shade200,
                      borderRadius: linkPreviewConfig?.borderRadius,
                      bodyStyle: linkPreviewConfig?.bodyStyle ?? const TextStyle(color: Colors.black),
                      titleStyle: linkPreviewConfig?.titleStyle,
                      errorBody: '',
                      errorTitle: '',
                    ),
            ),
          
          if (isPureUrl) const SizedBox(height: verticalPadding),
          
          // Show the message text with clickable URLs
          RichText(
            text: _buildTextWithLinks(
              url,
              linkPreviewConfig?.linkStyle?.copyWith(color: Colors.black) ??
                  const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                  ),
            ),
          ),
          
        ],
      ),
    );
  }
void _onLinkTap() {
    if (linkPreviewConfig?.onUrlDetect != null) {
      linkPreviewConfig?.onUrlDetect!(url);
    } else {
      _launchURL();
    }
  }

  void _launchURL() async {
    final parsedUrl = Uri.parse(url);
    await canLaunchUrl(parsedUrl)
        ? await launchUrl(parsedUrl)
        : throw couldNotLunch;
  }
}
