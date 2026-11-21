/// User-defined personal trackers (Hasaplar). Pure, immutable and fully
/// validated: [decodeTrackers] rejects anything it cannot represent exactly
/// instead of guessing, so corrupt storage or a bad backup never silently
/// replaces the user's numbers.
library;

enum TrackerKind {
  /// Count up, optional round target (tesbih).
  counter('counter', 'Sanagyç'),

  /// Progress toward a required total (book pages, hatym).
  progress('progress', 'Maksada çenli'),

  /// Several remaining debts counted down (kaza namazlary).
  debt('debt', 'Bergi'),

  /// Done / not done once per day, with a streak.
  habit('habit', 'Gündelik endik');

  const TrackerKind(this.id, this.label);
  final String id, label;

  static TrackerKind? byId(Object? id) {
    for (final k in values) {
      if (k.id == id) return k;
    }
    return null;
  }
}

/// Upper bound for every stored number; keeps JSON and arithmetic exact.
const trackerMaxValue = 10000000;
const trackerMaxItems = 20;
const trackerMaxNameLength = 60;

class TrackerItem {
  const TrackerItem({required this.label, required this.value, this.target});

  final String label;

  /// counter: count · progress: done · debt: remaining.
  final int value;

  /// counter: optional round · progress: required total · debt: initial total.
  final int? target;

  TrackerItem copyWith({String? label, int? value, int? target}) => TrackerItem(
    label: label ?? this.label,
    value: value ?? this.value,
    target: target ?? this.target,
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    if (target != null) 'target': target,
  };
}

/// Local calendar day key, e.g. 2026-11-22.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final _dayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

class Tracker {
  const Tracker({
    required this.id,
    required this.name,
    required this.kind,
    this.unit = '',
    this.step = 1,
    this.items = const [],
    this.days = const {},
    this.createdAt = 0,
  });

  final String id, name, unit;
  final TrackerKind kind;
  final int step, createdAt;
  final List<TrackerItem> items;

  /// Positive activity per local day (pages read, prayers made up, taps, 1
  /// for a done habit). Drives "Bu gün" and the streak.
  final Map<String, int> days;

  Tracker copyWith({
    String? name,
    String? unit,
    int? step,
    List<TrackerItem>? items,
    Map<String, int>? days,
  }) => Tracker(
    id: id,
    name: name ?? this.name,
    kind: kind,
    unit: unit ?? this.unit,
    step: step ?? this.step,
    items: items ?? this.items,
    days: days ?? this.days,
    createdAt: createdAt,
  );

  int today(DateTime now) => days[dayKey(now)] ?? 0;

  int get total => items.fold(0, (a, i) => a + i.value);
  int get totalTarget => items.fold(0, (a, i) => a + (i.target ?? 0));

  /// 0..1, or null when there is no meaningful target.
  double? get fraction {
    switch (kind) {
      case TrackerKind.progress:
        final t = totalTarget;
        return t <= 0 ? null : (total / t).clamp(0.0, 1.0);
      case TrackerKind.debt:
        final t = totalTarget;
        return t <= 0 ? null : ((t - total) / t).clamp(0.0, 1.0);
      case TrackerKind.counter:
        final t = items.isEmpty ? null : items.first.target;
        if (t == null || t <= 0) return null;
        final v = items.first.value;
        // A completed round shows full until the next tap starts a new one.
        return v == 0 ? 0 : ((v - 1) % t + 1) / t;
      case TrackerKind.habit:
        return null;
    }
  }

  /// Consecutive active days ending today, or yesterday while today is open.
  int streak(DateTime now) {
    var day = DateTime(now.year, now.month, now.day);
    if ((days[dayKey(day)] ?? 0) <= 0) {
      day = day.subtract(const Duration(days: 1));
    }
    var n = 0;
    while ((days[dayKey(day)] ?? 0) > 0) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return n;
  }

  Map<String, int> _logged(int amount, DateTime now) {
    final key = dayKey(now);
    final next = Map<String, int>.of(days);
    final value = ((next[key] ?? 0) + amount).clamp(0, trackerMaxValue);
    if (value == 0) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return next;
  }

