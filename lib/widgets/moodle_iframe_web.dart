import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// In-page Moodle embed. Sets [url] on the iframe exactly once so the
/// one-time auth_userkey is not consumed by a second load.
class MoodleIFrame extends StatefulWidget {
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
  State<MoodleIFrame> createState() => _MoodleIFrameState();
}

class _MoodleIFrameState extends State<MoodleIFrame> {
  late final String _viewType;
  web.HTMLIFrameElement? _iframe;
  var _srcAssigned = false;
  var _blockedReported = false;
  web.EventListener? _cspListener;

  @override
  void initState() {
    super.initState();
    _viewType = 'moodle-iframe-${identityHashCode(this)}';
    _listenForCsp();

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final wrapper = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.overflow = 'hidden'
        ..style.setProperty('pointer-events', 'auto');

      final iframe = web.HTMLIFrameElement()
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

      iframe.onload = ((web.Event _) {
        _detectChromeErrorPage(iframe);
      }).toJS;

      wrapper.append(iframe);
      _iframe = iframe;
      return wrapper;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_assignSrcOnce());
    });
  }

  void _listenForCsp() {
    _cspListener = ((web.Event event) {
      final violation = event as web.SecurityPolicyViolationEvent;
      final directive = violation.effectiveDirective.toLowerCase();
      if (directive.contains('frame')) {
        _reportBlocked();
      }
    }).toJS;
    web.document.addEventListener('securitypolicyviolation', _cspListener!);
  }

  void _detectChromeErrorPage(web.HTMLIFrameElement iframe) {
    if (_blockedReported || !mounted) return;
    try {
      final href = iframe.contentWindow?.location.href ?? '';
      if (href.startsWith('chrome-error') || href.startsWith('chrome://')) {
        _reportBlocked();
      }
    } catch (_) {
      // Cross-origin Moodle document — the embed succeeded.
    }
  }

  void _reportBlocked() {
    if (_blockedReported) return;
    _blockedReported = true;
    widget.onBlocked?.call();
  }

  Future<void> _assignSrcOnce() async {
    if (_srcAssigned) return;

    for (var i = 0; i < 50; i++) {
      if (!mounted || _srcAssigned) return;
      if (_iframe != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    if (_srcAssigned || !mounted) return;
    final iframe = _iframe;
    if (iframe == null || widget.url.isEmpty) return;

    _srcAssigned = true;
    iframe.src = widget.url;
  }

  @override
  void dispose() {
    final listener = _cspListener;
    if (listener != null) {
      web.document.removeEventListener('securitypolicyviolation', listener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
