import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/tracker_book.dart';
import '../domain/tracker.dart';
import 'tracker_editor.dart';

const _weekdays = ['Du', 'Si', 'Ça', 'Pe', 'An', 'Şe', 'Ýe'];

String _percent(double f) => '${(f * 100).floor()}%';

class TrackersPage extends StatefulWidget {
  const TrackersPage({super.key, required this.book});
  final TrackerBook book;

  @override
  State<TrackersPage> createState() => _TrackersPageState();
}

class _TrackersPageState extends State<TrackersPage> {
  TrackerBook get book => widget.book;

  @override
  void initState() {
    super.initState();
    if (book.state != TrackerBookState.ready) unawaited(book.load());
  }

  Future<void> create() async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          key: const Key('template-sheet'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Täze hasap',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              for (final t in trackerTemplates)
                ListTile(
                  key: Key('template-${t.key}'),
                  leading: Icon(_icon(t.kind)),
                  title: Text(t.title),
                  subtitle: Text(t.description),
                  onTap: () => Navigator.pop(ctx, t),
                ),
              const Divider(),
              ListTile(
                key: const Key('template-custom'),
                leading: const Icon(Icons.tune),
                title: const Text('Öz hasabyň'),
                subtitle: const Text(
                  'Adyny, görnüşini we maksadyny özüňiz saýlaň.',
                ),
                onTap: () => Navigator.pop(ctx, 'custom'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final created = await Navigator.of(context).push<Tracker>(
      MaterialPageRoute(
        builder: (_) => TrackerEditor(
          id: book.newId(),
          createdAt: book.clock().millisecondsSinceEpoch,
          template: choice is TrackerTemplate ? choice : null,
        ),
      ),
    );
    if (created != null) book.add(created);
  }

  Future<void> edit(Tracker t) async {
    final edited = await Navigator.of(
      context,
    ).push<Tracker>(MaterialPageRoute(builder: (_) => TrackerEditor.edit(t)));
    // Activity recorded meanwhile is kept; the editor only replaces settings.
    final current = book.byId(t.id);
    if (edited != null && current != null) {
      book.update(edited.copyWith(days: current.days));
    }
  }

  Future<void> delete(Tracker t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('«${t.name}» pozulsynmy?'),
        content: const Text('Pozulan hasaby yzyna getirip bolmaýar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ýatyr'),
          ),
          FilledButton(
            key: const Key('tracker-delete-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Poz'),
          ),
        ],
      ),
    );
    if (ok == true) book.remove(t.id);
  }

  Future<void> amount(Tracker t, int item) async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _AmountDialog(tracker: t, item: item),
    );
    if (result != null) book.record(t.id, item, result);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: book,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final ready = book.state == TrackerBookState.ready;
      return Scaffold(
        floatingActionButton: ready
            ? FloatingActionButton.extended(
                key: const Key('tracker-add'),
                onPressed: create,
                icon: const Icon(Icons.add),
                label: const Text('Täze hasap'),
              )
            : null,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.checklist_outlined,
                          color: colors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Hasaplar',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  if (book.saveFailed)
                    Container(
                      key: const Key('trackers-save-failed'),
                      color: colors.errorContainer,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Soňky üýtgeşmeler ýatda saklanmady. Enjamda boş ýeri barlaň.',
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  Expanded(child: body(context)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget body(BuildContext context) {
    switch (book.state) {
      case TrackerBookState.loading:
        return const Center(child: CircularProgressIndicator());
      case TrackerBookState.failed:
        return Center(
          key: const Key('trackers-load-error'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hasaplary okap bolmady. Ýatda saklanan maglumatlar üýtgedilmedi.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('trackers-retry'),
                  onPressed: book.load,
                  child: const Text('Täzeden synanyş'),
                ),
              ],
            ),
          ),
        );
      case TrackerBookState.ready:
        break;
    }
    if (book.trackers.isEmpty) {
      return SingleChildScrollView(
        key: const Key('trackers-empty'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.checklist_rtl_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Entek hasap ýok.',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kaza namazlaryny, okan kitabyňyzy, hatymy ýa-da tesbihi '
                'yzarlamak üçin «Täze hasap» düwmesine basyň.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final now = book.clock();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        for (final (i, t) in book.trackers.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TrackerCard(
              key: Key('tracker-${t.id}'),
              tracker: t,
              now: now,
              first: i == 0,
              last: i == book.trackers.length - 1,
              onRecord: (item, n) => book.record(t.id, item, n),
              onAmount: (item) => amount(t, item),
              onToggleDay: (day) => book.update(t.toggleDay(day)),
              onMenu: (action) {
                switch (action) {
                  case 'edit':
                    edit(t);
                  case 'reset':
                    book.update(t.resetCount());
                  case 'up':
                    book.move(i, i - 1);
                  case 'down':
                    book.move(i, i + 1);
                  case 'delete':
                    delete(t);
                }
              },
            ),
          ),
      ],
    );
  }
}