  /// Records [amount] units of activity on [item]. Negative amounts correct
  /// mistakes. Values never leave their valid range.
  Tracker record(int item, int amount, DateTime now) {
    if (kind == TrackerKind.habit || item < 0 || item >= items.length) {
      return this;
    }
    final current = items[item];
    final int next;
    switch (kind) {
      case TrackerKind.counter:
        next = (current.value + amount).clamp(0, trackerMaxValue);
      case TrackerKind.progress:
        next = (current.value + amount).clamp(0, current.target ?? 0);
      case TrackerKind.debt:
        next = (current.value - amount).clamp(0, trackerMaxValue);
      case TrackerKind.habit:
        return this;
    }
    final applied = kind == TrackerKind.debt
        ? current.value - next
        : next - current.value;
    if (applied == 0) return this;
    return copyWith(
      items: [
        for (var i = 0; i < items.length; i++)
          i == item ? current.copyWith(value: next) : items[i],
      ],
      days: _logged(applied, now),
    );
  }

  /// Habit only: marks or unmarks [now]'s day.
  Tracker toggleDay(DateTime now) {
    if (kind != TrackerKind.habit) return this;
    final key = dayKey(now);
    final next = Map<String, int>.of(days);
    if (next.remove(key) == null) next[key] = 1;
    return copyWith(days: next);
  }

  /// Counter only: starts a new round; the day log is kept.
  Tracker resetCount() => kind != TrackerKind.counter || items.isEmpty
      ? this
      : copyWith(items: [items.first.copyWith(value: 0)]);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.id,
    'unit': unit,
    'step': step,
    'createdAt': createdAt,
    'items': [for (final i in items) i.toJson()],
    'days': days,
  };

  /// Null when this tracker is not internally consistent.
  static String? problem(Tracker t) {
    bool okInt(int? v) => v == null || (v >= 0 && v <= trackerMaxValue);
    if (t.id.isEmpty || t.id.length > 64) return 'id';
    if (t.name.trim().isEmpty || t.name.length > trackerMaxNameLength) {
      return 'name';
    }
    if (t.unit.length > 30) return 'unit';
    if (t.step < 1 || t.step > trackerMaxValue) return 'step';
    if (t.items.length > trackerMaxItems) return 'items';
    for (final i in t.items) {
      if (i.label.length > trackerMaxNameLength) return 'item label';
      if (!okInt(i.value) || !okInt(i.target)) return 'item value';
    }
    switch (t.kind) {
      case TrackerKind.counter:
        if (t.items.length != 1) return 'counter items';
        final target = t.items.first.target;
        if (target != null && target < 1) return 'counter target';
      case TrackerKind.progress:
        if (t.items.length != 1) return 'progress items';
        final i = t.items.first;
        if (i.target == null || i.target! < 1 || i.value > i.target!) {
          return 'progress target';
        }
      case TrackerKind.debt:
        if (t.items.isEmpty) return 'debt items';
        for (final i in t.items) {
          if (i.label.trim().isEmpty) return 'debt label';
          if (i.target == null || i.value > i.target!) return 'debt target';
        }
      case TrackerKind.habit:
        if (t.items.isNotEmpty) return 'habit items';
    }
    for (final e in t.days.entries) {
      if (!_dayPattern.hasMatch(e.key) || e.value < 1 || !okInt(e.value)) {
        return 'days';
      }
    }
    return null;
  }

  static Map<String, int> _days(Map<dynamic, dynamic> raw) {
    final days = <String, int>{};
    for (final e in raw.entries) {
      if (e.key is! String || e.value is! int) {
        throw const FormatException('day');
      }
      days[e.key as String] = e.value as int;
    }
    return days;
  }

  static Tracker fromJson(Object? json) {
    if (json is! Map) throw const FormatException('tracker');
    T field<T>(String key) {
      final v = json[key];
      if (v is! T) throw FormatException(key);
      return v;
    }

    final kind = TrackerKind.byId(json['kind']);
    if (kind == null) throw const FormatException('kind');
    final rawItems = field<List<dynamic>>('items');
    final rawDays = field<Map<dynamic, dynamic>>('days');
    final tracker = Tracker(
      id: field<String>('id'),
      name: field<String>('name'),
      kind: kind,
      unit: field<String>('unit'),
      step: field<int>('step'),
      createdAt: field<int>('createdAt'),
      items: [
        for (final raw in rawItems)
          if (raw is Map &&
              raw['label'] is String &&
              raw['value'] is int &&
              (raw['target'] == null || raw['target'] is int))
            TrackerItem(
              label: raw['label'] as String,
              value: raw['value'] as int,
              target: raw['target'] as int?,
            )
          else
            throw const FormatException('item'),
      ],
      days: _days(rawDays),
    );
    final issue = problem(tracker);
    if (issue != null) throw FormatException(issue);
    return tracker;
  }
}

