import 'package:flutter/material.dart';

import '../data/reader_data.dart';

/// Presentation only: never inserted into canonical verse or translation records.
class SurahOpening extends StatelessWidget {
  const SurahOpening({
    super.key,
    required this.start,
    required this.data,
    required this.showArabic,
  });
  final QuranVerse start;
  final ReaderData data;
  final bool showArabic;

  @override
  Widget build(BuildContext context) {
    if (start.ayah != 1) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final copper = theme.brightness == Brightness.dark
        ? const Color(0xffffb46e)
        : const Color(0xff934515);
    final title = data.arabicTitles[start.surah];
    return Padding(
      key: Key('surah-opening-${start.surah}'),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomPaint(
            painter: _OpeningBorder(theme.colorScheme.onSurfaceVariant),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  if (title != null)
                    Text(
                      'سُورَةُ $title',
                      key: Key('opening-arabic-title-${start.surah}'),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'DiyanetAmasya',
                        fontSize: 32,
                        height: 1.8,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  Text(
                    '${data.names[start.surah]} Süresi • ${data.openingMetadata[start.surah]!}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'NotoSerif',
                      fontSize: 16,
                      height: 1.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showArabic && start.surah != 1 && start.surah != 9)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                data.pages
                    .expand((p) => p.verses)
                    .firstWhere((v) => v.surah == 1 && v.ayah == 1)
                    .text,
                key: Key('opening-basmala-${start.surah}'),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'DiyanetAmasya',
                  fontSize: 30,
                  height: 1.9,
                  color: copper,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Thin double scalloped outline and four native-vector diamond ornaments.
class _OpeningBorder extends CustomPainter {
  const _OpeningBorder(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75;
    for (final inset in [5.0, 9.0]) {
      final r = Rect.fromLTRB(
        inset,
        inset,
        size.width - inset,
        size.height - inset,
      );
      const c = 9.0;
      final path = Path()
        ..moveTo(r.left + c, r.top)
        ..lineTo(r.right - c, r.top)
        ..quadraticBezierTo(r.right - c, r.top + c, r.right, r.top + c)
        ..lineTo(r.right, r.bottom - c)
        ..quadraticBezierTo(r.right - c, r.bottom - c, r.right - c, r.bottom)
        ..lineTo(r.left + c, r.bottom)
        ..quadraticBezierTo(r.left + c, r.bottom - c, r.left, r.bottom - c)
        ..lineTo(r.left, r.top + c)
        ..quadraticBezierTo(r.left + c, r.top + c, r.left + c, r.top)
        ..close();
      canvas.drawPath(path, pen);
    }
    for (final x in [5.0, size.width - 5]) {
      for (final y in [5.0, size.height - 5]) {
        canvas.drawPath(
          Path()
            ..moveTo(x, y - 3)
            ..lineTo(x + 3, y)
            ..lineTo(x, y + 3)
            ..lineTo(x - 3, y)
            ..close(),
          pen,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_OpeningBorder oldDelegate) => oldDelegate.color != color;
}
