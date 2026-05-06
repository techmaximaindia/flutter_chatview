/* // lib/utils/markdown_text_parser.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

class MarkdownTextParser {
  static List<TextSpan> parseMarkdown(String text, TextStyle baseStyle) {
    if (text.isEmpty) return [TextSpan(text: text, style: baseStyle)];
    
    // First, parse markdown formatting (bold, italic, strikethrough)
    final formattedSpans = _parseMarkdownFormatting(text, baseStyle);
    
    // Then, apply URL detection to all spans
    return _applyUrlDetection(formattedSpans, baseStyle);
  }
  
  static List<TextSpan> _parseMarkdownFormatting(String text, TextStyle baseStyle) {
    if (text.isEmpty) return [TextSpan(text: text, style: baseStyle)];
    
    final List<TextSpan> spans = [];
    
    // Custom patterns for your syntax
    final RegExp boldPattern = RegExp(r'\*(.*?)\*');           // *text* -> bold
    final RegExp italicPattern = RegExp(r'_(.*?)_');          // _text_ -> italic
    final RegExp strikethroughPattern = RegExp(r'~(.*?)~');   // ~text~ -> strikethrough
    
    String remaining = text;
    
    // First handle strikethrough (~text~)
    final strikethroughMatches = strikethroughPattern.allMatches(remaining);
    if (strikethroughMatches.isNotEmpty) {
      int currentPos = 0;
      for (final match in strikethroughMatches) {
        if (match.start > currentPos) {
          final normalText = remaining.substring(currentPos, match.start);
          spans.addAll(_parseBoldAndItalic(normalText, baseStyle));
        }
        final strikethroughText = match.group(1)!;
        spans.add(TextSpan(
          text: strikethroughText,
          style: baseStyle.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor: Colors.black,  
            decorationThickness: 1.5, 
          ),
        ));
        currentPos = match.end;
      }
      if (currentPos < remaining.length) {
        final remainingText = remaining.substring(currentPos);
        spans.addAll(_parseBoldAndItalic(remainingText, baseStyle));
      }
    } else {
      spans.addAll(_parseBoldAndItalic(remaining, baseStyle));
    }
    
    return spans;
  }
  
  static List<TextSpan> _parseBoldAndItalic(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final RegExp boldPattern = RegExp(r'\*(.*?)\*');     // *text* -> bold
    final RegExp italicPattern = RegExp(r'_(.*?)_');    // _text_ -> italic
    
    String remaining = text;
    
    // First handle bold (*text*)
    final boldMatches = boldPattern.allMatches(remaining);
    if (boldMatches.isNotEmpty) {
      int currentPos = 0;
      for (final match in boldMatches) {
        if (match.start > currentPos) {
          final normalText = remaining.substring(currentPos, match.start);
          spans.addAll(_parseItalicOnly(normalText, baseStyle));
        }
        final boldText = match.group(1)!;
        spans.add(TextSpan(
          text: boldText,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
        currentPos = match.end;
      }
      if (currentPos < remaining.length) {
        final remainingText = remaining.substring(currentPos);
        spans.addAll(_parseItalicOnly(remainingText, baseStyle));
      }
    } else {
      spans.addAll(_parseItalicOnly(remaining, baseStyle));
    }
    
    return spans;
  }
  
  static List<TextSpan> _parseItalicOnly(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final RegExp italicPattern = RegExp(r'_(.*?)_');     // _text_ -> italic
    
    String remaining = text;
    final italicMatches = italicPattern.allMatches(remaining);
    
    if (italicMatches.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    
    int currentPos = 0;
    for (final match in italicMatches) {
      if (match.start > currentPos) {
        spans.add(TextSpan(
          text: remaining.substring(currentPos, match.start),
          style: baseStyle,
        ));
      }
      
      final italicText = match.group(1)!;
      spans.add(TextSpan(
        text: italicText,
        style: baseStyle.copyWith(fontStyle: FontStyle.italic),
      ));
      
      currentPos = match.end;
    }
    
    if (currentPos < remaining.length) {
      spans.add(TextSpan(
        text: remaining.substring(currentPos),
        style: baseStyle,
      ));
    }
    
    return spans;
  }
  
  static List<TextSpan> _applyUrlDetection(List<TextSpan> spans, TextStyle baseStyle) {
    final List<TextSpan> result = [];
    
    // URL pattern to match http/https links
    final urlPattern = RegExp(
      r'\b(?:https?|ftp):\/\/'  // Required protocol
      r'(?:www\.)?'  // Optional www
      r'(?:[\w\-]+\.)+[\w\-]{2,}'  // Domain
      r'(?:\/[^\s]*)?',  // Optional path
      caseSensitive: false,
      multiLine: false,
    );
    
    for (final span in spans) {
      final text = span.text ?? '';
      if (text.isEmpty) {
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
        // Add text before URL
        if (match.start > currentIndex) {
          result.add(TextSpan(
            text: text.substring(currentIndex, match.start),
            style: span.style,
          ));
        }
        
        // Add clickable URL
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
      
      // Add remaining text after last URL
      if (currentIndex < text.length) {
        result.add(TextSpan(
          text: text.substring(currentIndex),
          style: span.style,
        ));
      }
    }
    
    return result;
  }
} */

// lib/utils/markdown_text_parser.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

class MarkdownTextParser {
  static List<TextSpan> parseMarkdown(String text, TextStyle baseStyle) {
    if (text.isEmpty) return [TextSpan(text: text, style: baseStyle)];
    
    // First, parse markdown formatting (bold, italic, strikethrough, monospace)
    final formattedSpans = _parseMarkdownFormatting(text, baseStyle);
    
    // Then, apply URL detection to all spans
    return _applyUrlDetection(formattedSpans, baseStyle);
  }
  
