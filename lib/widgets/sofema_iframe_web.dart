import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// In-page Sofema embed for Flutter Web (HTML iframe).
///
/// Supports GET navigation via [url], or POST session boot via [sessionBoot].
class SofemaIFrame extends StatefulWidget {
  final String? url;
  final String title;
  final String frameName;

  /// When set, POSTs these fields to [sessionBootUrl] targeting this iframe
  /// (same pattern as portal.html autoLoginEmbed).
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
  State<SofemaIFrame> createState() => _SofemaIFrameState();
}

class _SofemaIFrameState extends State<SofemaIFrame> {
  late final String _viewType;
  web.HTMLIFrameElement? _iframe;
  String? _lastBootKey;

  @override
  void initState() {
    super.initState();
    _viewType = 'sofema-iframe-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..name = widget.frameName
        ..title = widget.title
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'fullscreen; clipboard-read; clipboard-write'
        ..referrerPolicy = 'no-referrer-when-downgrade'
        ..setAttribute('allowfullscreen', 'true');
      if (widget.url != null && widget.url!.isNotEmpty) {
        iframe.src = widget.url!;
      }
      _iframe = iframe;
      return iframe;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBootSession());
  }

  @override
  void didUpdateWidget(covariant SofemaIFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      _iframe?.title = widget.title;
    }
    if (widget.sessionBoot == null &&
        widget.url != null &&
        widget.url != oldWidget.url) {
      _iframe?.src = widget.url!;
    }
    _maybeBootSession();
  }

  void _maybeBootSession() {
    final bootUrl = widget.sessionBootUrl;
    final fields = widget.sessionBoot;
    if (bootUrl == null || fields == null || fields.isEmpty) return;

    final key = '$bootUrl|${fields.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    if (key == _lastBootKey) return;
    _lastBootKey = key;

    // Defer until iframe is in the DOM.
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      final form = web.HTMLFormElement()
        ..method = 'POST'
        ..action = bootUrl
        ..target = widget.frameName
        ..style.display = 'none';

      for (final entry in fields.entries) {
        final input = web.HTMLInputElement()
          ..name = entry.key
          ..value = entry.value;
        form.append(input);
      }

      web.document.body?.append(form);
      form.submit();
      form.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
