import 'package:flutter/material.dart';

/// Unbranded fallback for embedded/widget use; production keeps the native
/// book until real initialization completes. Errors must always be actionable.
class StartupPage extends StatelessWidget {
  const StartupPage({super.key, required this.failed, required this.retry});
  final bool failed;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduced = media.disableAnimations || media.accessibleNavigation;
    return Scaffold(
      key: Key(failed ? 'startup-error' : 'startup-loading'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      failed
                          ? 'Kitaphanany açyp bolmady.'
                          : 'Kitaphana taýýarlanýar…',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (failed)
                    FilledButton(
                      key: const Key('startup-retry'),
                      onPressed: retry,
                      child: const Text('Täzeden synanyş'),
                    )
                  else
                    SizedBox(
                      width: 112,
                      child: LinearProgressIndicator(
                        value: reduced ? 0 : null,
                        semanticsLabel: 'Ýüklenýär',
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
