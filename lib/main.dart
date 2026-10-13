import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

const String appName = 'BIEHLER JEAN';
const String supportEmail = 'support@biehlerjean.com';

const Color brandInk = Color(0xFF1C3243);
const Color brandTeal = Color(0xFF2C7A7B);
const Color brandGold = Color(0xFFC58F2A);
const Color brandMist = Color(0xFFF4F7F2);
const Color brandLine = Color(0xFFD9E3DA);

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.screenshotMode = const bool.fromEnvironment('SCREENSHOT_MODE'),
  });

  final bool screenshotMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: OperationsHome(screenshotMode: screenshotMode),
    );
  }
}

ThemeData _buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandTeal,
    brightness: Brightness.light,
    primary: brandInk,
    secondary: brandTeal,
    tertiary: brandGold,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brandMist,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: brandMist,
      foregroundColor: brandInk,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: brandLine),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandInk,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: brandTeal, width: 1.4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: brandTeal.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: brandInk,
        ),
      ),
    ),
  );
}

enum OperationKind { payroll, appointment, compliance, procurement }

enum RecordStatus { open, scheduled, review, closed }

extension OperationKindDetails on OperationKind {
  String get label {
    return switch (this) {
      OperationKind.payroll => 'Payroll',
      OperationKind.appointment => 'Appointment',
      OperationKind.compliance => 'Compliance',
      OperationKind.procurement => 'Procurement',
    };
  }

  IconData get icon {
    return switch (this) {
      OperationKind.payroll => Icons.payments_outlined,
      OperationKind.appointment => Icons.event_available_outlined,
      OperationKind.compliance => Icons.fact_check_outlined,
      OperationKind.procurement => Icons.inventory_2_outlined,
    };
  }
}

extension RecordStatusDetails on RecordStatus {
  String get label {
    return switch (this) {
      RecordStatus.open => 'Open',
      RecordStatus.scheduled => 'Scheduled',
      RecordStatus.review => 'In review',
      RecordStatus.closed => 'Closed',
    };
  }
}

OperationKind _parseKind(String? value) {
  return OperationKind.values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => OperationKind.procurement,
  );
}

RecordStatus _parseStatus(String? value) {
  return RecordStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => RecordStatus.open,
  );
}

class OperationRecord {
  const OperationRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.owner,
    required this.dueDate,
    required this.status,
    required this.value,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final OperationKind kind;
  final String title;
  final String owner;
  final DateTime dueDate;
  final RecordStatus status;
  final String value;
  final String notes;
  final DateTime createdAt;