  static List<TextSpan> _parseMarkdownFormatting(String text, TextStyle baseStyle) {
    if (text.isEmpty) return [TextSpan(text: text, style: baseStyle)];
    
    final List<TextSpan> spans = [];
    
    // Custom patterns for your syntax
    final RegExp monospacePattern = RegExp(r'`(.*?)`');     // `text` -> monospace
    final RegExp boldPattern = RegExp(r'\*(.*?)\*');        // *text* -> bold
    final RegExp italicPattern = RegExp(r'_(.*?)_');       // _text_ -> italic
    final RegExp strikethroughPattern = RegExp(r'~(.*?)~'); // ~text~ -> strikethrough
    
    String remaining = text;
    
    // First handle monospace (`text`)
    final monospaceMatches = monospacePattern.allMatches(remaining);
    if (monospaceMatches.isNotEmpty) {
      int currentPos = 0;
      for (final match in monospaceMatches) {
        if (match.start > currentPos) {
          final normalText = remaining.substring(currentPos, match.start);
          spans.addAll(_parseStrikethrough(normalText, baseStyle));
        }
        final monospaceText = match.group(1)!;
        spans.add(TextSpan(
          text: monospaceText,
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            fontSize: baseStyle.fontSize,
            color: Colors.pink.shade700,  // Only pink text color, no background
          ),
        ));
        currentPos = match.end;
      }
      if (currentPos < remaining.length) {
        final remainingText = remaining.substring(currentPos);
        spans.addAll(_parseStrikethrough(remainingText, baseStyle));
      }
    } else {
      spans.addAll(_parseStrikethrough(remaining, baseStyle));
    }
    
    return spans;
  }
  
  static List<TextSpan> _parseStrikethrough(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final RegExp strikethroughPattern = RegExp(r'~(.*?)~');   // ~text~ -> strikethrough
    
    String remaining = text;
    final strikethroughMatches = strikethroughPattern.allMatches(remaining);
    
    if (strikethroughMatches.isNotEmpty) {
      int currentPos = 0;
      for (final match in strikethroughMatches) {
        if (match.start > currentPos) {
          final normalText = remaining.substring(currentPos, match.start);
          spans.addAll(_parseBoldAndItalic(normalText, baseStyle));
        }
        final strikethroughText = match.group(1)!;
        spans.add(TextSpan(
          text: strikethroughText,
          style: baseStyle.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor: Colors.black,
            decorationThickness: 1.5,
          ),
        ));
        currentPos = match.end;
      }
      if (currentPos < remaining.length) {
        final remainingText = remaining.substring(currentPos);
        spans.addAll(_parseBoldAndItalic(remainingText, baseStyle));
      }
    } else {
      spans.addAll(_parseBoldAndItalic(remaining, baseStyle));
    }
    
    return spans;
  }
  
  static List<TextSpan> _parseBoldAndItalic(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final RegExp boldPattern = RegExp(r'\*(.*?)\*');     // *text* -> bold
    final RegExp italicPattern = RegExp(r'_(.*?)_');    // _text_ -> italic
    
    String remaining = text;
    
    // First handle bold (*text*)
    final boldMatches = boldPattern.allMatches(remaining);
    if (boldMatches.isNotEmpty) {
      int currentPos = 0;
      for (final match in boldMatches) {
        if (match.start > currentPos) {
          final normalText = remaining.substring(currentPos, match.start);
          spans.addAll(_parseItalicOnly(normalText, baseStyle));
        }
        final boldText = match.group(1)!;
        spans.add(TextSpan(
          text: boldText,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
        currentPos = match.end;
      }
      if (currentPos < remaining.length) {
        final remainingText = remaining.substring(currentPos);
        spans.addAll(_parseItalicOnly(remainingText, baseStyle));
      }
    } else {
      spans.addAll(_parseItalicOnly(remaining, baseStyle));
    }
    
    return spans;
  }
  
  static List<TextSpan> _parseItalicOnly(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final RegExp italicPattern = RegExp(r'_(.*?)_');     // _text_ -> italic
    
    String remaining = text;
    final italicMatches = italicPattern.allMatches(remaining);
    
    if (italicMatches.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    
    int currentPos = 0;
    for (final match in italicMatches) {
      if (match.start > currentPos) {
        spans.add(TextSpan(
          text: remaining.substring(currentPos, match.start),
          style: baseStyle,
        ));
      }
      
      final italicText = match.group(1)!;
      spans.add(TextSpan(
        text: italicText,
        style: baseStyle.copyWith(fontStyle: FontStyle.italic),
      ));
      
      currentPos = match.end;
    }
    
    if (currentPos < remaining.length) {
      spans.add(TextSpan(
        text: remaining.substring(currentPos),
        style: baseStyle,
      ));
    }
    
    return spans;
  }
  
  static List<TextSpan> _applyUrlDetection(List<TextSpan> spans, TextStyle baseStyle) {
    final List<TextSpan> result = [];
    
    // URL pattern to match http/https links
    final urlPattern = RegExp(
      r'\b(?:https?|ftp):\/\/'  // Required protocol
      r'(?:www\.)?'  // Optional www
      r'(?:[\w\-]+\.)+[\w\-]{2,}'  // Domain
      r'(?:\/[^\s]*)?',  // Optional path
      caseSensitive: false,
      multiLine: false,
    );
    
    for (final span in spans) {
      final text = span.text ?? '';
      if (text.isEmpty) {
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
        // Add text before URL
        if (match.start > currentIndex) {
          result.add(TextSpan(
            text: text.substring(currentIndex, match.start),
            style: span.style,
          ));
        }
        
        // Add clickable URL
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
      
      // Add remaining text after last URL
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