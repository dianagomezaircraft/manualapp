import 'package:flutter/widgets.dart';

/// Non-web stub — mobile uses [WebViewWidget] instead.
class SofemaIFrame extends StatelessWidget {
  final String? url;
  final String title;
  final String frameName;
  final String? sessionBootUrl;
  final Map<String, String>? sessionBoot;

  const SofemaIFrame({
    super.key,
    this.url,
    this.title = 'Sofema',
    this.frameName = 'portalFrame',
    this.sessionBootUrl,
    this.sessionBoot,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
