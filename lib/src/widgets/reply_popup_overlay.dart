import 'package:chatview/chatview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../chatview.dart';
import '../models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    this.onMarkAsUnreadTap,
    this.user_roles,
    this.show_translate = true,
    this.show_ticket = true,
  }) : super(key: key);

  final VoidCallBack onTap;
  final bool replyshowPopUp;
  final MessageCallBack onReplyTap;
  final MessageCallBack onCopyTap;
  final MessageCallBack onTranslateTap;
  final MessageCallBack onTicketTap;
  final MessageCallBack onDeleteTap;
  final MessageCallBack? onMarkAsUnreadTap;

  final String? user_roles;

  /// Show the "Translate" menu item (default true; agent app keeps it).
  final bool show_translate;

  /// Show the "Ticket" menu item (default true; agent app keeps it).
  final bool show_ticket;

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
  String? _cbLeadId;

  @override
  void initState() {
    super.initState();
    _loadCbLeadId();
    _initializeAnimationControllers();
    // Sync animation with initial value in case popup starts open.
    if (showPopUp) {
      _animationController.forward();
    }
  }

  // Animation is now driven here instead of inside build().
  @override
  void didUpdateWidget(covariant ReplyPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replyshowPopUp != oldWidget.replyshowPopUp) {
      if (widget.replyshowPopUp) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _loadCbLeadId() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _cbLeadId = prefs.getString('cb_lead_id');
    });
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
    final toolTipWidth = deviceWidth > 450 ? 450.0 : deviceWidth;

    return showPopUp
        ? Stack(
            children: [
              // Full-screen transparent barrier: tapping anywhere outside
              // the popup closes it. Sits behind the popup in this same
              // Stack, so it only ever receives taps that miss the popup.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
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
                      // Clamp away from exact 0 to avoid a degenerate
                      // zero-size Transform combined with BoxShadow.
                      scale: _scaleAnimation.value.clamp(0.01, 1.0),
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                    // Built once, not on every animation tick.
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 170),
                      margin: const EdgeInsets.symmetric(horizontal: 25),
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
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
            ],
          )
        : const SizedBox.shrink();
  }

  Widget get _replyPopupRow => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_message?.profilename != 'Summary' &&
              _message?.message_deleted == false)
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
          if (_message?.message_deleted == false)
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
          if (widget.show_translate &&
              _message?.profilename != 'Summary' &&
              _message?.message_deleted == false)
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
          if (_message?.profilename != "Bot" &&
              _message?.profilename != "bot" &&
              _message?.profilename != 'Summary' &&
              _message?.message_deleted == false &&
              (widget.user_roles == 'admin' ||
                  widget.user_roles == 'member' ||
                  widget.user_roles == 'Admin' ||
                  widget.user_roles == 'Member'))
            _buildReplyAction(
              icon: Icons.delete,
              text: 'Delete',
              onTap: () {
                widget.onTap();
                if (_message != null) {
                  widget.onDeleteTap(_message!);
                }
              },
              isDelete: true,
            ),
          if (_message?.message_deleted == false &&
              _message?.sendBy == '${_cbLeadId}' &&
              _message?.profilename != "Bot" &&
              _message?.profilename != "bot" &&
              _message?.profilename != 'Summary')
            _buildReplyAction(
              icon: Icons.mail,
              text: 'Mark as Unread',
              onTap: () {
                widget.onTap(); // This closes the popup
                if (_message != null) {
                  widget.onMarkAsUnreadTap?.call(_message!);
                }
              },
            ),
          if (widget.show_ticket &&
              _message?.profilename != "Bot" &&
              _message?.profilename != "bot" &&
              _message?.profilename != 'Summary' &&
              _message?.message_deleted == false)
            _buildReplyAction(
              icon: Icons.confirmation_num,
              text: 'Create Ticket',
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
          if (_message?.message_deleted == true)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline,
                        color: Colors.grey[600], size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Message has been deleted',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );

  Widget _buildReplyAction({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isDelete = false,
  }) {
    final color = isDelete ? Colors.red : Colors.black;

    // NOTE: no Expanded here — that's what caused the RenderFlex crash.
    // Each row now just takes its natural height inside the Column.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
