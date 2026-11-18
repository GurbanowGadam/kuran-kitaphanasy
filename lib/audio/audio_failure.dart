/// User-facing audio failures. Messages are the only audio error text shown
/// in the Türkmen interface; technical detail stays in [AudioException.detail].
enum AudioFailure {
  initialization('Ses maglumatlaryny açyp bolmady. Täzeden synanyşyň.'),
  invalidSelection('Saýlanan aýat üçin ses tapylmady.'),
  unknownReciter('Saýlanan kary elýeterli däl.'),
  unavailable('Bu süre üçin ses elýeterli däl.'),
  notDownloaded('Diňlemek üçin ilki süräni doly ýükläň.'),
  network('Ýükläp bolmady. Internet baglanyşygyny barlap, täzeden synanyşyň.'),
  integrity('Ýüklenen faýl barlagdan geçmedi. Täzeden ýükläň.'),
  storage('Faýly enjama ýazyp bolmady. Boş ýeri barlaň.'),
  localCorrupt('Ýüklenen ses faýly zeper ýetipdir. Süräni täzeden ýükläň.'),
  playback('Sesi çalyp bolmady.');

  const AudioFailure(this.message);
  final String message;
}

class AudioException implements Exception {
  const AudioException(this.failure, this.detail);
  final AudioFailure failure;
  final String detail;
  @override
  String toString() => 'AudioException(${failure.name}): $detail';
}