  OperationRecord copyWith({RecordStatus? status, String? notes}) {
    return OperationRecord(
      id: id,
      kind: kind,
      title: title,
      owner: owner,
      dueDate: dueDate,
      status: status ?? this.status,
      value: value,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'title': title,
      'owner': owner,
      'dueDate': dueDate.toIso8601String(),
      'status': status.name,
      'value': value,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory OperationRecord.fromJson(Map<String, Object?> json) {
    return OperationRecord(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      kind: _parseKind(json['kind'] as String?),
      title: json['title'] as String? ?? 'Operations request',
      owner: json['owner'] as String? ?? 'Unassigned',
      dueDate:
          DateTime.tryParse(json['dueDate'] as String? ?? '') ?? DateTime.now(),
      status: _parseStatus(json['status'] as String?),
      value: json['value'] as String? ?? 'Internal',
      notes: json['notes'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class OperationsStore {
  OperationsStore({required this.screenshotMode});

  static const String _recordsKey = 'biehler_records_v1';

  final bool screenshotMode;

  Future<List<OperationRecord>> loadRecords() async {
    if (screenshotMode) {
      return sampleRecords();
    }

    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_recordsKey);
    if (raw == null || raw.isEmpty) {
      return sampleRecords(seedOnly: true);
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return sampleRecords(seedOnly: true);
    }

    return decoded
        .whereType<Map>()
        .map(
          (entry) => OperationRecord.fromJson(Map<String, Object?>.from(entry)),
        )
        .toList();
  }

  Future<void> saveRecords(List<OperationRecord> records) async {
    if (screenshotMode) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      records.map((record) => record.toJson()).toList(),
    );
    await preferences.setString(_recordsKey, payload);
  }

  Future<void> clear() async {
    if (screenshotMode) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_recordsKey);
  }
}

List<OperationRecord> sampleRecords({bool seedOnly = false}) {
  final now = DateTime(2026, 5, 12, 9);
  final records = <OperationRecord>[
    OperationRecord(
      id: 'payroll-may-close',
      kind: OperationKind.payroll,
      title: 'BIEHLER JEAN',
      owner: 'Payroll desk',
      dueDate: now.add(const Duration(days: 2)),
      status: RecordStatus.review,
      value: '34 employees',
      notes: 'Review overtime deltas before the finance handoff.',
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    OperationRecord(
      id: 'supplier-badges',
      kind: OperationKind.procurement,
      title: 'Supplier badge printer order',
      owner: 'Front office',
      dueDate: now.add(const Duration(days: 5)),
      status: RecordStatus.open,
      value: 'USD 420',
      notes: 'Replace badge stock and ink before the June intake.',
      createdAt: now.subtract(const Duration(hours: 12)),
    ),
    OperationRecord(
      id: 'vendor-meeting',
      kind: OperationKind.appointment,
      title: 'Vendor renewal appointment',
      owner: 'Operations lead',
      dueDate: now.add(const Duration(days: 1)),
      status: RecordStatus.scheduled,
      value: '10:30 AM',
      notes: 'Prepare contract summary and renewal options.',
      createdAt: now.subtract(const Duration(days: 2)),
    ),
    OperationRecord(
      id: 'safety-register',
      kind: OperationKind.compliance,
      title: 'Quarterly compliance register',
      owner: 'Compliance desk',
      dueDate: now.add(const Duration(days: 12)),
      status: RecordStatus.review,
      value: 'Q2 file',
      notes: 'Attach incident log and procurement declarations.',
      createdAt: now.subtract(const Duration(days: 3)),
    ),
  ];

  if (seedOnly) {
    return records.take(2).toList();
  }

  return records;
}

class OperationsHome extends StatefulWidget {
  const OperationsHome({super.key, required this.screenshotMode});

  final bool screenshotMode;

  @override
  State<OperationsHome> createState() => _OperationsHomeState();
}

class _OperationsHomeState extends State<OperationsHome> {
  late final OperationsStore _store = OperationsStore(
    screenshotMode: widget.screenshotMode,
  );

  var _selectedIndex = 0;
  var _loading = true;
  var _records = <OperationRecord>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await _store.loadRecords();
    if (!mounted) {
      return;
    }

    setState(() {
      _records = loaded;
      _loading = false;
    });
  }

  Future<void> _persist() => _store.saveRecords(_records);

  Future<void> _openNewRecordSheet([OperationKind? initialKind]) async {
    final record = await showModalBottomSheet<OperationRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecordFormSheet(initialKind: initialKind),
    );

    if (record == null || !mounted) {
      return;
    }

    setState(() {
      _records = [record, ..._records];
      _selectedIndex = 1;
    });
    await _persist();
  }

  Future<void> _replaceRecord(OperationRecord updated) async {
    setState(() {
      _records = [
        for (final record in _records)
          record.id == updated.id ? updated : record,
      ];
    });
    await _persist();
  }

  Future<void> _clearWorkspace() async {
    await _store.clear();
    if (!mounted) {
      return;
    }

    setState(() {
      _records = widget.screenshotMode ? sampleRecords() : <OperationRecord>[];
    });
  }

  void _openDetail(OperationRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            RecordDetailPage(record: record, onChanged: _replaceRecord),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        records: _records,
        loading: _loading,
        onCreate: _openNewRecordSheet,
        onOpenRecord: _openDetail,
      ),
      RequestsScreen(
        records: _records,
        loading: _loading,
        onCreate: _openNewRecordSheet,
        onOpenRecord: _openDetail,
      ),
      ReportsScreen(records: _records, loading: _loading),
      SettingsScreen(
        records: _records,
        screenshotMode: widget.screenshotMode,
        onClear: _clearWorkspace,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actions: [
          IconButton(
            tooltip: 'New request',
            onPressed: () => _openNewRecordSheet(),
            icon: const Icon(Icons.add_task_outlined),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              key: const Key('new-request-button'),
              onPressed: () => _openNewRecordSheet(),
              icon: const Icon(Icons.add),
              label: const Text('New request'),
            )
          : null,
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.records,
    required this.loading,
    required this.onCreate,
    required this.onOpenRecord,
  });

  final List<OperationRecord> records;
  final bool loading;
  final ValueChanged<OperationKind?> onCreate;
  final ValueChanged<OperationRecord> onOpenRecord;

  @override
  Widget build(BuildContext context) {
    final openCount = records
        .where((record) => record.status != RecordStatus.closed)
        .length;
    final dueSoon = records.where((record) {
      return record.dueDate.difference(DateTime.now()).inDays <= 7 &&
          record.status != RecordStatus.closed;
    }).length;
    final payrollCount = records
        .where((record) => record.kind == OperationKind.payroll)
        .length;
    final complianceCount = records
        .where((record) => record.kind == OperationKind.compliance)
        .length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _WorkspaceHeader(),
          const SizedBox(height: 16),
          _MetricGrid(
            metrics: [
              MetricData(
                'Open items',
                '$openCount',
                Icons.pending_actions_outlined,
              ),
              MetricData(
                'Due this week',
                '$dueSoon',
                Icons.calendar_month_outlined,
              ),
              MetricData(
                'Payroll files',
                '$payrollCount',
                Icons.payments_outlined,
              ),
              MetricData(
                'Compliance',
                '$complianceCount',
                Icons.verified_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: "Today's operations",
            actionLabel: 'Add',
            onAction: () => onCreate(null),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: OperationKind.values.map((kind) {
              return _QuickActionChip(kind: kind, onTap: () => onCreate(kind));
            }).toList(),
          ),
          const SizedBox(height: 20),
          const _SectionTitle(title: 'Priority queue'),
          const SizedBox(height: 10),
          if (loading)
            const _LoadingPanel()
          else if (records.isEmpty)
            _EmptyPanel(onCreate: () => onCreate(null))
          else
            ...records
                .take(3)
                .map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OperationRecordCard(
                      record: record,
                      onTap: () => onOpenRecord(record),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({
    super.key,
    required this.records,
    required this.loading,
    required this.onCreate,
    required this.onOpenRecord,
  });

  final List<OperationRecord> records;
  final bool loading;
  final ValueChanged<OperationKind?> onCreate;
  final ValueChanged<OperationRecord> onOpenRecord;

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  OperationKind? _filter;

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == null
        ? widget.records
        : widget.records.where((record) => record.kind == _filter).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const _ScreenHeading(
            title: 'Request queue',
            subtitle:
                'Payroll, appointments, compliance, and procurement in one local list.',
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final kind in OperationKind.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(kind.icon, size: 18),
                      label: Text(kind.label),
                      selected: _filter == kind,
                      onSelected: (_) => setState(() => _filter = kind),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (widget.loading)
            const _LoadingPanel()
          else if (filtered.isEmpty)
            _EmptyPanel(onCreate: () => widget.onCreate(_filter))
          else
            ...filtered.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OperationRecordCard(
                  record: record,
                  onTap: () => widget.onOpenRecord(record),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({
    super.key,
    required this.records,
    required this.loading,
  });

  final List<OperationRecord> records;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final total = records.isEmpty ? 1 : records.length;
    final open = records
        .where((record) => record.status == RecordStatus.open)
        .length;
    final review = records
        .where((record) => record.status == RecordStatus.review)
        .length;
    final scheduled = records
        .where((record) => record.status == RecordStatus.scheduled)
        .length;
    final closed = records
        .where((record) => record.status == RecordStatus.closed)
        .length;

    final sorted = [...records]..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _ScreenHeading(
            title: 'Operations reports',
            subtitle:
                'Daily status for deadlines, owners, and outstanding work.',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status mix',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  _ProgressRow(
                    label: 'Open',
                    value: open,
                    total: total,
                    color: brandTeal,
                  ),
                  _ProgressRow(
                    label: 'In review',
                    value: review,
                    total: total,
                    color: brandGold,
                  ),
                  _ProgressRow(
                    label: 'Scheduled',
                    value: scheduled,
                    total: total,
                    color: const Color(0xFF5B67C2),
                  ),
                  _ProgressRow(
                    label: 'Closed',
                    value: closed,
                    total: total,
                    color: brandInk,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'Upcoming deadlines'),
          const SizedBox(height: 10),
          if (loading)
            const _LoadingPanel()
          else if (sorted.isEmpty)
            const _PlainPanel(
              icon: Icons.event_busy_outlined,
              title: 'No deadlines',
              body:
                  'Create a request to start building the operations timeline.',
            )
          else
            ...sorted
                .take(5)
                .map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DeadlineTile(record: record),
                  ),
                ),
          const SizedBox(height: 12),
          const _PlainPanel(
            icon: Icons.privacy_tip_outlined,
            title: 'Local reporting',
            body: 'Reports are calculated on this device from saved requests.',
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.records,
    required this.screenshotMode,
    required this.onClear,
  });

  final List<OperationRecord> records;
  final bool screenshotMode;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _ScreenHeading(
            title: 'Workspace settings',
            subtitle: 'Local controls for the BIEHLER JEAN operations file.',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: brandTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.business_center_outlined,
                          color: brandInk,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text('Operations workspace'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoLine(
                    icon: Icons.storage_outlined,
                    label: 'Stored records',
                    value: '${records.length}',
                  ),
                  const _InfoLine(
                    icon: Icons.lock_outline,
                    label: 'Data location',
                    value: 'On this device',
                  ),
                  const _InfoLine(
                    icon: Icons.wifi_off_outlined,
                    label: 'Accounts and sync',
                    value: 'Not used',
                  ),
                  const _InfoLine(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Device permissions',
                    value: 'None requested',
                  ),
                  const _InfoLine(
                    icon: Icons.mail_outline,
                    label: 'Support',
                    value: supportEmail,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Record controls',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    screenshotMode
                        ? 'Screenshot data is temporary and resets automatically.'
                        : 'Clear saved payroll, appointment, compliance, and procurement records from this device.',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear records'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecordDetailPage extends StatefulWidget {
  const RecordDetailPage({
    super.key,
    required this.record,
    required this.onChanged,
  });

  final OperationRecord record;
  final ValueChanged<OperationRecord> onChanged;

  @override
  State<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> {
  late OperationRecord _record = widget.record;

  void _setStatus(RecordStatus status) {
    final updated = _record.copyWith(status: status);
    setState(() => _record = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request detail')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _KindIcon(kind: _record.kind),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _record.kind.label,
                                style: const TextStyle(
                                  color: brandTeal,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _record.title,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(status: _record.status),
                        _LabelPill(
                          icon: Icons.person_outline,
                          label: _record.owner,
                        ),
                        _LabelPill(
                          icon: Icons.calendar_today_outlined,
                          label: _formatDate(_record.dueDate),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _DetailBlock(label: 'Value', value: _record.value),
                    _DetailBlock(label: 'Notes', value: _record.notes),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Move status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: RecordStatus.values.map((status) {
                        return ChoiceChip(
                          label: Text(status.label),
                          selected: _record.status == status,
                          onSelected: (_) => _setStatus(status),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecordFormSheet extends StatefulWidget {
  const RecordFormSheet({super.key, this.initialKind});

  final OperationKind? initialKind;

  @override
  State<RecordFormSheet> createState() => _RecordFormSheetState();
}

class _RecordFormSheetState extends State<RecordFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _ownerController = TextEditingController();
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();

  late OperationKind _kind = widget.initialKind ?? OperationKind.procurement;
  var _daysUntilDue = 3;

  @override
  void dispose() {
    _titleController.dispose();
    _ownerController.dispose();
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final now = DateTime.now();
    final record = OperationRecord(
      id: 'record-${now.microsecondsSinceEpoch}',
      kind: _kind,
      title: _titleController.text.trim(),
      owner: _ownerController.text.trim(),
      dueDate: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: _daysUntilDue)),
      status: _kind == OperationKind.appointment
          ? RecordStatus.scheduled
          : RecordStatus.open,
      value: _valueController.text.trim().isEmpty
          ? 'Internal'
          : _valueController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? 'Created from the mobile workspace.'
          : _notesController.text.trim(),
      createdAt: now,
    );

    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      height: 4,
                      width: 42,
                      decoration: BoxDecoration(
                        color: brandLine,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'New operations request',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<OperationKind>(
                    key: const Key('kind-field'),
                    initialValue: _kind,
                    decoration: const InputDecoration(
                      labelText: 'Request type',
                    ),
                    items: OperationKind.values.map((kind) {
                      return DropdownMenuItem(
                        value: kind,
                        child: Row(
                          children: [
                            Icon(kind.icon, size: 18),
                            const SizedBox(width: 8),
                            Text(kind.label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _kind = value ?? _kind),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('title-field'),
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Request title',
                      prefixIcon: Icon(Icons.subject_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().length < 3) {
                        return 'Enter a clear title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('owner-field'),
                    controller: _ownerController,
                    decoration: const InputDecoration(
                      labelText: 'Owner or desk',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().length < 2) {
                        return 'Add an owner';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('value-field'),
                    controller: _valueController,
                    decoration: const InputDecoration(
                      labelText: 'Value, count, or time',
                      prefixIcon: Icon(Icons.tag_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('notes-field'),
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Target date',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Today')),
                      ButtonSegment(value: 3, label: Text('3d')),
                      ButtonSegment(value: 7, label: Text('1w')),
                      ButtonSegment(value: 30, label: Text('30d')),
                    ],
                    selected: {_daysUntilDue},
                    onSelectionChanged: (values) {
                      setState(() => _daysUntilDue = values.first);
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('save-request-button'),
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save request'),
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

class OperationRecordCard extends StatelessWidget {
  const OperationRecordCard({
    super.key,
    required this.record,
    required this.onTap,
  });

  final OperationRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KindIcon(kind: record.kind),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(status: record.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _SmallMeta(
                          icon: Icons.business_center_outlined,
                          text: record.kind.label,
                        ),
                        _SmallMeta(
                          icon: Icons.person_outline,
                          text: record.owner,
                        ),
                        _SmallMeta(
                          icon: Icons.calendar_today_outlined,
                          text: _formatDate(record.dueDate),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: brandInk,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(DateTime(2026, 5, 12)),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Business operations board',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Track payroll, bookings, compliance, and purchasing without external services.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: brandGold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.domain_verification_outlined,
              color: brandInk,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 1.48,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) => _MetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class MetricData {
  const MetricData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(metric.icon, color: brandTeal),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.62)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({required this.kind, required this.onTap});

  final OperationKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(kind.icon, size: 18),
      label: Text(kind.label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: brandLine),
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});

  final OperationKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: _kindColor(kind).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(kind.icon, color: _kindColor(kind)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final RecordStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RecordStatus.open => brandTeal,
      RecordStatus.scheduled => const Color(0xFF5B67C2),
      RecordStatus.review => brandGold,
      RecordStatus.closed => brandInk,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LabelPill extends StatelessWidget {
  const _LabelPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: brandLine),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: brandInk),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SmallMeta extends StatelessWidget {
  const _SmallMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.black.withValues(alpha: 0.52)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.62),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _ScreenHeading extends StatelessWidget {
  const _ScreenHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.64),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 12),
            Text('Loading workspace'),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.inbox_outlined, color: brandTeal, size: 32),
            const SizedBox(height: 10),
            const Text(
              'No requests saved',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Create the first operations record for this device.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.64)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('New request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlainPanel extends StatelessWidget {
  const _PlainPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: brandTeal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.64),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = value / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$value',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress.clamp(0, 1),
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({required this.record});

  final OperationRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _KindIcon(kind: record.kind),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.owner} - ${record.value}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDate(record.dueDate),
              style: const TextStyle(
                color: brandInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: brandTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.black.withValues(alpha: 0.66)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: brandTeal,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, height: 1.35)),
        ],
      ),
    );
  }
}

Color _kindColor(OperationKind kind) {
  return switch (kind) {
    OperationKind.payroll => brandInk,
    OperationKind.appointment => const Color(0xFF5B67C2),
    OperationKind.compliance => brandGold,
    OperationKind.procurement => brandTeal,
  };
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}
