import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

class MarkdownTextParser {
  static List<TextSpan> parseMarkdown(String text, TextStyle baseStyle) {
    if (text.isEmpty) return [TextSpan(text: text, style: baseStyle)];
    
    final List<TextSpan> result = [];
    int currentIndex = 0;
    
    // Find ALL markdown patterns in one pass
    final RegExp allPatterns = RegExp(
      r'(`.*?`)|(~.*?~)|(\*.*?\*)|(_.*?_)',
      caseSensitive: false,
      multiLine: true,
    );
    
    final matches = allPatterns.allMatches(text);
    
    if (matches.isEmpty) {
      // No markdown found, just return plain text with URL detection
      return _applyUrlDetection([TextSpan(text: text, style: baseStyle)], baseStyle);
    }
    
    for (final match in matches) {
      // Add text before the match
      if (match.start > currentIndex) {
        final normalText = text.substring(currentIndex, match.start);
        result.addAll(_applyUrlDetection([TextSpan(text: normalText, style: baseStyle)], baseStyle));
      }
      
      // Process the matched pattern
      final matchText = match.group(0)!;
      final matchedSpan = _processMatch(matchText, baseStyle);
      if (matchedSpan != null) {
        result.add(matchedSpan);
      }
      
      currentIndex = match.end;
    }
    
    // Add remaining text
    if (currentIndex < text.length) {
      final remainingText = text.substring(currentIndex);
      result.addAll(_applyUrlDetection([TextSpan(text: remainingText, style: baseStyle)], baseStyle));
    }
    
    return result;
  }
  
  static TextSpan? _processMatch(String matchText, TextStyle baseStyle) {
    // Monospace
    if (matchText.startsWith('`') && matchText.endsWith('`')) {
      final content = matchText.substring(1, matchText.length - 1);
      return TextSpan(
        text: content,
        style: baseStyle.copyWith(
          fontFamily: 'monospace',
          fontSize: baseStyle.fontSize,
          color: Colors.pink.shade700,
        ),
      );
    }
    // Strikethrough
    else if (matchText.startsWith('~') && matchText.endsWith('~')) {
      final content = matchText.substring(1, matchText.length - 1);
      // Recursively parse content inside strikethrough
      final innerSpans = parseMarkdown(content, baseStyle);
      return TextSpan(
        children: innerSpans,
        style: baseStyle.copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: Colors.black,
          decorationThickness: 1.5,
        ),
      );
    }
    // Bold
    else if (matchText.startsWith('*') && matchText.endsWith('*')) {
      final content = matchText.substring(1, matchText.length - 1);
      // Recursively parse content inside bold
      final innerSpans = parseMarkdown(content, baseStyle);
      return TextSpan(
        children: innerSpans,
        style: baseStyle.copyWith(fontWeight: FontWeight.bold),
      );
    }
    // Italic
    else if (matchText.startsWith('_') && matchText.endsWith('_')) {
      final content = matchText.substring(1, matchText.length - 1);
      // Recursively parse content inside italic
      final innerSpans = parseMarkdown(content, baseStyle);
      return TextSpan(
        children: innerSpans,
        style: baseStyle.copyWith(fontStyle: FontStyle.italic),
      );
    }
    
    return null;
  }
  
  static List<TextSpan> _applyUrlDetection(List<TextSpan> spans, TextStyle baseStyle) {
    final List<TextSpan> result = [];
    
    final urlPattern = RegExp(
      r'\b(?:https?|ftp):\/\/'
      r'(?:www\.)?'
      r'(?:[\w\-]+\.)+[\w\-]{2,}'
      r'(?:\/[^\s]*)?',
      caseSensitive: false,
      multiLine: false,
    );
    
    for (final span in spans) {
      final text = span.text ?? '';
      if (text.isEmpty || span.children != null) {
        result.add(span);
        continue;
      }
      
      final matches = urlPattern.allMatches(text);
      
      if (matches.isEmpty) {
        result.add(span);
        continue;
      }
      
      int currentIndex = 0;
      for (final match in matches) {
        if (match.start > currentIndex) {
          result.add(TextSpan(
            text: text.substring(currentIndex, match.start),
            style: span.style,
          ));
        }
        
        String urlText = match.group(0)!;
        if (!urlText.toLowerCase().startsWith('http')) {
          urlText = 'https://$urlText';
        }
        
        result.add(TextSpan(
          text: match.group(0),
          style: (span.style ?? baseStyle).copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              try {
                final uri = Uri.parse(urlText);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (e) {
                print('Error launching URL: $e');
              }
            },
        ));
        
        currentIndex = match.end;
      }
      
      if (currentIndex < text.length) {
        result.add(TextSpan(
          text: text.substring(currentIndex),
          style: span.style,
        ));
      }
    }
    
    return result;
  }
}
