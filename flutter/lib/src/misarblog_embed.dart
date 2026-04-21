import "package:flutter/material.dart";
import "package:webview_flutter/webview_flutter.dart";
import "package:misarblog_sdk/misarblog.dart";

class MisarBlogEmbed extends StatelessWidget {
  final String username;
  final String? slug;
  final String theme;
  final double height;

  const MisarBlogEmbed({
    super.key,
    required this.username,
    this.slug,
    this.theme = "auto",
    this.height = 600.0,
  });

  @override
  Widget build(BuildContext context) {
    final url = embedUrl(username, slug: slug, theme: theme);
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));
    return SizedBox(height: height, child: WebViewWidget(controller: controller));
  }
}
