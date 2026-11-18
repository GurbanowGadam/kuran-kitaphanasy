import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import 'audio_catalog.dart';
import 'audio_failure.dart';

class AudioCancellation {
  bool cancelled = false;
  void Function()? onCancel;
  void cancel() {
    cancelled = true;
    onCancel?.call();
  }

  void check() {
    if (cancelled) throw const AudioCancelled();
  }
}

class AudioCancelled implements Exception {
  const AudioCancelled();
}

typedef AudioDownload = Stream<List<int>> Function(
  Uri uri,
  AudioCancellation cancel,
);

const _maxExpandedBytes = 256 * 1024 * 1024;

Uri driveDownloadUri(String fileId) =>
    Uri.https('drive.google.com', '/uc', {'export': 'download', 'id': fileId});

Future<String> sha256OfFile(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// Downloads, verifies and atomically installs [package] at [targetPath].
///
/// Memory stays bounded by I/O buffers: the archive is streamed to
/// `<target>.part` while hashing, the ZIP is read from that file and its MP3
/// entry is decompressed straight to `<target>.staging`, hashed, and only then
/// renamed into place. No partially verified package is ever published.
Future<void> installAudioPackage({
  required AudioPackage package,
  required String targetPath,
  required AudioDownload download,
  required AudioCancellation cancel,
  void Function(double progress)? onProgress,
}) async {
  final part = File('$targetPath.part');
  final stage = Directory('$targetPath.staging');
  IOSink? sink;
  InputFileStream? input;
  try {
    if (package.bytes <= 0 || package.bytes > AudioPackage.maxArchiveBytes) {
      throw const AudioException(
        AudioFailure.integrity,
        'Archive exceeds safe size limit',
      );
    }
    await part.parent.create(recursive: true);
    sink = part.openWrite();
    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    var count = 0;
    try {
      await for (final chunk in download(
        driveDownloadUri(package.driveFileId),
        cancel,
      )) {
        cancel.check();
        count += chunk.length;
        if (count > package.bytes) {
          throw const AudioException(
            AudioFailure.integrity,
            'Unexpected archive length / HTML response',
          );
        }
        sink.add(chunk);
        hasher.add(chunk);
        onProgress?.call(count / package.bytes);
      }
    } on AudioException {
      rethrow;
    } on AudioCancelled {
      rethrow;
    } on FileSystemException {
      rethrow;
    } catch (e) {
      throw AudioException(AudioFailure.network, '$e');
    }
    await sink.flush();
    await sink.close();
    sink = null;
    hasher.close();
    cancel.check();
    if (count != package.bytes ||
        digest.value.toString() != package.sha256Hash) {
      throw const AudioException(
        AudioFailure.integrity,
        'Archive is incomplete or SHA256 does not match',
      );
    }

    if (await stage.exists()) await stage.delete(recursive: true);
    await stage.create(recursive: true);
    input = InputFileStream(part.path);
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input, verify: true);
    } catch (e) {
      throw AudioException(AudioFailure.integrity, 'Invalid ZIP: $e');
    }
    final seen = <String>{};
    var expanded = 0;
    for (final entry in archive) {
      cancel.check();
      if (!entry.isFile ||
          entry.isSymbolicLink ||
          entry.name != package.audioFile ||
          !package.files.containsKey(entry.name) ||
          !seen.add(entry.name)) {
        throw const AudioException(
          AudioFailure.integrity,
          'Unsafe or unexpected ZIP entry',
        );
      }
      expanded += entry.size;
      if (entry.size > AudioPackage.maxArchiveBytes ||
          expanded > _maxExpandedBytes) {
        throw const AudioException(
          AudioFailure.integrity,
          'Expanded archive too large',
        );
      }
      final file = File('${stage.path}/${entry.name}');
      final output = OutputFileStream(file.path);
      try {
        entry.writeContent(output);
      } on FileSystemException {
        rethrow;
      } catch (e) {
        throw AudioException(AudioFailure.integrity, 'ZIP entry: $e');
      } finally {
        await output.close();
      }
      if (await sha256OfFile(file) != package.files[entry.name]) {
        throw const AudioException(
          AudioFailure.integrity,
          'MP3 checksum mismatch',
        );
      }
    }
    if (seen.length != package.files.length) {
      throw const AudioException(AudioFailure.integrity, 'Incomplete package');
    }
    cancel.check();
    final target = Directory(targetPath);
    if (await target.exists()) await target.delete(recursive: true);
    await stage.rename(target.path);
  } on FileSystemException catch (e) {
    throw AudioException(AudioFailure.storage, '$e');
  } finally {
    await sink?.close();
    input?.closeSync();
    if (await part.exists()) await part.delete();
    if (await stage.exists()) await stage.delete(recursive: true);
  }
}

/// Streams a public Google Drive file, following its one-step large-file
/// confirmation form. Only Drive hosts are accepted for the follow-up request.
Stream<List<int>> driveDownload(Uri uri, AudioCancellation cancel) async* {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  cancel.onCancel = () => client.close(force: true);
  try {
    for (var attempt = 0; attempt < 2; attempt++) {
      cancel.check();
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      if (response.statusCode != 200) {
        throw AudioException(
          AudioFailure.network,
          'Google Drive HTTP ${response.statusCode}',
        );
      }
      final type = response.headers.contentType?.mimeType ?? '';
      if (type.contains('html')) {
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 1024 * 1024) {
            throw const AudioException(
              AudioFailure.network,
              'Drive returned HTML, not audio',
            );
          }
        }
        final html = utf8.decode(bytes, allowMalformed: true);
        final action = RegExp(r'<form[^>]*action="([^"]+)"')
            .firstMatch(html)
            ?.group(1);
        if (attempt > 0 || action == null) {
          throw const AudioException(
            AudioFailure.network,
            'Google Drive download unavailable (quota, permissions or confirmation)',
          );
        }
        final next = Uri.parse(action.replaceAll('&amp;', '&'));
        if (next.scheme != 'https' ||
            !{
              'drive.google.com',
              'drive.usercontent.google.com',
            }.contains(next.host)) {
          throw const AudioException(
            AudioFailure.network,
            'Unsafe Drive confirmation URL',
          );
        }
        final params = <String, String>{...next.queryParameters};
        for (final field in RegExp(r'<input[^>]*>').allMatches(html)) {
          final name = RegExp(r'name="([^"]+)"')
              .firstMatch(field.group(0)!)
              ?.group(1);
          final value = RegExp(r'value="([^"]*)"')
              .firstMatch(field.group(0)!)
              ?.group(1);
          if (name != null && value != null) {
            params[name] = value.replaceAll('&amp;', '&');
          }
        }
        uri = next.replace(queryParameters: params);
        continue;
      }
      yield* response.timeout(const Duration(seconds: 45));
      return;
    }
  } finally {
    cancel.onCancel = null;
    client.close(force: true);
  }
}
