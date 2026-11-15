import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

// ---------------------------------------------------------------------------
// Options de personnalisation
// ---------------------------------------------------------------------------

const List<Color> kPalette = [
  Color(0xFF6750A4), // violet
  Color(0xFFE91E63), // rose
  Color(0xFFF44336), // rouge
  Color(0xFFFF9800), // orange
  Color(0xFFFFC107), // jaune
  Color(0xFF4CAF50), // vert
  Color(0xFF009688), // turquoise
  Color(0xFF2196F3), // bleu
  Color(0xFF3F51B5), // indigo
  Color(0xFF795548), // marron
  Color(0xFF607D8B), // gris-bleu
  Color(0xFF212121), // noir
];

// Nom affiché -> police système Android (null = police par défaut).
const Map<String, String?> kFonts = {
  'Classique': null,
  'Élégante': 'serif',
  'Machine': 'monospace',
  'Condensée': 'sans-serif-condensed',
  'Manuscrite': 'cursive',
};

// ---------------------------------------------------------------------------
// Modèle de données
// ---------------------------------------------------------------------------

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Task {
  Task({
    required this.id,
    required this.title,
    required this.date,
    this.time,
    this.done = false,
  });

  final String id;
  final String title;
  final DateTime date;
  final String? time; // "HH:mm"
  bool done;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': dateKey(date),
        'time': time,
        'done': done,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        date: DateTime.parse(j['date'] as String),
        time: j['time'] as String?,
        done: (j['done'] as bool?) ?? false,
      );
}

// ---------------------------------------------------------------------------
// Stockage des tâches (sur le téléphone, rien n'est envoyé en ligne)
// ---------------------------------------------------------------------------

class TaskStore extends ChangeNotifier {
  final List<Task> tasks = [];
  late SharedPreferences _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p.getString('tasks');
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      tasks
        ..clear()
        ..addAll(list.map((e) => Task.fromJson(e as Map<String, dynamic>)));
    } catch (_) {
      // Données illisibles : on repart de zéro plutôt que de planter.
    }
  }

  List<Task> forDay(DateTime d) {
    final k = dateKey(d);
    final list = tasks.where((t) => dateKey(t.date) == k).toList();
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return (a.time ?? '99:99').compareTo(b.time ?? '99:99');
    });
    return list;
  }

  Future<void> _persist() async {
    notifyListeners();
    await _p.setString(
      'tasks',
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> upsert(Task t) async {
    final i = tasks.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      tasks[i] = t;
    } else {
      tasks.add(t);
    }
    await _persist();
  }

  Future<void> toggle(Task t) async {
    t.done = !t.done;
    await _persist();
  }

  Future<void> remove(Task t) async {
    tasks.removeWhere((x) => x.id == t.id);
    await _persist();
  }
}

// ---------------------------------------------------------------------------
// Réglages d'apparence
// ---------------------------------------------------------------------------

class AppSettings extends ChangeNotifier {
  int colorIndex = 0;
  int fontIndex = 0;
  ThemeMode mode = ThemeMode.system;
  double radius = 16;
  double overlay = 0.55; // opacité du voile posé sur l'image de fond
  String? backgroundPath;

