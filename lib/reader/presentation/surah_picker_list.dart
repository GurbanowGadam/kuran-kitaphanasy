import 'package:flutter/material.dart';

import '../data/reader_data.dart';

/// Source-backed chapter navigation with name-only filtering; no juz/full-text search.
class SurahPickerList extends StatefulWidget {
  const SurahPickerList({
    super.key,
    required this.data,
    required this.selectedSurah,
    required this.onSelected,
  });

  final ReaderData data;
  final int selectedSurah;
  final ValueChanged<int> onSelected;

  @override
  State<SurahPickerList> createState() => _SurahPickerListState();
}

Color surahNavigationBackground(ThemeData theme) => Color.alphaBlend(
  Colors.black.withValues(
    alpha: theme.brightness == Brightness.dark ? .20 : .045,
  ),
  theme.colorScheme.surface,
);

String _normalizedName(String value) {
  var result = value.trim().toLowerCase();
  const letters = {
    'ä': 'a',
    'ë': 'e',
    'ü': 'u',
    'ö': 'o',
    'ý': 'y',
    'ş': 's',
    'ç': 'c',
    'ň': 'n',
    'ž': 'z',
    'ı': 'i',
  };
  letters.forEach((letter, plain) => result = result.replaceAll(letter, plain));
  return result;
}

class _SurahPickerListState extends State<SurahPickerList> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';

  void _updateQuery(String value) {
    setState(() => _query = _normalizedName(value));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final ids = data.availableSurahs
        .where((id) => _normalizedName(data.names[id]!).contains(_query))
        .toList();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = theme.brightness == Brightness.dark
        ? const Color(0xffe59a60)
        : const Color(0xffa65424);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          decoration: BoxDecoration(
            color: surahNavigationBackground(theme),
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: TextField(
            key: const Key('surah-name-search'),
            controller: _search,
            style: const TextStyle(fontSize: 14),
            onChanged: _updateQuery,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: 'Süräniň adyny gözle...',
              isDense: true,
              constraints: const BoxConstraints(minHeight: 48),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Arassala',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        _search.clear();
                        _updateQuery('');
                      },
                    ),
              filled: true,
              fillColor: colors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ids.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Süre tapylmady.'),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                  itemCount: ids.length,
                  itemBuilder: (context, index) {
                    final id = ids[index];
                    final metadata = data.openingMetadata[id]!;
                    final meccan = metadata.startsWith('Mekge');
                    final selected = id == widget.selectedSurah;
                    final page = (data.startPage(id) + 1).toString().padLeft(
                      3,
                      '0',
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: ListTile(
                        key: Key('surah-$id'),
                        dense: true,
                        minTileHeight: 64,
                        minVerticalPadding: 6,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minLeadingWidth: 24,
                        horizontalTitleGap: 10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        selected: selected,
                        selectedColor: colors.onSurface,
                        selectedTileColor: colors.secondaryContainer.withValues(
                          alpha: .45,
                        ),
                        leading: ExcludeSemantics(
                          child: SizedBox(
                            key: Key('surah-origin-$id'),
                            width: 24,
                            height: 26,
                            child: meccan
                                ? CustomPaint(painter: _KaabaPainter(accent))
                                : Icon(
                                    Icons.mosque_outlined,
                                    color: accent,
                                    size: 24,
                                  ),
                          ),
                        ),
                        title: Text(
                          '$id. ${data.names[id]} süresi',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            metadata,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        trailing: Container(
                          key: Key('surah-page-$id'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'sah. $page',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        onTap: () => widget.onSelected(id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Small outline cube with its band; no downloaded icon or additional font.
class _KaabaPainter extends CustomPainter {
  const _KaabaPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(4, 9)
        ..lineTo(16, 4)
        ..lineTo(28, 9)
        ..lineTo(28, 25)
        ..lineTo(16, 29)
        ..lineTo(4, 25)
        ..close()
        ..moveTo(4, 9)
        ..lineTo(16, 14)
        ..lineTo(28, 9)
        ..moveTo(16, 14)
        ..lineTo(16, 29)
        ..moveTo(4, 14)
        ..lineTo(16, 19)
        ..lineTo(28, 14),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KaabaPainter oldDelegate) =>
      color != oldDelegate.color;
}
