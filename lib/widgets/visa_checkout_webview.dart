import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VisaCheckoutWebView extends StatefulWidget {
  final String checkoutUrl;
  final VoidCallback onSuccess;

  const VisaCheckoutWebView({
    super.key,
    required this.checkoutUrl,
    required this.onSuccess,
  });

  @override
  State<VisaCheckoutWebView> createState() => _VisaCheckoutWebViewState();
}

class _VisaCheckoutWebViewState extends State<VisaCheckoutWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url.toLowerCase();
            if (url.contains('status=completed') || url.contains('payments/return/')) {
              Navigator.pop(context);
              widget.onSuccess();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PayChangu Visa Payment")),
      body: WebViewWidget(controller: _controller),
    );
  }
}