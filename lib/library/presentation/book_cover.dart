import 'package:flutter/material.dart';

import '../domain/book.dart';

/// Owner-approved artwork, retouched for Türkmen lettering and bundled offline.
/// This is an application illustration, not an official publisher's book cover.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book});
  final LibraryBook book;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    // The adjacent accessible book title and open action label this artwork.
    child: SizedBox(
      width: 216,
      child: AspectRatio(
        // Preserve the complete reference: no stretched medallion/cropped border.
        aspectRatio: 1696 / 2528,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xff10392f),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .22),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              'assets/images/kurany-kerim-cover.jpg',
              key: const Key('mushaf-cover-artwork'),
              semanticLabel: 'KURANY KERIM — TÜRKMENÇE MANY TERJIMESI',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    ),
  );
}
