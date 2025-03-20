import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewExample extends StatefulWidget {
  final String htmlContent; // Accepts HTML content as a string

  WebViewExample({required this.htmlContent});

  @override
  _WebViewExampleState createState() => _WebViewExampleState();
}

class _WebViewExampleState extends State<WebViewExample> {
  late WebViewController _controller;
  bool _isLoading = true;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _progress = 0;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _progress = 100;
            });
          },
          onProgress: (int progress) {
            setState(() {
              _progress = progress;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(widget.htmlContent); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Stack(
        children: [
          WebViewWidget(
           controller: _controller,
          ),
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _progress / 100,
                  ),
                  SizedBox(height: 20),
                  Text("Loading $_progress%"),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ExpandedWebView extends StatefulWidget {
  final String htmlContent;

  const ExpandedWebView({Key? key, required this.htmlContent}) : super(key: key);

  @override
  _ExpandedWebViewState createState() => _ExpandedWebViewState();
}

class _ExpandedWebViewState extends State<ExpandedWebView> {
  late WebViewController _controller;
  bool _isLoading = true;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _progress = 0;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _progress = 100;
            });
          },
          onProgress: (int progress) {
            setState(() {
              _progress = progress;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(widget.htmlContent);
  }
  Future<void> _clearCacheAndStorage() async {
    await _controller.runJavaScript('window.localStorage.clear();');
    await _controller.runJavaScript('window.sessionStorage.clear();');
    _controller.reload();
  }

  void _reloadWebView() {
    _clearCacheAndStorage();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading:IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), 
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _reloadWebView,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _progress / 100,
                  ),
                  SizedBox(height: 20),
                  Text("Loading $_progress%"),
                ],
              ),
            ),
        ],
      ),
    );
  }
}