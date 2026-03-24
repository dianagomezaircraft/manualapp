import 'package:arts_claims_app/screens/coming_soon_features.dart';
import 'package:arts_claims_app/screens/comming_soon_screen.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/auth_service.dart';
import '../services/chapters_service.dart';
import '../services/airline_service.dart';
import '../models/airline.dart';
import '../widgets/app_bottom_navigation.dart';

import 'search_screen.dart';
import 'chapter_detail_screen.dart';
import 'contact_details_screen.dart';
import 'login_screen.dart';
import 'section_detail_screen.dart';
import '../services/content_service.dart' as cs;

class CategoryScreen extends StatefulWidget {
  final String userName;

  const CategoryScreen({
    super.key,
    this.userName = 'User',
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  int selectedRating = 0;
  int selectedBottomIndex = 2;

  final AuthService _authService = AuthService();
  final ChaptersService _chaptersService = ChaptersService();
  final AirlineService _airlineService = AirlineService();

  List<Chapter> chapters = [];
  List<Airline> airlines = [];
  bool isLoading = true;
  bool isLoadingAirlines = false;
  bool isGeneratingPdf = false;
  String? errorMessage;
  String userName = 'User';
  bool isSuperAdmin = false;
  String? selectedAirlineId;
  String? userAirlineId;

  // ─────────────────────────────────────────────────────────────────────────
  // HTML → PDF widget converter
  // ─────────────────────────────────────────────────────────────────────────

  List<pw.Widget> _htmlToPdfWidgets(
    String html, {
    required pw.Font ttf,
    required pw.Font ttfBold,
    required pw.Font ttfItalic,
  }) {
    final List<pw.Widget> widgets = [];

    String cleaned = html
        .replaceAll(RegExp(r'\r\n|\r'), '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('{{CONTACT_BUTTON}}', '[See Contacts]');

    final RegExp blockReg = RegExp(
      r'<(h1|h2|h3|h4|p|ul|ol|br\s*/?)(\s[^>]*)?>.*?<\/\1>|<br\s*/?>',
      caseSensitive: false,
      dotAll: true,
    );

    int cursor = 0;

    for (final match in blockReg.allMatches(cleaned)) {
      if (match.start > cursor) {
        final raw = cleaned.substring(cursor, match.start).trim();
        if (raw.isNotEmpty) {
          widgets.add(_pdfRichText(
            _inlineSpans(raw, ttf: ttf, ttfBold: ttfBold, ttfItalic: ttfItalic),
            ttf: ttf,
          ));
          widgets.add(pw.SizedBox(height: 4));
        }
      }

      final full = match.group(0)!;
      final tag = match.group(1)?.toLowerCase() ?? '';

      if (tag == 'h1' || tag == 'h2') {
        final text = _stripInlineTags(full);
        widgets.add(pw.Text(
          text,
          style: pw.TextStyle(
            font: ttfBold,
            fontSize: tag == 'h1' ? 15 : 13,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF123157),
          ),
        ));
        widgets.add(pw.SizedBox(height: 6));
      } else if (tag == 'h3' || tag == 'h4') {
        final text = _stripInlineTags(full);
        widgets.add(pw.Text(
          text,
          style: pw.TextStyle(
            font: ttfBold,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF1e518f),
          ),
        ));
        widgets.add(pw.SizedBox(height: 4));
      } else if (tag == 'p') {
        final inner = _extractInner(full, 'p');
        if (inner.trim().isNotEmpty) {
          widgets.add(_pdfRichText(
            _inlineSpans(inner,
                ttf: ttf, ttfBold: ttfBold, ttfItalic: ttfItalic),
            ttf: ttf,
          ));
          widgets.add(pw.SizedBox(height: 6));
        }
      } else if (tag == 'ul' || tag == 'ol') {
        final items = _extractListItems(full);
        for (int i = 0; i < items.length; i++) {
          final bullet = tag == 'ol' ? '${i + 1}.' : '-';
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 16,
                    child: pw.Text(
                      bullet,
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF123157),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: _pdfRichText(
                      _inlineSpans(
                        items[i],
                        ttf: ttf,
                        ttfBold: ttfBold,
                        ttfItalic: ttfItalic,
                      ),
                      ttf: ttf,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        widgets.add(pw.SizedBox(height: 6));
      } else if (full.toLowerCase().startsWith('<br')) {
        widgets.add(pw.SizedBox(height: 4));
      }

      cursor = match.end;
    }

    if (cursor < cleaned.length) {
      final raw = cleaned.substring(cursor).trim();
      if (raw.isNotEmpty) {
        widgets.add(_pdfRichText(
          _inlineSpans(raw, ttf: ttf, ttfBold: ttfBold, ttfItalic: ttfItalic),
          ttf: ttf,
        ));
      }
    }

    return widgets.isEmpty
        ? [
            pw.Text(
              _stripInlineTags(cleaned).trim(),
              style: pw.TextStyle(font: ttf, fontSize: 11, lineSpacing: 3),
            )
          ]
        : widgets;
  }

  pw.Widget _pdfRichText(
    List<pw.TextSpan> spans, {
    required pw.Font ttf,
  }) {
    return pw.RichText(
      text: pw.TextSpan(
        style: pw.TextStyle(
          font: ttf,
          fontSize: 11,
          color: PdfColors.grey800,
          lineSpacing: 3,
        ),
        children: spans,
      ),
    );
  }

  List<pw.TextSpan> _inlineSpans(
    String html, {
    required pw.Font ttf,
    required pw.Font ttfBold,
    required pw.Font ttfItalic,
  }) {
    final List<pw.TextSpan> spans = [];
    final RegExp inlineReg = RegExp(
      r'<(strong|b|em|i|span)(\s[^>]*)?>.*?<\/\1>',
      caseSensitive: false,
      dotAll: true,
    );

    int cursor = 0;
    for (final match in inlineReg.allMatches(html)) {
      if (match.start > cursor) {
        final plain = _stripInlineTags(html.substring(cursor, match.start));
        if (plain.isNotEmpty) {
          spans.add(pw.TextSpan(
            text: plain,
            style: pw.TextStyle(font: ttf),
          ));
        }
      }

      final tag = match.group(1)!.toLowerCase();
      final inner = _stripInlineTags(match.group(0)!);

      if (tag == 'strong' || tag == 'b') {
        spans.add(pw.TextSpan(
          text: inner,
          style: pw.TextStyle(
            font: ttfBold,
            fontWeight: pw.FontWeight.bold,
          ),
        ));
      } else if (tag == 'em' || tag == 'i') {
        spans.add(pw.TextSpan(
          text: inner,
          style: pw.TextStyle(
            font: ttfItalic,
            fontStyle: pw.FontStyle.italic,
          ),
        ));
      } else {
        spans.add(pw.TextSpan(
          text: inner,
          style: pw.TextStyle(font: ttf),
        ));
      }

      cursor = match.end;
    }

    if (cursor < html.length) {
      final plain = _stripInlineTags(html.substring(cursor));
      if (plain.isNotEmpty) {
        spans.add(pw.TextSpan(
          text: plain,
          style: pw.TextStyle(font: ttf),
        ));
      }
    }

    return spans.isEmpty
        ? [
            pw.TextSpan(
              text: _stripInlineTags(html),
              style: pw.TextStyle(font: ttf),
            )
          ]
        : spans;
  }

  String _extractInner(String html, String tag) {
    final reg = RegExp(
      '<$tag(\\s[^>]*)?>((.|\\n)*?)<\\/$tag>',
      caseSensitive: false,
      dotAll: true,
    );
    final m = reg.firstMatch(html);
    return m?.group(2) ?? html;
  }

  List<String> _extractListItems(String html) {
    final reg = RegExp(
      r'<li(\s[^>]*)?>((.|\\n)*?)<\/li>',
      caseSensitive: false,
      dotAll: true,
    );
    return reg.allMatches(html).map((m) => m.group(2) ?? '').toList();
  }

  String _stripInlineTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PDF generation
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _generateAndDownloadPdf() async {
    if (chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No chapters available to export.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isGeneratingPdf = true);

    try {
      // ── Load Unicode fonts ─────────────────────────────────────────────
      final ttf = await PdfGoogleFonts.robotoRegular();
      final ttfBold = await PdfGoogleFonts.robotoBold();
      final ttfItalic = await PdfGoogleFonts.robotoItalic();

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: ttfBold,
          italic: ttfItalic,
        ),
      );

      // ── 1. Load full chapter details ───────────────────────────────────
      final List<Chapter> fullChapters = [];

      for (final chapter in chapters) {
        final result = await _chaptersService.getChapterById(chapter.id);
        if (result['success'] == true) {
          fullChapters.add(Chapter.fromJson(result['data']));
        } else {
          fullChapters.add(chapter);
        }
      }

      // ── 2. Load content for every section ─────────────────────────────
      final Map<String, List<cs.Content>> sectionContents = {};

      for (final chapter in fullChapters) {
        if (chapter.sections == null) continue;
        for (final section in chapter.sections!) {
          final contentService = cs.ContentService();
          final result =
              await contentService.getContentsBySectionId(section.id);
          if (result['success'] == true) {
            final items = (result['data'] as List<dynamic>)
                .map((j) => cs.Content.fromJson(j as Map<String, dynamic>))
                .toList()
              ..sort((a, b) => a.order.compareTo(b.order));
            sectionContents[section.id] = items;
          }
        }
      }

      // ── 3. Cover page ──────────────────────────────────────────────────
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(32),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFF123157),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ARTS Claims Manual',
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Loss Prevention & Claims Reference',
                      style: pw.TextStyle(
                        font: ttf,
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 32),
              pw.Text(
                'Contents',
                style: pw.TextStyle(
                  font: ttfBold,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF123157),
                ),
              ),
              pw.SizedBox(height: 12),
              ...fullChapters.map(
                (chapter) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        'Chapter ${chapter.order - 1}',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Text(
                          chapter.title,
                          style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Text(
                        '${chapter.sectionsCount} section${chapter.sectionsCount != 1 ? 's' : ''}',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 10,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // ── 4. One MultiPage per chapter ───────────────────────────────────
      for (final chapter in fullChapters) {
        final sections = chapter.sections ?? [];

        pdf.addPage(
          pw.MultiPage(
            maxPages: 9999,
            pageFormat: PdfPageFormat.a4,
            header: (pw.Context ctx) => pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColor.fromInt(0xFF123157),
                    width: 1,
                  ),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ARTS Claims Manual',
                      style: pw.TextStyle(
                          font: ttf, fontSize: 10, color: PdfColors.grey600)),
                  pw.Text('Chapter ${chapter.order - 1}',
                      style: pw.TextStyle(
                          font: ttf, fontSize: 10, color: PdfColors.grey600)),
                ],
              ),
            ),
            footer: (pw.Context ctx) => pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Page ${ctx.pageNumber}',
                  style: pw.TextStyle(
                      font: ttf, fontSize: 9, color: PdfColors.grey500)),
            ),
            build: (pw.Context ctx) {
              // ── Build a FLAT list — MultiPage cannot paginate nested Columns ──
              final List<pw.Widget> items = [];

              // Chapter title block
              items.add(
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFEEEFF0),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CHAPTER ${chapter.order - 1}',
                          style: pw.TextStyle(
                              font: ttf,
                              fontSize: 10,
                              color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(chapter.title,
                          style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF123157))),
                    ],
                  ),
                ),
              );
              items.add(pw.SizedBox(height: 12));

              // Chapter description
              if (chapter.description.isNotEmpty &&
                  chapter.description != 'Coming soon') {
                items.add(pw.Text(
                  chapter.description,
                  style: pw.TextStyle(
                      font: ttf,
                      fontSize: 12,
                      color: PdfColors.grey800,
                      lineSpacing: 4),
                ));
                items.add(pw.SizedBox(height: 16));
              }

              // No sections
              if (sections.isEmpty) {
                items.add(pw.Text('No sections available.',
                    style: pw.TextStyle(
                        font: ttf, fontSize: 11, color: PdfColors.grey600)));
              }

              // Sections — each widget added individually to the flat list
              for (final section in sections) {
                final contents = sectionContents[section.id] ?? [];

                items.add(pw.SizedBox(height: 16));

                // Section header
                items.add(
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFF123157),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(section.title,
                        style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white)),
                  ),
                );

                // Section description
                if (section.description != null &&
                    section.description!.isNotEmpty &&
                    section.description!.toLowerCase() != 'coming soon') {
                  items.add(pw.SizedBox(height: 6));
                  items.add(pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 4),
                    child: pw.Text(section.description!,
                        style: pw.TextStyle(
                            font: ttf,
                            fontSize: 11,
                            color: PdfColors.grey700,
                            lineSpacing: 3)),
                  ));
                }

                items.add(pw.SizedBox(height: 8));

                // No content
                if (contents.isEmpty) {
                  items.add(pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 4, bottom: 8),
                    child: pw.Text('No content available.',
                        style: pw.TextStyle(
                            font: ttf, fontSize: 10, color: PdfColors.grey500)),
                  ));
                }

                // Content blocks — each one added individually
                for (final content in contents) {
                  final htmlWidgets = _htmlToPdfWidgets(
                    content.content,
                    ttf: ttf,
                    ttfBold: ttfBold,
                    ttfItalic: ttfItalic,
                  );

                  if (content.title.isNotEmpty) {
                    items.add(pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
                      child: pw.Text(content.title,
                          style: pw.TextStyle(
                              font: ttfBold,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF1e518f))),
                    ));
                  }

                  // Each HTML widget added directly — avoids wrapping in a Column
                  for (final w in htmlWidgets) {
                    items.add(w);
                  }

                  items.add(pw.SizedBox(height: 12));
                }
              }

              return items;
            },
          ),
        );
      }

      // ── 5. Print / save ────────────────────────────────────────────────
      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'ARTS_Claims_Manual.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isGeneratingPdf = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle & data loading
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _checkUserRole();
    if (isSuperAdmin) await _loadAirlines();
    await _loadChapters();
  }

  Future<void> _checkUserRole() async {
    final userData = await _authService.getUserData();
    if (userData != null) {
      setState(() {
        isSuperAdmin = userData['role'] == 'SUPER_ADMIN';
        if (!isSuperAdmin) userAirlineId = userData['airlineId'];
      });
    }
  }

  Future<void> _loadAirlines() async {
    setState(() => isLoadingAirlines = true);
    try {
      final token = await _authService.getAccessToken();
      if (token == null) throw Exception('No access token available');
      final airlinesData = await _airlineService.getAllAirlines(token: token);
      if (mounted) {
        setState(() {
          airlines = airlinesData;
          isLoadingAirlines = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingAirlines = false);
      print('Error loading airlines: $e');
    }
  }

  Future<void> _loadUserName() async {
    final name = await _authService.getUserName();
    if (mounted) setState(() => userName = name);
  }

  Future<void> _loadChapters() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final userData = await _authService.getUserData();
      if (userData == null) throw Exception('User not authenticated');
      final userRole = userData['role'];
      String? airlineId;
      if (userRole == 'SUPER_ADMIN') {
        airlineId = selectedAirlineId;
      } else {
        airlineId = userData['airlineId'];
        if (airlineId == null || airlineId.isEmpty) {
          throw Exception('User has no airline assigned');
        }
      }
      final result = await _chaptersService.getChapters(airlineId: airlineId);
      if (!mounted) return;
      if (result['success'] == true) {
        final chaptersData = result['data'] as List<dynamic>;
        setState(() {
          chapters = chaptersData.map((json) => Chapter.fromJson(json)).toList()
            ..sort((a, b) => a.order.compareTo(b.order));
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = result['error'] ?? 'Failed to load chapters';
          isLoading = false;
        });
        if (result['needsLogin'] == true) _handleLogout();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
      if (e.toString().contains('not authenticated')) _handleLogout();
    }
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _handleChapterTap(String chapterId, String title,
      String? description, String chapterNumber) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF123157))),
    );
    try {
      final result = await _chaptersService.getChapterById(chapterId);
      if (!mounted) return;
      Navigator.pop(context);
      if (result['success'] == true) {
        final chapterData = Chapter.fromJson(result['data']);
        if (chapterData.sections != null &&
            chapterData.sections!.isNotEmpty &&
            chapterData.sections!.length == 1) {
          final section = chapterData.sections!.first;
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => SectionDetailScreen(
                      sectionId: section.id,
                      title: section.title,
                      description: section.description,
                      chapterTitle: chapterData.title)));
        } else if (chapterData.sections!.isEmpty) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => chapterData.title == 'Notification of a Loss'
                      ? const ComingSoonScreen()
                      : const ComingSoonFeatures()));
        } else {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ChapterDetailScreen(
                      chapterTitle: title,
                      chapterNumber: chapterNumber,
                      chapterId: chapterId)));
        }
      } else {
        if (result['needsLogin'] == true) {
          _handleLogout();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result['error'] ?? 'Error loading chapter'),
              backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red));
    }
  }

  void _navigateToSearch(String searchTerm) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SearchScreen(initialSearchTerm: searchTerm)));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background_1.png'),
            alignment: Alignment.topCenter,
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 20.0),
                child: Column(
                  children: [
                    // Greeting row with PDF button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Hi $userName!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Tooltip(
                          message: 'Download manual as PDF',
                          child: Material(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: isGeneratingPdf || isLoading
                                  ? null
                                  : _generateAndDownloadPdf,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: isGeneratingPdf
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.picture_as_pdf_outlined,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      'Access the loss prevention measures and the key steps and contacts you would need in the event of a  loss.',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Inter',
                          height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    if (isSuperAdmin && !isLoadingAirlines)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedAirlineId,
                            hint: const Row(children: [
                              Icon(Icons.filter_list,
                                  size: 18, color: Color(0xFF123157)),
                              SizedBox(width: 8),
                              Text('All Airlines',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Inter',
                                      color: Color(0xFF123157),
                                      fontWeight: FontWeight.w600))
                            ]),
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Color(0xFF123157)),
                            style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'Inter',
                                color: Color(0xFF123157)),
                            items: [
                              const DropdownMenuItem<String>(
                                  value: null,
                                  child: Row(children: [
                                    Icon(Icons.flight,
                                        size: 18, color: Color(0xFF123157)),
                                    SizedBox(width: 8),
                                    Text('All Airlines',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF123157)))
                                  ])),
                              ...airlines
                                  .map((airline) => DropdownMenuItem<String>(
                                        value: airline.id,
                                        child: Row(children: [
                                          const Icon(Icons.flight,
                                              size: 18,
                                              color: Color(0xFF123157)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(
                                                  '${airline.name} (${airline.code})',
                                                  style: const TextStyle(
                                                      color: Color(0xFF123157)),
                                                  overflow:
                                                      TextOverflow.ellipsis))
                                        ]),
                                      )),
                            ],
                            onChanged: (String? newValue) {
                              setState(() => selectedAirlineId = newValue);
                              _loadChapters();
                            },
                          ),
                        ),
                      ),

                    if (isSuperAdmin && isLoadingAirlines)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF123157))),
                              SizedBox(width: 12),
                              Text('Loading airlines...',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Inter',
                                      color: Color(0xFF123157)))
                            ]),
                      ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStarRating(1, 'Incident'),
                            _buildStarRating(1, 'Major Loss'),
                            _buildStarRating(1, 'Injuries'),
                            _buildStarRating(1, 'Liability'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFeeeff0),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 29),
                      Expanded(child: _buildChaptersList()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 0),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI helpers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildChaptersList() {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF123157)));
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontFamily: 'Inter')),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadChapters,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF123157),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12)),
              ),
            ],
          ),
        ),
      );
    }

    if (chapters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                isSuperAdmin && selectedAirlineId != null
                    ? 'No chapters available for selected airline'
                    : 'No chapters available',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16, color: Colors.grey[600], fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChapters,
      color: const Color(0xFF123157),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: chapters.length,
        itemBuilder: (context, index) {
          final chapter = chapters[index];
          return _buildCategoryCard(
              chapter.title,
              'CHAPTER ${chapter.order - 1}',
              chapter.description,
              chapter.imageUrl,
              chapter.id,
              index);
        },
      ),
    );
  }

  Widget _buildStarRating(int stars, String label) {
    final isSelected = selectedRating == stars;
    return GestureDetector(
      onTap: () {
        _navigateToSearch(label);
        setState(() => selectedRating = stars);
      },
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
                stars,
                (_) => Icon(isSelected ? Icons.star : Icons.star_border,
                    color: isSelected ? const Color(0xFFAD8042) : Colors.grey,
                    size: 30)),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontFamily: 'Inter',
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, String chapterNumber,
      String? description, String? imageUrl, String chapterId, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () =>
              _handleChapterTap(chapterId, title, description, chapterNumber),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                              color: Colors.black87)),
                      const SizedBox(height: 8),
                      Text(
                        description != null && description != 'Coming soon'
                            ? chapterNumber
                            : description ?? chapterNumber,
                        style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Inter',
                            color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.transparent),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                              child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                  color: const Color(0xFF123157)));
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.transparent, size: 32)),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200]),
                    child: Icon(Icons.book, color: Colors.grey[400], size: 40),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
