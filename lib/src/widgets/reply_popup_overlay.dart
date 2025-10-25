import 'package:chatview/chatview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../chatview.dart';
import '../models/models.dart';


class ReplyPopup extends StatefulWidget {
  const ReplyPopup({
    Key? key,
    required this.onTap,
    required this.replyshowPopUp,
    required this.onReplyTap,
    required this.onCopyTap,
    required this.onTranslateTap,
    required this.onTicketTap,
    required this.onDeleteTap,
  }) : super(key: key);

  final VoidCallBack onTap;
  final bool replyshowPopUp;
  final MessageCallBack onReplyTap;
  final MessageCallBack onCopyTap;
  final MessageCallBack onTranslateTap;
  final MessageCallBack onTicketTap;
  final MessageCallBack onDeleteTap;

  @override
  ReplyPopupState createState() => ReplyPopupState();
}

class ReplyPopupState extends State<ReplyPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  bool get showPopUp => widget.replyshowPopUp;
  double _yCoordinate = 0.0;
  double _xCoordinate = 0.0;
  Message? _message;

  @override
  void initState() {
    super.initState();
    _initializeAnimationControllers();
  }

  void _initializeAnimationControllers() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
      reverseCurve: Curves.easeInOutSine,
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceWidth = MediaQuery.of(context).size.width;
    final toolTipWidth = deviceWidth > 450 ? 450 : deviceWidth;
    
    if (showPopUp) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    
    return showPopUp
        ? Positioned(
            top: _yCoordinate,
            left: _xCoordinate + toolTipWidth > deviceWidth
                ? deviceWidth - toolTipWidth
                : _xCoordinate - (toolTipWidth / 2) < 0
                    ? 0
                    : _xCoordinate - (toolTipWidth / 2),
            child: SizedBox(
              width: deviceWidth > 450 ? 450 : deviceWidth,
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: 350,
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 25),
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade400,
                          blurRadius: 8,
                          spreadRadius: -2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _replyPopupRow,
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
  }

  Widget get _replyPopupRow => Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildReplyAction(
          icon: Icons.reply,
          text: 'Reply',
          onTap: () {
            widget.onTap(); // This closes the popup
            if (_message != null) {
              widget.onReplyTap(_message!);
            }
          },
        ),
        _buildReplyAction(
          icon: Icons.copy,
          text: 'Copy',
          onTap: () {
            widget.onTap(); // This closes the popup
            if (_message != null) {
              widget.onCopyTap(_message!);
            }
          },
        ),
        _buildReplyAction(
          icon: Icons.translate,
          text: 'Translate',
          onTap: () {
            widget.onTap(); // This closes the popup
            if (_message != null) {
              widget.onTranslateTap(_message!);
            }
          },
        ),
        if (_message?.profilename != "Bot" && _message?.profilename != "bot")
          _buildReplyAction(
            icon: Icons.delete, // Fixed: changed from Icons.Delete to Icons.delete
            text: 'Delete',
            onTap: () {
              widget.onTap();
              // Add your delete logic here
              if (_message != null) {
                // Call delete callback if you add it
                 widget.onDeleteTap(_message!);
              }
            },
            isDelete: true, // Add this parameter
          ),
          if (_message?.profilename != "Bot" && _message?.profilename != "bot")
            _buildReplyAction(
              icon: Icons.confirmation_num,
              text: 'Ticket',
              onTap: () {
                widget.onTap();
                if (_message != null) {
                 
                  if (_message!.messageType == MessageType.image || 
                      _message!.messageType == MessageType.custom) {
                    // Create a copy of the message with empty message text
                    Message emptyMessage = Message(
                      id: _message!.id,
                      message: "", // Empty message
                      messageType: _message!.messageType,
                      sendBy: _message!.sendBy,
                      createdAt: _message!.createdAt,
                      // Copy other properties as needed
                    );
                    widget.onTicketTap(emptyMessage);
                  } else {
                    widget.onTicketTap(_message!);
                  }
                }
              },
            ),
      ],
    );

  Widget _buildReplyAction({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isDelete = false, // Add this parameter
  }) {
    final color = isDelete ? Colors.red : Colors.black; // Red for delete, black for others
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: color, // Use the color variable
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    color: color, // Use the color variable
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void refreshWidget({
    required Message message,
    required double xCoordinate,
    required double yCoordinate,
  }) {
    setState(() {
      _message = message;
      _xCoordinate = xCoordinate;
      _yCoordinate = yCoordinate;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
