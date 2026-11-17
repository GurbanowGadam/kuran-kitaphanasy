part of '../presentation/reader.dart';

extension _ReaderSettings on _ReaderState {
  void settings(ReaderData data) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) {
          void update(VoidCallback change) {
            changeState(change);
            refresh(() {});
          }

          Widget choice(
            String key,
            String label,
            bool selected,
            VoidCallback action,
          ) => ChoiceChip(
            key: Key(key),
            label: Text(label),
            selected: selected,
            onSelected: (_) => update(action),
          );
          Widget sizes(
            String title,
            String prefix,
            double value,
            double min,
            double max,
            ValueChanged<double> change,
          ) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              Row(
                children: [
                  IconButton(
                    key: Key('$prefix-decrease'),
                    tooltip: '$title: kiçelt',
                    onPressed: value > min
                        ? () => update(() => change(value - 2))
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text('${value.toInt()}'),
                  IconButton(
                    key: Key('$prefix-increase'),
                    tooltip: '$title: ulalt',
                    onPressed: value < max
                        ? () => update(() => change(value + 2))
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          );
          return Theme(
            data: readerTheme,
            child: Material(
              color: readerTheme.colorScheme.surface,
              child: SafeArea(
                child: SizedBox(
                  height: MediaQuery.sizeOf(ctx).height * .8,
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Sazlamalar'),
                        subtitle: const Text('Diňe şu kitap üçin'),
                        trailing: IconButton(
                          tooltip: 'Ýap',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          key: const Key('settings-sheet'),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tema'),
                              Wrap(
                                spacing: 8,
                                children: [
                                  choice(
                                    'theme-light',
                                    'Açyk',
                                    readerTheme.brightness == Brightness.light,
                                    () => bookDark = false,
                                  ),
                                  choice(
                                    'theme-dark',
                                    'Garaňky',
                                    readerTheme.brightness == Brightness.dark,
                                    () => bookDark = true,
                                  ),
                                ],
                              ),
                              sizes(
                                'Arapça harplaryň ululygy',
                                'arabic',
                                arabicSize,
                                24,
                                48,
                                (v) => arabicSize = v,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Text(
                                  data.pages
                                      .expand((p) => p.verses)
                                      .firstWhere(
                                        (v) => v.surah == 1 && v.ayah == 1,
                                      )
                                      .text,
                                  key: const Key('arabic-size-preview'),
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontFamily: 'DiyanetAmasya',
                                    fontSize: arabicSize,
                                    height: 1.9,
                                  ),
                                ),
                              ),
                              sizes(
                                'Türkmençe harplaryň ululygy',
                                'translation',
                                translationSize,
                                14,
                                32,
                                (v) => translationSize = v,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Text(
                                  'Bismillahirrahmanirrahim',
                                  key: const Key('translation-size-preview'),
                                  textDirection: TextDirection.ltr,
                                  style: TextStyle(
                                    fontFamily: 'NotoSerif',
                                    fontSize: translationSize,
                                    height: 1.65,
                                  ),
                                ),
                              ),
                              const Text(
                                'Diňe Arapça görnüşinde tekstiň deňlenişi',
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  choice(
                                    'align-center',
                                    'Ortada',
                                    alignment == TextAlign.center,
                                    () => alignment = TextAlign.center,
                                  ),
                                  choice(
                                    'align-right',
                                    'Sagda',
                                    alignment == TextAlign.right,
                                    () => alignment = TextAlign.right,
                                  ),
                                  choice(
                                    'align-justify',
                                    'Iki gyrada',
                                    alignment == TextAlign.justify,
                                    () => alignment = TextAlign.justify,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text('Sahypalaryň geçişi'),
                              Wrap(
                                spacing: 8,
                                children: [
                                  choice(
                                    'orientation-horizontal',
                                    'Keseligine',
                                    !vertical,
                                    () => changeOrientation(false),
                                  ),
                                  choice(
                                    'orientation-vertical',
                                    'Dikligine',
                                    vertical,
                                    () => changeOrientation(true),
                                  ),
                                ],
                              ),
                              TextButton(
                                key: const Key('settings-reset'),
                                onPressed: () => update(() {
                                  arabicSize = 34;
                                  translationSize = 20;
                                  alignment = TextAlign.justify;
                                  bookDark = null;
                                  changeOrientation(false);
                                }),
                                child: const Text(
                                  'Başlangyç sazlamalara dolan',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
