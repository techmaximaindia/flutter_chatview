import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MaxIAResponseBottomSheet extends StatefulWidget {
  final String promptText;
  final Future<String> Function(String) aiAssistCall;
  final Future<List<Map<String, String>>> Function() fetchLanguagesCall;
  final Future<String> Function(String, String) translateCall;
  final VoidCallback onSendPressed;
  final TextEditingController messageController;
  final ValueNotifier<bool> sendEnabledNotifier;
  final ValueNotifier<bool> loadingAINotifier;
  final bool isChatPage;

  const MaxIAResponseBottomSheet({
    Key? key,
    required this.promptText,
    required this.aiAssistCall,
    required this.fetchLanguagesCall,
    required this.translateCall,
    required this.onSendPressed,
    required this.messageController,
    required this.sendEnabledNotifier,
    required this.loadingAINotifier,
    required this.isChatPage,
  }) : super(key: key);

  @override
  State<MaxIAResponseBottomSheet> createState() =>
      _MaxIAResponseBottomSheetState();
}

class _MaxIAResponseBottomSheetState extends State<MaxIAResponseBottomSheet> {
  // ── State ────────────────────────────────────────────────────────────────
  bool _isResponseReady = false;
  bool _isTranslating = false;
  bool _isRegenerating = false;
  bool _isEditing = false;
  bool _translationFailed = false;
  bool _isAiError = false;
  String _originalResponse = '';
  String _translatedText = '';
  String? _selectedLanguage;
  int _currentPage = 0;

  late final TextEditingController _sheetMsgController;
  late final TextEditingController _translatedController;
  late final PageController _pageController;

  // FIX 3: separate scroll controllers — sharing one between two simultaneously
  // alive PageView children causes a "ScrollController attached to multiple
  // scroll views" crash
  late final ScrollController _originalScrollController;
  late final ScrollController _translatedScrollController;

  List<Map<String, String>> _availableLanguages = [];

  // ── Safe helpers ──────────────────────────────────────────────────────────

