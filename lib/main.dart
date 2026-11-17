import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
export 'app/app.dart';
export 'reader/presentation/reader.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the platform book visible; never submit a second Flutter splash.
  // Deferred frames still run post-frame callbacks used by initialization.
  binding.deferFirstFrame();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/fonts/NotoSerif-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['Noto Serif'], license);
  });
  bool released = false;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['Material Icons'],
      await rootBundle.loadString('assets/licenses/MaterialIcons-LICENSE.txt'),
    );
  });
  runApp(
    QuranApp(
      onStartupReady: () {
        if (released) return;
        released = true;
        binding.allowFirstFrame();
      },
    ),
  );
}
