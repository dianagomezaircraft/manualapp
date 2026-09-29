import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Moodle embed for Flutter web.
///
/// [HtmlElementView] sits under the Flutter canvas, so clicks never reach
/// Moodle, and the factory often builds the iframe twice (burns the SSO key).
/// This widget appends **one** real iframe to `document.body`, positions it
/// over the placeholder, and assigns [url] a single time.
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

class _MoodleIFrameState extends State<MoodleIFrame>
    with WidgetsBindingObserver {
  final _anchorKey = GlobalKey();
  web.HTMLIFrameElement? _iframe;
  var _srcAssigned = false;
  var _blockedReported = false;
  web.EventListener? _cspListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForCsp();
    _iframe = _createIframe();
    web.document.body?.append(_iframe!);
  }

  web.HTMLIFrameElement _createIframe() {
    final iframe = web.HTMLIFrameElement()
      ..id = 'moodle-sso-frame'
      ..title = widget.title
      ..src = 'about:blank'
      ..allow = 'fullscreen; clipboard-read; clipboard-write'
      ..referrerPolicy = 'no-referrer-when-downgrade'
      ..setAttribute('allowfullscreen', 'true')
      ..setAttribute('scrolling', 'yes');

    iframe.style
      ..setProperty('position', 'fixed')
      ..setProperty('border', 'none')
      ..setProperty('margin', '0')
      ..setProperty('padding', '0')
      ..setProperty('z-index', '100000')
      ..setProperty('pointer-events', 'auto')
      ..setProperty('touch-action', 'auto')
      ..setProperty('background', '#ffffff')
      ..setProperty('display', 'none');

    iframe.onload = ((web.Event _) {
      _detectChromeErrorPage(iframe);
    }).toJS;

    return iframe;
  }

  @override
  void didChangeMetrics() {
    _syncFrame();
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

  void _syncFrame() {
    final iframe = _iframe;
    if (!mounted || iframe == null) return;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      iframe.style.setProperty('display', 'none');
      return;
    }

    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      iframe.style.setProperty('display', 'none');
      return;
    }

    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    if (size.width <= 1 || size.height <= 1) {
      iframe.style.setProperty('display', 'none');
      return;
    }

    iframe.style
      ..setProperty('display', 'block')
      ..setProperty('left', '${offset.dx}px')
      ..setProperty('top', '${offset.dy}px')
      ..setProperty('width', '${size.width}px')
      ..setProperty('height', '${size.height}px');

    if (!_srcAssigned && widget.url.isNotEmpty) {
      _srcAssigned = true;
      iframe.src = widget.url;
    }
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final listener = _cspListener;
    if (listener != null) {
      web.document.removeEventListener('securitypolicyviolation', listener);
    }
    _iframe?.remove();
    _iframe = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFrame());
    return SizedBox.expand(key: _anchorKey);
  }
}
