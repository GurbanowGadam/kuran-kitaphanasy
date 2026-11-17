import 'package:flutter/material.dart';

/// A reading annotation, never inserted into the scripture's shaping run.
class SajdahMarker extends StatelessWidget {
  const SajdahMarker({
    super.key,
    required this.reference,
    this.showReference = false,
  });
  final String reference;
  final bool showReference;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xffe0b995)
        : const Color(0xff81502b);
    return Semantics(
      label: '$reference — Sežde aýaty',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Align(
          alignment: Alignment.centerRight,
          child: DefaultTextStyle(
            style: TextStyle(color: color, fontSize: 14, height: 1.4),
            child: IconTheme(
              data: IconThemeData(color: color, size: 16),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  const Icon(Icons.info),
                  const Text('(Sežde aýaty)'),
                  if (showReference) Text(reference),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
