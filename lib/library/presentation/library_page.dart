import 'package:flutter/material.dart';

import '../domain/book.dart';
import 'book_cover.dart';

export 'book_cover.dart' show BookCover;

class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    required this.dark,
    required this.openBook,
    this.books = libraryBooks,
  });
  final List<LibraryBook> books;
  final bool dark;
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
                          key: Key('library-title'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.6,
                          ),
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
                  const SizedBox(height: 16),
                  const Text(
                    'Hadyslar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: colors.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colors.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final title in ['Sahih Muslim', 'Sahih Buhari'])
                          ListTile(
                            leading: Icon(
                              Icons.menu_book_outlined,
                              color: colors.primary,
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: const Text(
                              'Ýakynda',
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(
                              Icons.schedule_outlined,
                              size: 20,
                            ),
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(title),
                                content: const Text(
                                  'Ýakyn wagtda taýýar bolar.',
                                ),
                                actions: [
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
