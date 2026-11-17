import 'package:flutter/material.dart';

import '../domain/book.dart';
import 'book_cover.dart';

export 'book_cover.dart' show BookCover;

class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    required this.dark,
    required this.toggleTheme,
    required this.openBook,
    this.books = libraryBooks,
  });
  final List<LibraryBook> books;
  final bool dark;
  final VoidCallback toggleTheme;
  final ValueChanged<LibraryBook> openBook;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_stories_outlined,
                        color: colors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Kitaphana',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.6,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: dark ? 'Ýagty görnüş' : 'Garaňky görnüş',
                        onPressed: toggleTheme,
                        icon: Icon(
                          dark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: colors.outlineVariant),
                  const SizedBox(height: 16),
                  const Text(
                    'Okamaga hoş geldiňiz.',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kitaby saýlaň we okamaga başlaň.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final book in books)
                    Material(
                      color: dark
                          ? const Color(0xff1b302b)
                          : const Color(0xfffffdf7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: Key('book-${book.id}'),
                        onTap: () => openBook(book),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cover = SizedBox(
                                width: constraints.maxWidth < 300 ? 104 : 128,
                                child: BookCover(book: book),
                              );
                              final details = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    book.title,
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    book.subtitle,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),

                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: () => openBook(book),
                                    icon: const Icon(
                                      Icons.arrow_forward,
                                      size: 17,
                                    ),
                                    label: const Text('Okap başla'),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      backgroundColor: dark
                                          ? const Color(0xffb7d7c8)
                                          : const Color(0xff174e40),
                                      foregroundColor: dark
                                          ? const Color(0xff12382e)
                                          : const Color(0xfffff8e6),
                                    ),
                                  ),
                                ],
                              );
                              // Keep a compact side-by-side card on phones.
                              // Large accessibility text falls back to a scrollable
                              // stacked card rather than being shrunk or clipped.
                              if (constraints.maxWidth < 220 ||
                                  MediaQuery.textScalerOf(context).scale(14) >
                                      20) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(child: cover),
                                    const SizedBox(height: 16),
                                    details,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  cover,
                                  const SizedBox(width: 16),
                                  Expanded(child: details),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const Key('source-about'),
                    icon: const Icon(Icons.info_outline, size: 18),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    label: const Text('Çeşmeler we programma barada'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Kuran Kitaphanasy'),
                        content: const SingleChildScrollView(
                          child: Text(
                            'Arapça tekst we süre maglumatlary: Türkiýe Diyanet Işleri Baş müdirliginiň açyk Kuran çeşmesi (kuran.diyanet.gov.tr, textGroup 4).\n\n'
                            'Türkmençe many terjimesi, süre atlary, girişler we düşündirişler: Türkmenistanyň Müftüsiniň müdiriýeti tarapyndan taýýarlanan «Kurany Kerim» neşiri (PDF). Çeşmedäki toparlanan aýatlar saklanýar.\n\n'
                            'Tekstler we şriftler enjamda saklanýar; okamak üçin internet gerek däl. Hasap, mahabat ýa-da analitika ýok. Okalyş ýagdaýy diňe şu enjamda saklanýar.\n\n'
                            'Ses çeşmesi: MP3Quran (mp3quran.net). Asyl süre ýazgylary we aýat wagtlary saklanýar. Sesler diňe ulanyjy ýüklenenden soň enjamdan diňlenýär; awtomatik internet arkaly çalynmaýar. Ýüklemäge taýýarlanylýan ýazgylar entek elýeterli däl.\n\n'
                            'Programma wersiýasy: 0.0.1. Material Icons: Apache 2.0.\n\n'
                            'Arapça ýazuw şrifti: DiyanetAmasya. Türkmençe ýazuw şrifti: Noto Serif (SIL Open Font License).',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => showLicensePage(
                              context: ctx,
                              applicationName: 'Kuran Kitaphanasy',
                              applicationVersion: '0.0.1',
                            ),
                            child: const Text('Şrift ygtyýarnamalary'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Ýap'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
