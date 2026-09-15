import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_helper.dart';

final currentTotality = TotalityController();

enum AppThemePreference { system, light, dark }

enum AppFontSize {
  small('Small', .85),
  standard('Default', 1),
  large('Large', 1.15),
  extraLarge('Extra Large', 1.3);

  const AppFontSize(this.label, this.scale);
  final String label;
  final double scale;
}

enum ResultsSortOrder {
  highestMarks('Highest marks'),
  highestRubrics('Highest rubrics covered'),
  alphabetical('Alphabetical A-Z');

  final String label;
  const ResultsSortOrder(this.label);
}

class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs);
  final SharedPreferences _prefs;
  AppThemePreference _theme = AppThemePreference.system;
  AppFontSize _fontSize = AppFontSize.standard;
  AppThemePreference get theme => _theme;
  AppFontSize get fontSize => _fontSize;

  void load() {
    _theme = AppThemePreference.values.byName(
      _prefs.getString('theme_preference') ?? 'system',
    );
    _fontSize = AppFontSize.values.byName(
      _prefs.getString('font_size_preference') ?? 'standard',
    );
  }

  Future<void> setTheme(AppThemePreference value) async {
    _theme = value;
    notifyListeners();
    await _prefs.setString('theme_preference', value.name);
  }

  Future<void> setFontSize(AppFontSize value) async {
    _fontSize = value;
    notifyListeners();
    await _prefs.setString('font_size_preference', value.name);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings(await SharedPreferences.getInstance())..load();
  runApp(KentRepertoryApp(settings: settings));
}

class KentRepertoryApp extends StatelessWidget {
  const KentRepertoryApp({super.key, required this.settings});
  final AppSettings settings;

  ThemeData _theme(Brightness brightness) {
    final colors =
        ColorScheme.fromSeed(seedColor: Colors.teal, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
      ),
      cardTheme: CardThemeData(color: colors.surfaceContainerLow),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: settings,
        builder: (context, _) => MaterialApp(
          title: 'KENT REPERTORY FOR STUDENTS',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: switch (settings.theme) {
            AppThemePreference.system => ThemeMode.system,
            AppThemePreference.light => ThemeMode.light,
            AppThemePreference.dark => ThemeMode.dark,
          },
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(settings.fontSize.scale),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          home: RepertorySearchScreen(settings: settings),
        ),
      );
}

class TotalityController extends ChangeNotifier {
  final List<RubricResult> _rubrics = [];
  List<RubricResult> get rubrics => List.unmodifiable(_rubrics);
  bool contains(int rubricId) =>
      _rubrics.any((rubric) => rubric.id == rubricId);

  bool add(RubricResult rubric) {
    if (contains(rubric.id)) return false;
    _rubrics.add(rubric);
    notifyListeners();
    return true;
  }

  void remove(int rubricId) {
    _rubrics.removeWhere((rubric) => rubric.id == rubricId);
    notifyListeners();
  }

  void clear() {
    _rubrics.clear();
    notifyListeners();
  }
}

class RepertorySearchScreen extends StatefulWidget {
  const RepertorySearchScreen({super.key, required this.settings});
  final AppSettings settings;
  @override
  State<RepertorySearchScreen> createState() => _RepertorySearchScreenState();
}

class _RepertorySearchScreenState extends State<RepertorySearchScreen> {
  final _queryController = TextEditingController();
  List<RubricResult> _rubricResults = [];
  bool _searching = false;
  int _searchRequest = 0;

  Future<void> _onSearch(String query) async {
    final request = ++_searchRequest;
    if (query.trim().isEmpty) {
      setState(() {
        _rubricResults = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    try {
      final results = await RepertoryEngine.searchSymptom(query);
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _rubricResults = results;
      });
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted && request == _searchRequest) {
        setState(() => _searching = false);
      }
    }
  }

