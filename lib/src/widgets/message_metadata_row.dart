import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

/// Shared metadata row widget for all message types.
/// Displays profile name, time, and status indicators with modern styling.
class MessageMetadataRow extends StatelessWidget
{
  const MessageMetadataRow({
    Key? key,
    required this.profileName,
    required this.createdAt,
    required this.isMessageBySender,
    this.metadataTextStyle,
    this.metadataIconColor,
  }) : super(key: key);

  final String? profileName;
  final DateTime createdAt;
  final bool isMessageBySender;
  final TextStyle? metadataTextStyle;
  final Color? metadataIconColor;

  @override
  Widget build(BuildContext context)
  {
    final formattedTime = DateFormat('hh:mm a').format(createdAt);
    final defaultStyle = metadataTextStyle ?? const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Color(0xFF6C757D),
    );
    final iconColor = metadataIconColor ?? const Color(0xFF6C757D);
    const double iconSize = 11;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMessageBySender) ...[
          if (profileName == 'Bot') ...[
            Icon(Icons.smart_toy_outlined, size: iconSize, color: iconColor),
            const SizedBox(width: 4),
            Text('Bot', style: defaultStyle),
            const SizedBox(width: 4),
          ] else if (profileName == 'Summary') ...[
            FaIcon(FontAwesomeIcons.magicWandSparkles, color: iconColor, size: iconSize),
            const SizedBox(width: 4),
            Text(profileName ?? '', style: defaultStyle),
            const SizedBox(width: 4),
          ] else ...[
            Icon(Icons.person, size: iconSize, color: iconColor),
            const SizedBox(width: 4),
            Text(profileName ?? '', style: defaultStyle),
            const SizedBox(width: 4),
          ],
        ] else ...[
          if ((profileName ?? '').isNotEmpty) ...[
            Icon(Icons.person, size: iconSize, color: iconColor),
            const SizedBox(width: 4),
            Text(profileName!, style: defaultStyle),
            const SizedBox(width: 4),
          ],
        ],
        Icon(Icons.access_time, size: iconSize, color: iconColor),
        const SizedBox(width: 4),
        Text(formattedTime, style: defaultStyle),
      ],
    );
  }
}
