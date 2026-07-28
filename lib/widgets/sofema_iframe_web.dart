import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// In-page Sofema embed for Flutter Web (HTML iframe).
class SofemaIFrame extends StatefulWidget {
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
  State<SofemaIFrame> createState() => _SofemaIFrameState();
}

class _SofemaIFrameState extends State<SofemaIFrame> {
  late final String _viewType;
  late final String _frameName;
  web.HTMLIFrameElement? _iframe;
  String? _lastBootKey;

  @override
  void initState() {
    super.initState();
    _viewType = 'sofema-iframe-${identityHashCode(this)}';
    _frameName = '${widget.frameName}_${identityHashCode(this)}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final wrapper = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.overflow = 'hidden'
        ..style.setProperty('pointer-events', 'auto');

      final iframe = web.HTMLIFrameElement()
        ..name = _frameName
        ..id = _frameName
        ..title = widget.title
        ..src = 'about:blank'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.setProperty('pointer-events', 'auto')
        ..style.setProperty('touch-action', 'auto')
        ..allow = 'fullscreen; clipboard-read; clipboard-write'
        ..referrerPolicy = 'no-referrer-when-downgrade'
        ..setAttribute('allowfullscreen', 'true')
        ..setAttribute('scrolling', 'yes');

      if (widget.url != null &&
          widget.url!.isNotEmpty &&
          widget.sessionBoot == null) {
        iframe.src = widget.url!;
      }

      wrapper.append(iframe);
      _iframe = iframe;
      return wrapper;
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

    final key =
        '$bootUrl|${fields.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    if (key == _lastBootKey) return;
    _lastBootKey = key;

    unawaited(_bootIntoIFrame(bootUrl, fields));
  }

  /// POST session boot **from inside** the iframe (about:blank).
  /// Never uses form[target], so the browser cannot open a new tab.
  Future<void> _bootIntoIFrame(
    String bootUrl,
    Map<String, String> fields,
  ) async {
    web.HTMLIFrameElement? iframe;
    for (var i = 0; i < 50; i++) {
      if (!mounted) return;
      final el = web.document.querySelector('iframe#$_frameName');
      if (el != null) {
        iframe = el as web.HTMLIFrameElement;
        break;
      }
      if (_iframe != null) {
        iframe = _iframe;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (iframe == null || !mounted) return;

    // Wait until about:blank is ready so contentDocument is writable.
    await _ensureBlankReady(iframe);
    if (!mounted) return;

    final doc = iframe.contentDocument;
    if (doc == null) {
      // Last resort: navigate with GET-less approach — still no new tab.
      // Build a data URL form is not viable; keep iframe blank.
      return;
    }

    final body = doc.body ?? doc.documentElement;
    if (body == null) return;

    final form = doc.createElement('form') as web.HTMLFormElement
      ..method = 'POST'
      ..action = bootUrl
      ..acceptCharset = 'UTF-8'
      ..style.display = 'none';
    // No [target] → navigates this iframe only.

    for (final entry in fields.entries) {
      final input = doc.createElement('input') as web.HTMLInputElement
        ..type = 'hidden'
        ..name = entry.key
        ..value = entry.value;
      form.append(input);
    }

    body.append(form);
    form.submit();
  }

  Future<void> _ensureBlankReady(web.HTMLIFrameElement iframe) async {
    if (iframe.contentDocument?.body != null) return;

    final ready = Completer<void>();

    iframe.onload = ((web.Event _) {
      if (!ready.isCompleted) ready.complete();
    }).toJS;

    iframe.src = 'about:blank';

    try {
      await ready.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      // Ignore timeout; contentDocument may still be usable.
    }

    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