IconData _icon(TrackerKind kind) => switch (kind) {
  TrackerKind.counter => Icons.touch_app_outlined,
  TrackerKind.progress => Icons.menu_book_outlined,
  TrackerKind.debt => Icons.mosque_outlined,
  TrackerKind.habit => Icons.event_available_outlined,
};

class _TrackerCard extends StatelessWidget {
  const _TrackerCard({
    super.key,
    required this.tracker,
    required this.now,
    required this.first,
    required this.last,
    required this.onRecord,
    required this.onAmount,
    required this.onToggleDay,
    required this.onMenu,
  });

  final Tracker tracker;
  final DateTime now;
  final bool first, last;
  final void Function(int item, int amount) onRecord;
  final void Function(int item) onAmount;
  final void Function(DateTime day) onToggleDay;
  final void Function(String action) onMenu;

  String get id => tracker.id;
  String get unit => tracker.unit.isEmpty ? '' : ' ${tracker.unit}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = tracker.today(now);
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon(tracker.kind), size: 20, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tracker.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  key: Key('tracker-menu-$id'),
                  tooltip: 'Hasap sazlamalary',
                  onSelected: onMenu,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      key: Key('tracker-edit'),
                      value: 'edit',
                      child: Text('Üýtget'),
                    ),
                    if (tracker.kind == TrackerKind.counter)
                      const PopupMenuItem(
                        key: Key('tracker-reset'),
                        value: 'reset',
                        child: Text('Nola gaýtar'),
                      ),
                    if (!first)
                      const PopupMenuItem(
                        value: 'up',
                        child: Text('Ýokary süýşür'),
                      ),
                    if (!last)
                      const PopupMenuItem(
                        value: 'down',
                        child: Text('Aşak süýşür'),
                      ),
                    const PopupMenuItem(
                      key: Key('tracker-delete'),
                      value: 'delete',
                      child: Text('Poz'),
                    ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: switch (tracker.kind) {
                TrackerKind.counter => counter(context, today),
                TrackerKind.progress => progress(context, today),
                TrackerKind.debt => debt(context, today),
                TrackerKind.habit => habit(context),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget counter(BuildContext context, int today) {
    final item = tracker.items.first;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                key: Key('tracker-value-$id'),
                TextSpan(
                  text: '${item.value}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    if (item.target != null)
                      TextSpan(
                        text: ' / ${item.target}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
              if (tracker.fraction case final f?) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(value: f),
              ],
              const SizedBox(height: 6),
              Text('Bu gün: $today$unit'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: Key('tracker-dec-$id'),
          tooltip: 'Yza al',
          onPressed: item.value > 0 ? () => onRecord(0, -1) : null,
          icon: const Icon(Icons.undo),
        ),
        SizedBox(
          width: 72,
          height: 72,
          child: FilledButton(
            key: Key('tracker-inc-$id'),
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              onRecord(0, tracker.step);
            },
            child: Text(
              '+${tracker.step}',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget progress(BuildContext context, int today) {
    final item = tracker.items.first;
    final f = tracker.fraction ?? 0;
    final done = item.value >= (item.target ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        LinearProgressIndicator(value: f, minHeight: 6),
        const SizedBox(height: 8),
        Text(
          '${item.value} / ${item.target}$unit · ${_percent(f)}',
          key: Key('tracker-value-$id'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(done ? 'Tamamlandy · Bu gün: $today$unit' : 'Bu gün: $today$unit'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              key: Key('tracker-inc-$id'),
              onPressed: done ? null : () => onRecord(0, tracker.step),
              child: Text('+${tracker.step}'),
            ),
            OutlinedButton(
              key: Key('tracker-amount-$id-0'),
              onPressed: () => onAmount(0),
              child: const Text('Başga san'),
            ),
          ],
        ),
      ],
    );
  }

  Widget debt(BuildContext context, int today) {
    final colors = Theme.of(context).colorScheme;
    final f = tracker.fraction ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Galan: ${tracker.total}$unit',
          key: Key('tracker-value-$id'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text('Bu gün: $today · Tamamlanan: ${_percent(f)}'),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: f),
        const SizedBox(height: 4),
        for (final (i, item) in tracker.items.indexed)
          Row(
            children: [
              Expanded(child: Text(item.label)),
              TextButton(
                key: Key('tracker-amount-$id-$i'),
                onPressed: () => onAmount(i),
                child: Text(
                  '${item.value}',
                  key: Key('tracker-item-$id-$i'),
                  style: TextStyle(
                    fontSize: 15,
                    color: item.value == 0 ? colors.primary : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: Key('tracker-undo-$id-$i'),
                tooltip: '${item.label}: yza al',
                onPressed: item.value < (item.target ?? 0)
                    ? () => onRecord(i, -1)
                    : null,
                icon: const Icon(Icons.undo, size: 20),
              ),
              IconButton.filledTonal(
                key: Key('tracker-done-$id-$i'),
                tooltip: '${item.label}: kaza edildi',
                onPressed: item.value > 0 ? () => onRecord(i, 1) : null,
                icon: const Icon(Icons.check, size: 20),
              ),
            ],
          ),
      ],
    );
  }

  Widget habit(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final start = DateTime(now.year, now.month, now.day);
    final week = [
      for (var i = 6; i >= 0; i--)
        DateTime(start.year, start.month, start.day - i),
    ];
    final doneToday = tracker.today(now) > 0;
    final streak = tracker.streak(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Yzygiderlilik: $streak gün',
          key: Key('tracker-value-$id'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final day in week)
              Builder(
                builder: (context) {
                  final done = tracker.today(day) > 0;
                  // Seven fixed days share the width; large text scales the
                  // whole day down instead of overflowing narrow phones.
                  return Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        children: [
                          Text(
                            _weekdays[day.weekday - 1],
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Semantics(
                            button: true,
                            selected: done,
                            label: '${day.day}.${day.month}',
                            child: InkResponse(
                              key: Key('tracker-day-$id-${dayKey(day)}'),
                              onTap: () => onToggleDay(day),
                              radius: 22,
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: done
                                    ? colors.primary
                                    : colors.surfaceContainerHighest,
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: done
                                        ? colors.onPrimary
                                        : colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        doneToday
            ? FilledButton.tonalIcon(
                key: Key('tracker-today-$id'),
                onPressed: () => onToggleDay(now),
                icon: const Icon(Icons.check),
                label: const Text('Bu gün edildi'),
              )
            : FilledButton.icon(
                key: Key('tracker-today-$id'),
                onPressed: () => onToggleDay(now),
                icon: const Icon(Icons.radio_button_unchecked),
                label: const Text('Bu gün belle'),
              ),
      ],
    );
  }
}

/// Owns its text controller so it outlives the dialog's exit animation.
class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.tracker, required this.item});
  final Tracker tracker;
  final int item;
  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit(int sign) {
    final n = int.tryParse(controller.text.trim());
    if (n == null || n <= 0 || n > trackerMaxValue) return;
    Navigator.pop(context, sign * n);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tracker;
    final debt = t.kind == TrackerKind.debt;
    final label = t.items[widget.item].label;
    return AlertDialog(
      title: Text(label.isEmpty ? t.name : label),
      content: TextField(
        key: const Key('amount-field'),
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: t.unit.isEmpty ? 'San' : 'San (${t.unit})',
        ),
        onSubmitted: (_) => submit(1),
      ),
      actions: [
        TextButton(
          key: const Key('amount-subtract'),
          onPressed: () => submit(-1),
          child: Text(debt ? 'Bergä goş' : 'Aýyr'),
        ),
        FilledButton(
          key: const Key('amount-add'),
          onPressed: () => submit(1),
          child: Text(debt ? 'Kaza edildi' : 'Goş'),
        ),
      ],
    );
  }
}