  late SharedPreferences _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    colorIndex =
        (_p.getInt('colorIndex') ?? 0).clamp(0, kPalette.length - 1).toInt();
    fontIndex =
        (_p.getInt('fontIndex') ?? 0).clamp(0, kFonts.length - 1).toInt();
    mode = ThemeMode.values[(_p.getInt('mode') ?? 0).clamp(0, 2).toInt()];
    radius = _p.getDouble('radius') ?? 16;
    overlay = _p.getDouble('overlay') ?? 0.55;
    final bg = _p.getString('bg');
    if (bg != null && File(bg).existsSync()) backgroundPath = bg;
  }

  void setColor(int i) {
    colorIndex = i;
    _p.setInt('colorIndex', i);
    notifyListeners();
  }

  void setFont(int i) {
    fontIndex = i;
    _p.setInt('fontIndex', i);
    notifyListeners();
  }

  void setMode(ThemeMode m) {
    mode = m;
    _p.setInt('mode', m.index);
    notifyListeners();
  }

  void setRadius(double v) {
    radius = v;
    _p.setDouble('radius', v);
    notifyListeners();
  }

  void setOverlay(double v) {
    overlay = v;
    _p.setDouble('overlay', v);
    notifyListeners();
  }

  Future<void> pickBackground() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest =
        '${dir.path}/fond_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy(dest);
    final old = backgroundPath;
    backgroundPath = dest;
    await _p.setString('bg', dest);
    if (old != null) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> clearBackground() async {
    final old = backgroundPath;
    backgroundPath = null;
    await _p.remove('bg');
    if (old != null) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Application
// ---------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  final settings = AppSettings();
  final store = TaskStore();
  await settings.load();
  await store.load();
  runApp(PlanningApp(settings: settings, store: store));
}

class PlanningApp extends StatelessWidget {
  const PlanningApp({super.key, required this.settings, required this.store});

