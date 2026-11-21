import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/tracker.dart';

/// Creates a tracker from a template / from scratch, or edits its settings.
/// Pops with the resulting [Tracker]; the kind is fixed after creation.
class TrackerEditor extends StatefulWidget {
  const TrackerEditor({
    super.key,
    required this.id,
    required this.createdAt,
    this.template,
  }) : existing = null;

  const TrackerEditor.edit(Tracker tracker, {super.key})
    : existing = tracker,
      id = '',
      createdAt = 0,
      template = null;

  final String id;
  final int createdAt;
  final TrackerTemplate? template;
  final Tracker? existing;

  @override
  State<TrackerEditor> createState() => _TrackerEditorState();
}

class _Row {
  _Row(String label, int value, this.target)
    : label = TextEditingController(text: label),
      value = TextEditingController(text: '$value');
  final TextEditingController label, value;
  int target;
  void dispose() {
    label.dispose();
    value.dispose();
  }
}

/// Days in a year for the "fill from years" helper (solar calendar).
const daysPerYear = 365;

class _TrackerEditorState extends State<TrackerEditor> {
  final form = GlobalKey<FormState>();
  late TrackerKind kind;
  late final TextEditingController name, unit, step, target, value;
  final years = TextEditingController(), days = TextEditingController();
  final rows = <_Row>[];
  String? rowsError;