  // FIX 1: guard ValueNotifier writes — the notifier lives in the parent widget
  // and may be disposed before our async callbacks finish
  void _safeWriteNotifier<T>(ValueNotifier<T> notifier, T value) {
    if (!mounted) return;
    try {
      notifier.value = value;
    } catch (_) {
      // notifier was disposed externally — silently ignore
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _sheetMsgController = TextEditingController();
    _translatedController = TextEditingController();
    _pageController = PageController();
    _originalScrollController = ScrollController();
    _translatedScrollController = ScrollController();

    widget.messageController.clear();
    _safeWriteNotifier(widget.sendEnabledNotifier, false);
    _safeWriteNotifier(widget.loadingAINotifier, true);

    _callAIAssist();
  }

  @override
  void dispose() {
    // Reset parent notifiers before our controllers are torn down
    _safeWriteNotifier(widget.sendEnabledNotifier, false);
    _safeWriteNotifier(widget.loadingAINotifier, false);
    widget.messageController.clear();

    _sheetMsgController.dispose();
    _translatedController.dispose();
    _pageController.dispose();
    _originalScrollController.dispose();
    _translatedScrollController.dispose();
    super.dispose();
  }

  // ── API calls ─────────────────────────────────────────────────────────────

  Future<void> _callAIAssist() async {
    try {
      // FIX 4: only fetch languages when the translate UI is actually shown
      if (widget.isChatPage) {
        _availableLanguages = await widget.fetchLanguagesCall();
        if (!mounted) return;
      }

      final response = await widget.aiAssistCall(widget.promptText);
      if (!mounted) return;

      _originalResponse = response;
      _translatedText = response;
      _sheetMsgController.text = response;
      _safeWriteNotifier(widget.sendEnabledNotifier, response.isNotEmpty);
      _safeWriteNotifier(widget.loadingAINotifier, false);

      _safeSetState(() {
        _isResponseReady = true;
        _isAiError = false;
      });
    } catch (error) {
      if (!mounted) return;

      final msg = error.toString().replaceFirst('Exception: ', '');
      _originalResponse = msg;
      _sheetMsgController.text = msg;
      _safeWriteNotifier(widget.sendEnabledNotifier, false);
      _safeWriteNotifier(widget.loadingAINotifier, false);

      _safeSetState(() {
        _isResponseReady = true;
        _isAiError = true;
      });
    }
  }

  Future<void> _regenerate() async {
    if (!mounted || _isRegenerating) return;

    // FIX 2: jump to page 0 BEFORE setState shrinks the children list,
    // otherwise PageController is still on page 1 with only 1 child → crash
    if (_pageController.hasClients && _currentPage != 0) {
      _pageController.jumpToPage(0);
    }

    _safeSetState(() {
      _isRegenerating = true;
      _isEditing = false;
      _isTranslating = false;
      _translationFailed = false;
      _isAiError = false;
      _selectedLanguage = null;
      _currentPage = 0;
    });

    _sheetMsgController.clear();
    _safeWriteNotifier(widget.sendEnabledNotifier, false);

    try {
      final response = await widget.aiAssistCall(widget.promptText);
      if (!mounted) return;

      _originalResponse = response;
      _translatedText = response;
      _sheetMsgController.text = response;
      _translatedController.clear();
      _safeWriteNotifier(widget.sendEnabledNotifier, response.isNotEmpty);

      _safeSetState(() {
        _isRegenerating = false;
        _isAiError = false;
      });
    } catch (error) {
      if (!mounted) return;

      final msg = error.toString().replaceFirst('Exception: ', '');
      _originalResponse = msg;
      _sheetMsgController.text = msg;
      _safeWriteNotifier(widget.sendEnabledNotifier, false);

      _safeSetState(() {
        _isRegenerating = false;
        _isAiError = true;
      });
    }
  }

  Future<void> _triggerTranslation(String lang) async {
    if (!mounted || _isTranslating) return;

    // Already translated to this language — just navigate to the translated page
    if (_selectedLanguage == lang && !_translationFailed) {
      _goToPage(1);
      return;
    }

    _safeSetState(() {
      _selectedLanguage = lang;
      _isTranslating = true;
      _translationFailed = false;
    });
    _goToPage(1);

    try {
      final translated = await widget.translateCall(_originalResponse, lang);
      if (!mounted) return;

      _translatedText = translated;
      _translatedController.text = translated;
      _safeWriteNotifier(widget.sendEnabledNotifier, true);

      _safeSetState(() {
        _isTranslating = false;
        _translationFailed = false;
      });
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().replaceFirst('Exception: ', '');
      _translatedText = msg;
      _translatedController.text = msg;

      _safeSetState(() {
        _isTranslating = false;
        _translationFailed = true;
      });
    }
  }

  void _goToPage(int page) {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
    _safeSetState(() => _currentPage = page);
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  void _sendOriginal() {
    if (!mounted) return;
    final text = _sheetMsgController.text.trim();
    if (text.isEmpty) return;
    widget.messageController.text = text;
    widget.onSendPressed();
    Navigator.of(context).pop();
  }

  void _sendTranslated() {
    if (!mounted) return;
    if (_translatedText.trim().isEmpty || _isTranslating || _translationFailed) {
      return;
    }
    widget.messageController.text = _translatedText;
    widget.onSendPressed();
    Navigator.of(context).pop();
  }

  String _getLanguageName(String code) {
    final lang = _availableLanguages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => {'name': code},
    );
    return lang['name'] ?? code;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85 -
              MediaQuery.of(context).viewInsets.bottom,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF820AFF)],
              stops: [0.0, 0.8],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              _buildHeader(),
              if (widget.isChatPage) _buildTranslateRow(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: widget.loadingAINotifier,
                    builder: (_, isLoading, __) {
                      if (isLoading) return _loadingCard();

                      // FIX 2: build the list once per frame so its length
                      // is stable; PageController never sees a mismatch
                      final pages = [
                        _buildOriginalCard(),
                        if (widget.isChatPage && !_isAiError)
                          _buildTranslatedCard(),
                      ];

                      return Column(
                        children: [
                          // ── Pager dots ──────────────────────────────────
                          if (widget.isChatPage &&
                              _isResponseReady &&
                              _selectedLanguage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 250),
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(
                                          _currentPage == 0 ? 1.0 : 0.35),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 250),
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(
                                          _currentPage == 1 ? 1.0 : 0.35),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currentPage == 0
                                        ? 'Original'
                                        : 'Translated',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          // ── PageView ────────────────────────────────────
                          Expanded(
                            child: PageView(
                              controller: _pageController,
                              physics: pages.length > 1
                                  ? const BouncingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              onPageChanged: (p) =>
                                  _safeSetState(() => _currentPage = p),
                              children: pages,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: widget.loadingAINotifier,
                builder: (_, isLoading, __) {
                  final canEdit = !isLoading &&
                      _isResponseReady &&
                      !_isRegenerating &&
                      !_isAiError &&
                      _currentPage == 0;
                  return TextButton(
                    onPressed: canEdit
                        ? () => _safeSetState(() => _isEditing = !_isEditing)
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isEditing ? 'Done' : 'Edit',
                          style: TextStyle(
                            color: canEdit ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_isEditing && canEdit) ...[
                          const SizedBox(width: 3),
                          const Icon(Icons.check_circle,
                              color: Colors.white, size: 18),
                        ],
                      ],
                    ),
                  );
                },
              ),
              TextButton(
                onPressed: () {
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          RichText(
            text: const TextSpan(children: [
              WidgetSpan(
                child: FaIcon(FontAwesomeIcons.magicWandSparkles,
                    color: Colors.white, size: 16),
                alignment: PlaceholderAlignment.middle,
              ),
              WidgetSpan(child: SizedBox(width: 5)),
              TextSpan(
                text: 'MaxIA',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Translate row ─────────────────────────────────────────────────────────

  Widget _buildTranslateRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.translate, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text('Translate to',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedLanguage,
                hint: const Text('Select language…',
                    style:
                        TextStyle(fontSize: 13, color: Colors.black54)),
                isExpanded: true,
                isDense: true,
                dropdownColor: Colors.white,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down,
                    size: 20, color: Colors.black),
                style:
                    const TextStyle(fontSize: 13, color: Colors.black),
                onChanged:
                    (_isTranslating || !_isResponseReady || _isAiError)
                        ? null
                        : (String? v) {
                            if (v != null) _triggerTranslation(v);
                          },
                items: _availableLanguages
                    .map<DropdownMenuItem<String>>(
                      (lang) => DropdownMenuItem<String>(
                        value: lang['code'],
                        child: Text(
                          lang['name'] ?? lang['code'] ?? '',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          if (_isTranslating) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  // ── Cards ─────────────────────────────────────────────────────────────────

  Widget _loadingCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF6366F1), width: 3),
      ),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildLoadingShimmer(),
      ),
    );
  }

  Widget _buildOriginalCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF6366F1), width: 3),
      ),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [
                  Icon(Icons.check_circle_outline,
                      size: 13, color: Color(0xFF6366F1)),
                  SizedBox(width: 5),
                  Text('Original',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.w500)),
                ]),
                if (!_isRegenerating && !_isAiError)
                  TextButton.icon(
                    onPressed: _regenerate,
                    icon: const Icon(Icons.refresh,
                        size: 16, color: Color(0xFF6366F1)),
                    label: const Text('Regenerate',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF6366F1))),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const Divider(height: 16, thickness: 0.5),
            Expanded(
              child: _isRegenerating
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation(Color(0xFF6366F1)),
                        strokeWidth: 2,
                      ),
                    )
                  : SingleChildScrollView(
                      controller: _originalScrollController, // FIX 3
                      child: TextField(
                        controller: _sheetMsgController,
                        maxLines: null,
                        enabled: _isEditing && !_isAiError,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: _isAiError
                              ? 'Failed to generate response'
                              : 'AI response will appear here…',
                          hintStyle: TextStyle(
                              color:
                                  _isAiError ? Colors.red : Colors.grey,
                              fontSize: 14),
                        ),
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            height: 1.6),
                        onChanged: (text) {
                          if (!_isAiError) {
                            _originalResponse = text;
                            _safeWriteNotifier(widget.sendEnabledNotifier,
                                text.trim().isNotEmpty);
                          }
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            if (!_isAiError)
              //original text
              ValueListenableBuilder<bool>(
                valueListenable: widget.sendEnabledNotifier,
                builder: (_, canSend, __) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canSend && !_isRegenerating
                        ? _sendOriginal
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Send This',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslatedCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF820AFF), width: 3),
      ),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.translate,
                  size: 13, color: Color(0xFF820AFF)),
              const SizedBox(width: 5),
              Text(
                _selectedLanguage != null
                    ? 'Translated to ${_getLanguageName(_selectedLanguage!)}'
                    : 'Translated',
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF820AFF),
                    fontWeight: FontWeight.w500),
              ),
            ]),
            const Divider(height: 16, thickness: 0.5),
            Expanded(
              child: _isTranslating
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation(Color(0xFF820AFF)),
                        strokeWidth: 2,
                      ),
                    )
                  : _translationFailed
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red, size: 48),
                              const SizedBox(height: 12),
                              const Text(
                                  'Translation failed. Please try again.',
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  if (_selectedLanguage != null) {
                                    _triggerTranslation(_selectedLanguage!);
                                  }
                                },
                                child: const Text('Retry Translation',
                                    style: TextStyle(
                                        color: Color(0xFF820AFF),
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          controller: _translatedScrollController, // FIX 3
                          child: TextField(
                            controller: _translatedController,
                            maxLines: null,
                            enabled: false,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Translation will appear here…',
                              hintStyle: TextStyle(
                                  color: Colors.grey, fontSize: 14),
                            ),
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                height: 1.6),
                          ),
                        ),
            ),
            const SizedBox(height: 12),
            if (!_translationFailed)
            //Translated text
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (!_isTranslating &&
                          !_translationFailed &&
                          _translatedText.trim().isNotEmpty)
                      ? _sendTranslated
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF820AFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Send This',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Shimmer ───────────────────────────────────────────────────────────────

  Widget _buildLoadingShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(children: [
          _PulsingDots(),
          SizedBox(width: 10),
          Text(
            'Generating response…',
            style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w500),
          ),
        ]),
        const SizedBox(height: 20),
        ...[0.95, 1.0, 0.78, 1.0, 0.62, 0.88, 0.45].map(
          (w) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ShimmerLine(widthFactor: w),
          ),
        ),
      ],
    );
  }
}

// ── Shimmer line ──────────────────────────────────────────────────────────────

class _ShimmerLine extends StatefulWidget {
  final double widthFactor;
  const _ShimmerLine({required this.widthFactor});

  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  late final Animation<double> _anim = Tween<double>(begin: 0.25, end: 0.7)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => FractionallySizedBox(
          widthFactor: widget.widthFactor,
          alignment: Alignment.centerLeft,
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF6366F1).withOpacity(_anim.value),
            ),
          ),
        ),
      );
}

// ── Pulsing dots ──────────────────────────────────────────────────────────────

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _dot(double delay) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = (_ctrl.value - delay) % 1.0;
          final scale = t < 0.4
              ? 0.6 + (t / 0.4) * 0.4
              : t < 0.8
                  ? 1.0 - ((t - 0.4) / 0.4) * 0.4
                  : 0.6;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: Color(0xFF6366F1), shape: BoxShape.circle),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(0.0),
          const SizedBox(width: 4),
          _dot(0.2),
          const SizedBox(width: 4),
          _dot(0.4),
        ],
      );
}