import 'package:flutter/material.dart';

/// Sources, privacy and licences. Opened from Sazlamalar.
Future<void> showAboutSources(BuildContext context) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Kuran Kitaphanasy'),
    content: const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Arapça tekst we süre maglumatlary: Türkiýe Diyanet Işleri Baş müdirliginiň açyk Kuran çeşmesi (kuran.diyanet.gov.tr, textGroup 4).\n\n'
            'Türkmençe many terjimesi, süre atlary, girişler we düşündirişler: Türkmenistanyň Müftüsiniň müdiriýeti tarapyndan taýýarlanan «Kurany Kerim» neşiri (PDF). Çeşmedäki toparlanan aýatlar saklanýar.\n\n'
            'Tekstler we şriftler enjamda saklanýar; okamak üçin internet gerek däl. Hasap, mahabat ýa-da analitika ýok. Okalyş ýagdaýy diňe şu enjamda saklanýar.\n\n'
            'Ses çeşmesi: MP3Quran (mp3quran.net). Asyl süre ýazgylary we aýat wagtlary saklanýar. Sesler diňe ulanyjy ýüklenenden soň enjamdan diňlenýär; awtomatik internet arkaly çalynmaýar. Ýüklemäge taýýarlanylýan ýazgylar entek elýeterli däl.\n\n'
            'Programma wersiýasy: 1.0.0. Material Icons: Apache 2.0.\n\n'
            'Arapça ýazuw şrifti: DiyanetAmasya. Türkmençe ýazuw şrifti: Noto Serif (SIL Open Font License).',
          ),
          SizedBox(height: 16),
          Text(
            'Gizlinlik we maglumatlar',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Sesleri ýüklemegi özüňiz saýlanyňyzda, programma Google Drive-daky '
            'hemmeler üçin açyk faýllary internet arkaly ýükleýär. Şonda Google '
            'Drive tor haýyşlaryny we IP salgyňyz ýaly tehniki maglumatlary alýar. '
            'Ýüklenen ses faýllarynyň bitewiligi barlanýar.',
          ),
          SizedBox(height: 12),
          Text('Programmanyň gizlinlik syýasaty:'),
          SelectableText(
            'https://gurbanowgadam.github.io/kuran-kitaphanasy/privacy.html',
          ),
          SizedBox(height: 12),
          Text('Habarlaşmak üçin: kurankitaphanasy@gmail.com'),
          SizedBox(height: 12),
          Text('Google hyzmatynyň gizlinlik syýasaty:'),
          SelectableText('https://policies.google.com/privacy'),
          SizedBox(height: 12),
          Text(
            'Sazlamalar, okalyş ýagdaýy, bellikler, hasaplar we ýüklenen sesler diňe şu '
            'enjamda saklanýar. Hasap açmak talap edilmeýär; mahabat we '
            'analitika ýok.',
          ),
          SizedBox(height: 12),
          Text(
            'Hasaplaryň ätiýaçlyk nusgasy diňe siz «Hasaplary göçür» '
            'düwmesine basanyňyzda enjamyň buferine göçürilýär; ony '
            'nirede saklajagyňyzy özüňiz saýlaýarsyňyz.',
          ),
          SizedBox(height: 12),
          Text(
            'Ýerli maglumatlary pozmak üçin enjamyň ulgam sazlamalarynda '
            'programmanyň maglumatlaryny arassalaň ýa-da programmany aýryň. '
            'Şonda şu enjamdaky sazlamalar, okalyş ýagdaýy, bellikler, hasaplar we '
            'ýüklenen sesler pozular.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => showLicensePage(
          context: ctx,
          applicationName: 'Kuran Kitaphanasy',
          applicationVersion: '1.0.0',
        ),
        child: const Text('Şrift ygtyýarnamalary'),
      ),
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ýap')),
    ],
  ),
);