  bool get creating => widget.existing == null;
  bool get custom => creating && widget.template == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final t = widget.template;
    kind = e?.kind ?? t?.kind ?? TrackerKind.counter;
    name = TextEditingController(text: e?.name ?? t?.name ?? '');
    unit = TextEditingController(text: e?.unit ?? t?.unit ?? '');
    step = TextEditingController(text: '${e?.step ?? t?.step ?? 1}');
    final first = e != null && e.items.isNotEmpty ? e.items.first : null;
    target = TextEditingController(
      text: (e != null ? first?.target : t?.target)?.toString() ?? '',
    );
    value = TextEditingController(text: '${first?.value ?? 0}');
    if (e != null && e.kind == TrackerKind.debt) {
      for (final i in e.items) {
        rows.add(_Row(i.label, i.value, i.target ?? i.value));
      }
    } else {
      for (final l in t?.labels ?? const <String>[]) {
        rows.add(_Row(l, 0, 0));
      }
    }
  }

  @override
  void dispose() {
    for (final c in [name, unit, step, target, value, years, days]) {
      c.dispose();
    }
    for (final r in rows) {
      r.dispose();
    }
    super.dispose();
  }

  String? number(String? text, {bool required = true, int min = 0}) {
    final raw = text?.trim() ?? '';
    if (raw.isEmpty) return required ? 'San giriziň' : null;
    final n = int.tryParse(raw);
    if (n == null || n < min || n > trackerMaxValue) {
      return min > 0 ? '$min-den $trackerMaxValue-e çenli san' : 'Nädogry san';
    }
    return null;
  }

  int? parse(TextEditingController c) => int.tryParse(c.text.trim());

  void fill() {
    final total = (parse(years) ?? 0) * daysPerYear + (parse(days) ?? 0);
    if (total <= 0 || total > trackerMaxValue) return;
    setState(() {
      for (final r in rows) {
        r.value.text = '$total';
        r.target = total;
      }
    });
  }

  void save() {
    setState(() => rowsError = null);
    if (!form.currentState!.validate()) return;
    if (kind == TrackerKind.debt && rows.isEmpty) {
      setState(() => rowsError = 'Iň bolmanda bir setir gerek');
      return;
    }
    final items = switch (kind) {
      TrackerKind.habit => const <TrackerItem>[],
      TrackerKind.debt => [
        for (final r in rows)
          TrackerItem(
            label: r.label.text.trim(),
            value: parse(r.value)!,
            // Raising the remaining count raises the initial total with it.
            target: parse(r.value)! > r.target ? parse(r.value)! : r.target,
          ),
      ],
      _ => [
        TrackerItem(label: '', value: parse(value)!, target: parse(target)),
      ],
    };
    final e = widget.existing;
    final tracker = Tracker(
      id: e?.id ?? widget.id,
      name: name.text.trim(),
      kind: kind,
      unit: kind == TrackerKind.habit ? '' : unit.text.trim(),
      step: kind == TrackerKind.counter || kind == TrackerKind.progress
          ? parse(step)!
          : 1,
      items: items,
      days: e?.days ?? const {},
      createdAt: e?.createdAt ?? widget.createdAt,
    );
    // The form validated every field; this is a last fail-closed guard.
    if (Tracker.problem(tracker) != null) {
      setState(() => rowsError = 'Maglumatlary barlaň');
      return;
    }
    Navigator.pop(context, tracker);
  }

  InputDecoration field(String label, {String? helper}) =>
      InputDecoration(labelText: label, helperText: helper);

  Widget numberField(
    String key,
    TextEditingController c,
    String label, {
    String? helper,
    bool required = true,
    int min = 0,
    String? Function(int)? extra,
  }) => TextFormField(
    key: Key(key),
    controller: c,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: field(label, helper: helper),
    validator: (text) {
      final basic = number(text, required: required, min: min);
      if (basic != null || extra == null || (text ?? '').trim().isEmpty) {
        return basic;
      }
      return extra(int.parse(text!.trim()));
    },
  );

  @override
  Widget build(BuildContext context) {
    final gap = const SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        title: Text(creating ? 'Täze hasap' : 'Hasaby üýtget'),
        actions: [
          TextButton(
            key: const Key('editor-save'),
            onPressed: save,
            child: const Text('Ýatda sakla'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                key: const Key('editor-name'),
                controller: name,
                maxLength: trackerMaxNameLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: field('Ady'),
                validator: (t) =>
                    (t ?? '').trim().isEmpty ? 'Adyny giriziň' : null,
              ),
              if (custom) ...[
                DropdownButtonFormField<TrackerKind>(
                  key: const Key('editor-kind'),
                  initialValue: kind,
                  decoration: field('Görnüşi'),
                  items: [
                    for (final k in TrackerKind.values)
                      DropdownMenuItem(value: k, child: Text(k.label)),
                  ],
                  onChanged: (k) => setState(() {
                    kind = k!;
                    if (kind == TrackerKind.debt && rows.isEmpty) {
                      rows.add(_Row('', 0, 0));
                    }
                  }),
                ),
                gap,
                Text(switch (kind) {
                  TrackerKind.counter =>
                    'Her basanyňyzda san artýar (meselem: tesbih, salawat).',
                  TrackerKind.progress => 'Jemi maksada çenli öňe gidişiňizi görkezýär (meselem: kitap).',
                  TrackerKind.debt => 'Birnäçe setir boýunça galan bergini azaldýar (meselem: kaza).',
                  TrackerKind.habit =>
                    'Her gün edildi ýa-da edilmedi diýip belleýärsiňiz.',
                }, style: Theme.of(context).textTheme.bodySmall),
                gap,
              ],
              if (kind != TrackerKind.habit) ...[
                TextFormField(
                  key: const Key('editor-unit'),
                  controller: unit,
                  maxLength: 30,
                  decoration: field(
                    'Birligi',
                    helper: 'Meselem: sahypa, gezek',
                  ),
                ),
              ],
              if (kind == TrackerKind.counter) ...[
                numberField(
                  'editor-target',
                  target,
                  'Bir aýlawdaky maksat',
                  helper: 'Boş goýup bolýar (meselem: 33)',
                  required: false,
                  min: 1,
                ),
                gap,
                numberField(
                  'editor-step',
                  step,
                  'Her basyşda goşulýan',
                  min: 1,
                ),
                gap,
                numberField('editor-value', value, 'Häzirki san'),
              ],
              if (kind == TrackerKind.progress) ...[
                numberField('editor-target', target, 'Jemi maksat', min: 1),
                gap,
                numberField(
                  'editor-value',
                  value,
                  'Eýýäm edileni',
                  extra: (v) {
                    final t = parse(target);
                    return t != null && v > t
                        ? 'Maksatdan köp bolup bilmez'
                        : null;
                  },
                ),
                gap,
                numberField(
                  'editor-step',
                  step,
                  'Çalt goşmak düwmesi',
                  helper: 'Meselem: 10 sahypa',
                  min: 1,
                ),
              ],
              if (kind == TrackerKind.debt) ...debtFields(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> debtFields(BuildContext context) => [
    const SizedBox(height: 8),
    Text('Galan bergiler', style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: 4),
    Text(
      'Näçe gün kaza galan bolsa, ýyl we gün giriziň: her setire şol san ýazylar.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            key: const Key('editor-years'),
            controller: years,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: field('Ýyl ($daysPerYear gün)'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: const Key('editor-days'),
            controller: days,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: field('Gün'),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          key: const Key('editor-fill'),
          onPressed: fill,
          child: const Text('Doldur'),
        ),
      ],
    ),
    const SizedBox(height: 12),
    for (final (i, r) in rows.indexed)
      Row(
        key: ObjectKey(r),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              key: Key('editor-item-label-$i'),
              controller: r.label,
              maxLength: trackerMaxNameLength,
              decoration: field('Setir'),
              validator: (t) =>
                  (t ?? '').trim().isEmpty ? 'Adyny giriziň' : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: numberField('editor-item-value-$i', r.value, 'Galan'),
          ),
          IconButton(
            key: Key('editor-item-remove-$i'),
            tooltip: 'Setiri aýyr',
            onPressed: () => setState(() => rows.removeAt(i).dispose()),
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    if (rowsError != null)
      Text(
        rowsError!,
        key: const Key('editor-rows-error'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    if (rows.length < trackerMaxItems)
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: const Key('editor-item-add'),
          onPressed: () => setState(() => rows.add(_Row('', 0, 0))),
          icon: const Icon(Icons.add),
          label: const Text('Setir goş'),
        ),
      ),
  ];
}
