// max_ia_prompt_dialog.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MaxIAPromptDialog extends StatefulWidget {
  final Function(String) onGenerate;
  final String typedText; // This will contain the input text from the field
  
  const MaxIAPromptDialog({
    Key? key,
    required this.onGenerate,
    required this.typedText,
  }) : super(key: key);
  
  @override
  State<MaxIAPromptDialog> createState() => _MaxIAPromptDialogState();
}

class _MaxIAPromptDialogState extends State<MaxIAPromptDialog> {
  late final TextEditingController _promptController;
  bool _isActive = true;
  
  @override
  void initState() {
    super.initState();
    // Pre-fill the text field with the typed text
    _promptController = TextEditingController(text: widget.typedText);
    
    // Auto-focus and place cursor at the end
    Future.delayed(Duration.zero, () {
      if (_promptController.hasListeners) {
        _promptController.selection = TextSelection.fromPosition(
          TextPosition(offset: _promptController.text.length),
        );
      }
    });
  }
  
  @override
  void dispose() {
    _isActive = false;
    _promptController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final bool hasTypedText = widget.typedText.isNotEmpty;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF820AFF)],
                              ).createShader(bounds),
                              child: const FaIcon(
                                FontAwesomeIcons.magicWandSparkles,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Generate Reply with MaxIA',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasTypedText
                              ? 'Edit your message below and add instructions to improve it.'
                              : 'Enter your message and let MaxIA AI Assistant help you write better content.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.close, size: 20, color: Colors.grey.shade400),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            
            // Text area with pre-filled typed text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    TextField(
                      controller: _promptController,
                      maxLines: 6,
                      minLines: 6,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: hasTypedText
                            ? 'Edit your message or add instructions...'
                            : 'Type your message here...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                          height: 1.5,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 36),
                      ),
                    ),
                   /*  Positioned(
                      right: 10,
                      bottom: 8,
                      child: Icon(
                        Icons.mic_none,
                        size: 22,
                        color: Colors.grey.shade400,
                      ),
                    ), */
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Generate button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _promptController,
                  builder: (_, value, __) {
                    final hasText = value.text.trim().isNotEmpty;
                    return ElevatedButton(
                      onPressed: !hasText
                          ? null
                          : () {
                              final finalText = _promptController.text.trim();
                              // Pass the final text to the callback
                              widget.onGenerate(finalText);
                              Navigator.of(context).pop();
                            
                            },/* () {
                              final finalText = _promptController.text.trim();
                              Navigator.of(context).pop();
                              // Pass the final text to the callback
                              widget.onGenerate(finalText);
                            }, */
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.grey.shade200,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: hasText
                              ? const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF820AFF)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : null,
                          color: hasText ? null : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FaIcon(
                                FontAwesomeIcons.magicWandSparkles,
                                size: 14,
                                color: hasText ? Colors.white : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Generate',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: hasText ? Colors.white : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
