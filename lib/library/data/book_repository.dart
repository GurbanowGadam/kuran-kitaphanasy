import '../../reader/data/reader_data.dart';
import '../domain/book.dart';

abstract interface class BookRepository {
  List<LibraryBook> get books;
  Future<ReaderData> load(String bookId);
}

class BundledBookRepository implements BookRepository {
  @override
  List<LibraryBook> get books => libraryBooks;
  final _cache = <String, Future<ReaderData>>{};
  @override
  Future<ReaderData> load(String bookId) {
    if (!books.any((b) => b.id == bookId)) {
      return Future.error(
        ArgumentError.value(bookId, 'bookId', 'Unknown book'),
      );
    }
    return _cache.putIfAbsent(bookId, () async {
      try {
        return await ReaderData.load();
      } catch (_) {
        // A transient asset/read failure must not poison all later retries.
        _cache.remove(bookId);
        rethrow;
      }
    });
  }
}