const trackerSchemaVersion = 1;
const trackerFormat = 'kuran-kitaphanasy-hasaplar';

Map<String, dynamic> encodeTrackers(List<Tracker> trackers) => {
  'format': trackerFormat,
  'version': trackerSchemaVersion,
  'trackers': [for (final t in trackers) t.toJson()],
};

/// Strict inverse of [encodeTrackers]; throws [FormatException] otherwise.
List<Tracker> decodeTrackers(Object? json) {
  if (json is! Map ||
      json['format'] != trackerFormat ||
      json['version'] != trackerSchemaVersion ||
      json['trackers'] is! List) {
    throw const FormatException('envelope');
  }
  final list = [for (final t in json['trackers'] as List) Tracker.fromJson(t)];
  if (list.map((t) => t.id).toSet().length != list.length) {
    throw const FormatException('duplicate id');
  }
  return list;
}

/// Prayer rows for a kaza namaz tracker (Hanafi: witr is made up too).
const kazaPrayers = ['Ertir', 'Öýle', 'Ikindi', 'Agşam', 'Ýassy', 'Witr'];

/// Ready-made starting points; every field stays editable.
class TrackerTemplate {
  const TrackerTemplate({
    required this.key,
    required this.title,
    required this.description,
    required this.kind,
    required this.name,
    this.unit = '',
    this.step = 1,
    this.target,
    this.labels = const [],
  });

  final String key, title, description, name, unit;
  final TrackerKind kind;
  final int step;
  final int? target;
  final List<String> labels;
}

const trackerTemplates = [
  TrackerTemplate(
    key: 'kaza',
    title: 'Kaza namazlary',
    description: 'Her wagt üçin galan namazlar; okanyňyzda azalýar.',
    kind: TrackerKind.debt,
    name: 'Kaza namazlary',
    unit: 'namaz',
    labels: kazaPrayers,
  ),
  TrackerTemplate(
    key: 'book',
    title: 'Kitap okamak',
    description: 'Okan sahypalaryňyz we kitabyň tamamlanyşy.',
    kind: TrackerKind.progress,
    name: 'Kitap okamak',
    unit: 'sahypa',
    step: 10,
    target: 300,
  ),
  TrackerTemplate(
    key: 'hatym',
    title: 'Hatym',
    description: 'Kurany Kerimi 604 sahypa boýunça tamamlamak.',
    kind: TrackerKind.progress,
    name: 'Hatym',
    unit: 'sahypa',
    step: 20,
    target: 604,
  ),
  TrackerTemplate(
    key: 'tesbih',
    title: 'Tesbih',
    description: 'Her basanyňyzda bir sanalýar; maksat 33.',
    kind: TrackerKind.counter,
    name: 'Tesbih',
    unit: 'gezek',
    target: 33,
  ),
  TrackerTemplate(
    key: 'habit',
    title: 'Gündelik endik',
    description: 'Oraza, sadaka ýaly her gün belleýän işiňiz.',
    kind: TrackerKind.habit,
    name: 'Gündelik endik',
  ),
];
