import 'package:flutter/widgets.dart';

/// Non-web stub — mobile uses [WebViewWidget] instead.
class MoodleIFrame extends StatelessWidget {
  final String url;
  final String title;
  final VoidCallback? onBlocked;

  const MoodleIFrame({
    super.key,
    required this.url,
    this.title = 'Moodle',
    this.onBlocked,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