  final AppSettings settings;
  final TaskStore store;

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: kPalette[settings.colorIndex],
      brightness: brightness,
    );
    final radius = BorderRadius.circular(settings.radius);
    final shape = RoundedRectangleBorder(borderRadius: radius);
    final hasBg = settings.backgroundPath != null;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: kFonts.values.elementAt(settings.fontIndex),
      scaffoldBackgroundColor: hasBg ? Colors.transparent : null,
      appBarTheme: AppBarTheme(
        backgroundColor: hasBg ? Colors.transparent : null,
        scrolledUnderElevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(shape: shape),
      filledButtonTheme:
          FilledButtonThemeData(style: FilledButton.styleFrom(shape: shape)),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: shape),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(settings.radius)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Mon planning',
          debugShowCheckedModeBanner: false,
          locale: const Locale('fr', 'FR'),
          supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: settings.mode,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          builder: (context, child) {
            final bg = settings.backgroundPath;
            if (bg == null) return child!;
            final scheme = Theme.of(context).colorScheme;
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(bg),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
                ColoredBox(
                  color: scheme.surface
                      .withAlpha((settings.overlay * 255).round()),
                ),
                child!,
              ],
            );
          },
          home: HomeScreen(settings: settings, store: store),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Écran principal : calendrier + tâches du jour
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings, required this.store});

  final AppSettings settings;
  final TaskStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  Future<void> _editTask(Task? existing) async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TaskForm(task: existing, initialDate: _selected),
    );
    if (result != null) await widget.store.upsert(result);
  }

  String _capitalized(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _tile(Task t, ColorScheme scheme, double radius, bool hasBg) {
    final borderRadius = BorderRadius.circular(radius);
    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: borderRadius,
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) {
        widget.store.remove(t);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: const Text('Tâche supprimée'),
              action: SnackBarAction(
                label: 'Annuler',
                onPressed: () => widget.store.upsert(t),
              ),
            ),
          );
      },
      child: Material(
        color: scheme.surfaceContainerHighest.withAlpha(hasBg ? 210 : 255),
        borderRadius: borderRadius,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          leading: Checkbox(
            value: t.done,
            onChanged: (_) => widget.store.toggle(t),
          ),
          title: Text(
            t.title,
            style: TextStyle(
              decoration: t.done ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: t.time == null ? null : Text(t.time!),
          onTap: () => _editTask(t),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = widget.settings.radius;
    final hasBg = widget.settings.backgroundPath != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon planning'),
        actions: [
          IconButton(
            tooltip: "Aujourd'hui",
            icon: const Icon(Icons.today),
            onPressed: () => setState(() {
              _focused = DateTime.now();
              _selected = DateTime.now();
            }),
          ),
          IconButton(
            tooltip: 'Personnaliser',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(settings: widget.settings),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editTask(null),
        icon: const Icon(Icons.add),
        label: const Text('Tâche'),
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final tasks = widget.store.forDay(_selected);
          final doneCount = tasks.where((t) => t.done).length;
          return Column(
            children: [
              TableCalendar<Task>(
                locale: 'fr_FR',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: _focused,
                calendarFormat: _format,
                startingDayOfWeek: StartingDayOfWeek.monday,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Mois',
                  CalendarFormat.twoWeeks: '2 sem.',
                  CalendarFormat.week: 'Semaine',
                },
                selectedDayPredicate: (d) => isSameDay(d, _selected),
                eventLoader: (d) => widget.store.forDay(d),
                onDaySelected: (selected, focused) => setState(() {
                  _selected = selected;
                  _focused = focused;
                }),
                onFormatChanged: (f) => setState(() => _format = f),
                onPageChanged: (focused) => _focused = focused,
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonShowsNext: false,
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(color: scheme.onPrimary),
                  todayDecoration: BoxDecoration(
                    color: scheme.primary.withAlpha(90),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(color: scheme.onSurface),
                  markerDecoration: BoxDecoration(
                    color: scheme.tertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _capitalized(
                          DateFormat('EEEE d MMMM', 'fr_FR').format(_selected),
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (tasks.isNotEmpty) Text('$doneCount/${tasks.length}'),
                  ],
                ),
              ),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(child: Text('Rien de prévu ce jour-là.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _tile(tasks[i], scheme, radius, hasBg),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Formulaire d'ajout / modification d'une tâche
// ---------------------------------------------------------------------------

class TaskForm extends StatefulWidget {
  const TaskForm({super.key, this.task, required this.initialDate});

  final Task? task;
  final DateTime initialDate;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  late final TextEditingController _title;
  late DateTime _date;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _date = t?.date ?? widget.initialDate;
    final time = t?.time;
    if (time != null) {
      final parts = time.split(':');
      _time = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String? _timeString() {
    final t = _time;
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _time = t);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      Task(
        id: widget.task?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        date: DateTime(_date.year, _date.month, _date.day),
        time: _timeString(),
        done: widget.task?.done ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Que veux-tu planifier ?',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('EEE d MMM', 'fr_FR').format(_date)),
                  onPressed: _pickDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(_timeString() ?? 'Heure'),
                  onPressed: _pickTime,
                ),
              ),
            ],
          ),
          if (_time != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _time = null),
                child: const Text("Retirer l'heure"),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Écran de personnalisation
// ---------------------------------------------------------------------------

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final AppSettings settings;

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personnaliser')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final bg = settings.backgroundPath;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              _section(context, 'Couleur principale'),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < kPalette.length; i++)
                    GestureDetector(
                      onTap: () => settings.setColor(i),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: kPalette[i],
                        child: settings.colorIndex == i
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
              _section(context, 'Thème'),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Clair')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Sombre')),
                ],
                selected: {settings.mode},
                onSelectionChanged: (s) => settings.setMode(s.first),
              ),
              _section(context, 'Police'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < kFonts.length; i++)
                    ChoiceChip(
                      label: Text(
                        kFonts.keys.elementAt(i),
                        style: TextStyle(fontFamily: kFonts.values.elementAt(i)),
                      ),
                      selected: settings.fontIndex == i,
                      onSelected: (_) => settings.setFont(i),
                    ),
                ],
              ),
              _section(context, 'Arrondi des formes'),
              Slider(
                value: settings.radius,
                min: 0,
                max: 32,
                divisions: 8,
                label: settings.radius.round().toString(),
                onChanged: settings.setRadius,
              ),
              _section(context, 'Image de fond'),
              if (bg != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(settings.radius),
                    child: Image.file(
                      File(bg),
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: settings.pickBackground,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(bg == null ? 'Choisir une image' : 'Changer'),
                  ),
                  const SizedBox(width: 8),
                  if (bg != null)
                    TextButton(
                      onPressed: settings.clearBackground,
                      child: const Text('Retirer'),
                    ),
                ],
              ),
              if (bg != null) ...[
                _section(context, "Voile sur l'image"),
                Slider(
                  value: settings.overlay,
                  min: 0.2,
                  max: 0.9,
                  onChanged: settings.setOverlay,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