  void _addRubric(RubricResult rubric) {
    final added = currentTotality.add(rubric);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Added to repertorial totality.'
              : 'That rubric is already in the totality.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('KENT REPERTORY FOR STUDENTS'),
          elevation: 1,
          actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(settings: widget.settings),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: currentTotality,
              builder: (_, __) => IconButton(
                tooltip:
                    'Repertorial totality (${currentTotality.rubrics.length})',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TotalityScreen()),
                ),
                icon: Badge(
                  label: Text('${currentTotality.rubrics.length}'),
                  child: const Icon(Icons.format_list_bulleted),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _queryController,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText:
                      "Enter symptom (e.g. 'Burning pain in head morning')...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _queryController.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator())
                  : _rubricResults.isEmpty
                      ? Center(
                          child: Text(
                            _queryController.text.isEmpty
                                ? 'Type a clinical symptom to search the Kent hierarchy.'
                                : 'No matching rubrics found.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _rubricResults.length,
                          itemBuilder: (_, index) =>
                              _rubricCard(_rubricResults[index]),
                        ),
            ),
          ],
        ),
      );

  Widget _rubricCard(RubricResult item) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chapter: ${item.chapter}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.fullPath,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Page: ${item.pageNumber}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: item.remedies
                      .map(
                        (remedy) => TextSpan(
                          text: '${remedy.abbrev}  ',
                          style: _gradeStyle(remedy.grade),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedBuilder(
                  animation: currentTotality,
                  builder: (_, __) => OutlinedButton.icon(
                    onPressed: currentTotality.contains(item.id)
                        ? null
                        : () => _addRubric(item),
                    icon: Icon(
                      currentTotality.contains(item.id)
                          ? Icons.check
                          : Icons.add,
                    ),
                    label: Text(
                      currentTotality.contains(item.id)
                          ? 'Added'
                          : 'Add to totality',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  TextStyle _gradeStyle(int grade) => grade == 3
      ? TextStyle(
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.error,
        )
      : grade == 2
          ? TextStyle(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            )
          : TextStyle(color: Theme.of(context).colorScheme.onSurface);
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: settings,
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text(
                  'Theme',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...AppThemePreference.values.map(
                (v) => RadioListTile<AppThemePreference>(
                  value: v,
                  groupValue: settings.theme,
                  onChanged: (x) {
                    if (x != null) settings.setTheme(x);
                  },
                  title: Text(switch (v) {
                    AppThemePreference.system => 'System default',
                    AppThemePreference.light => 'Light',
                    AppThemePreference.dark => 'Dark',
                  }),
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Font size',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...AppFontSize.values.map(
                (v) => RadioListTile<AppFontSize>(
                  value: v,
                  groupValue: settings.fontSize,
                  onChanged: (x) {
                    if (x != null) settings.setFontSize(x);
                  },
                  title: Text(v.label),
                ),
              ),
              const Divider(),
              const ListTile(
                title: Text(
                  'KENT REPERTORY FOR STUDENTS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('CREATED BY : CALM HOMOEOPATH'),
              ),
            ],
          ),
        ),
      );
}

class TotalityScreen extends StatelessWidget {
  const TotalityScreen({super.key});

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear repertorial totality?'),
        content: const Text(
          'All selected rubrics will be removed from the current case.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) currentTotality.clear();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: currentTotality,
        builder: (_, __) {
          final rubrics = currentTotality.rubrics;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Repertorial Totality'),
              actions: [
                if (rubrics.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear totality',
                    onPressed: () => _clear(context),
                  ),
              ],
            ),
            body: rubrics.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.playlist_add,
                            size: 56,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No rubrics selected',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Search for a rubric and add it to build the current case.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.search),
                            label: const Text('Add Symptom / Rubric'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          '${rubrics.length} selected rubric${rubrics.length == 1 ? '' : 's'} — numbered in case order.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: rubrics.length,
                          itemBuilder: (_, index) {
                            final rubric = rubrics[index];
                            final sNo = index + 1;
                            return ListTile(
                              leading: CircleAvatar(child: Text('$sNo')),
                              title: Text(
                                'S.No. $sNo — ${rubric.fullPath}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text('Page ${rubric.pageNumber}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                tooltip: 'Remove rubric',
                                onPressed: () =>
                                    currentTotality.remove(rubric.id),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Rubric'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RepertorizationResultsScreen(
                                      rubrics: rubrics,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.calculate),
                                label: const Text('Repertorize'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          );
        },
      );
}

class RepertorizationResultsScreen extends StatefulWidget {
    final List<RubricResult> rubrics;
  const RepertorizationResultsScreen({super.key, required this.rubrics});
  @override
  State<RepertorizationResultsScreen> createState() =>
      _RepertorizationResultsScreenState();
}

class _RepertorizationResultsScreenState
    extends State<RepertorizationResultsScreen> {
  late final Future<List<RepertorizationResult>> _resultsFuture;
  ResultsSortOrder _currentSort = ResultsSortOrder.highestMarks;

  @override
  void initState() {
    super.initState();
    _resultsFuture = RepertoryEngine.repertorize(
      widget.rubrics.map((rubric) => rubric.id).toList(),
    );
  }

  List<RepertorizationResult> _sortList(List<RepertorizationResult> list) {
    final sorted = List<RepertorizationResult>.from(list);
    switch (_currentSort) {
      case ResultsSortOrder.highestMarks:
        sorted.sort((a, b) {
          final cmp = b.totalMarks.compareTo(a.totalMarks);
          if (cmp != 0) return cmp;
          final covCmp = b.rubricsCovered.compareTo(a.rubricsCovered);
          if (covCmp != 0) return covCmp;
          return a.abbreviation
              .toLowerCase()
              .compareTo(b.abbreviation.toLowerCase());
        });
        break;
      case ResultsSortOrder.highestRubrics:
        sorted.sort((a, b) {
          final covCmp = b.rubricsCovered.compareTo(a.rubricsCovered);
          if (covCmp != 0) return covCmp;
          final marksCmp = b.totalMarks.compareTo(a.totalMarks);
          if (marksCmp != 0) return marksCmp;
          return a.abbreviation
              .toLowerCase()
              .compareTo(b.abbreviation.toLowerCase());
        });
        break;
      case ResultsSortOrder.alphabetical:
        sorted.sort((a, b) => a.abbreviation
            .toLowerCase()
            .compareTo(b.abbreviation.toLowerCase()));
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Repertorial Results'),
          actions: [
            PopupMenuButton<ResultsSortOrder>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort remedies',
              initialValue: _currentSort,
              onSelected: (ResultsSortOrder order) {
                setState(() {
                  _currentSort = order;
                });
              },
              itemBuilder: (BuildContext context) => ResultsSortOrder.values
                  .map(
                    (order) => PopupMenuItem<ResultsSortOrder>(
                      value: order,
                      child: Row(
                        children: [
                          Icon(
                            _currentSort == order
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(order.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        body: FutureBuilder<List<RepertorizationResult>>(
          future: _resultsFuture,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Unable to calculate this totality: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final rawResults = snapshot.data ?? [];
            if (rawResults.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No remedies cover the selected rubrics. Return to the totality and adjust the case.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final results = _sortList(rawResults);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Sorted by: ${_currentSort.label}. ${widget.rubrics.length} rubric${widget.rubrics.length == 1 ? '' : 's'} selected.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (_, index) {
                      final result = results[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RemedyDetailScreen(
                                result: result,
                                rubrics: widget.rubrics,
                              ),
                            ),
                          ),
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(
                            result.abbreviation,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${result.totalMarks} marks  •  ${result.rubricsCovered} of ${widget.rubrics.length} rubrics covered',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class RemedyDetailScreen extends StatefulWidget {
  final RepertorizationResult result;
  final List<RubricResult> rubrics;
  const RemedyDetailScreen({
    super.key,
    required this.result,
    required this.rubrics,
  });
  @override
  State<RemedyDetailScreen> createState() => _RemedyDetailScreenState();
}

class _RemedyDetailScreenState extends State<RemedyDetailScreen> {
  late final Future<List<RubricCoverage>> _coverage;

  @override
  void initState() {
    super.initState();
    _coverage = RepertoryEngine.remedyCoverage(
      remedyIds: widget.result.remedyIds,
      rubrics: widget.rubrics,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Remedy Detail')),
        body: FutureBuilder<List<RubricCoverage>>(
          future: _coverage,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Unable to load remedy coverage: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }
            final coverage = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.result.abbreviation,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.result.totalMarks} marks / ${widget.result.rubricsCovered} of ${widget.rubrics.length} rubrics',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Divider(height: 32),
                const Text(
                  'Covered Rubrics & Assigned Marks',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                ...coverage.map(
                  (item) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${item.serialNumber}'),
                      ),
                      title: Text(
                        'S.No. ${item.serialNumber} — ${item.fullPath}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Chip(
                        label: Text(
                          '${item.grade} ${item.grade == 1 ? 'mark' : 'marks'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Total Marks: ${widget.result.totalMarks}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            );
          },
        ),
      );
}
