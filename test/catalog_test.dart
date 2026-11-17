import 'package:flutter_test/flutter_test.dart';
import 'package:kuran_kitaphanasy/library/domain/book.dart';
import 'package:kuran_kitaphanasy/library/data/book_repository.dart';

void main() {
  test(
    'V1 catalog describes only real offline Quran with explicit capabilities',
    () {
      final repo = BundledBookRepository();
      expect(repo.books.length, 1);
      final book = repo.books.single;
      expect(book.id, 'quran');
      expect(book.type, BookType.quran);
      expect(book.contentVersion, isNotEmpty);
      expect(book.capabilities, {
        BookCapability.arabic,
        BookCapability.translation,
        BookCapability.notes,
        BookCapability.chapters,
      });
      expect(book.capabilities.contains(BookCapability.audio), isFalse);
    },
  );
}
