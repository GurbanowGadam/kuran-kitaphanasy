enum BookType { quran }

enum BookCapability { arabic, translation, notes, chapters, audio }

class LibraryBook {
  const LibraryBook(
    this.id,
    this.title,
    this.subtitle,
    this.scope, {
    this.type = BookType.quran,
    this.contentVersion = '2026.11.full-v1',
    this.capabilities = const {
      BookCapability.arabic,
      BookCapability.translation,
      BookCapability.notes,
      BookCapability.chapters,
    },
  });
  final String id, title, subtitle, scope, contentVersion;
  final BookType type;
  final Set<BookCapability> capabilities;
}

const libraryBooks = [
  LibraryBook(
    'quran',
    'Kurany Kerim',
    'Arapça we türkmençe many terjimesi',
    '',
  ),
];
