import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db.dart';
import 'app_state.dart';
import 'models/record.dart';
import 'models/records_model.dart';
import 'month_detail_list.dart';
import 'wallet_page.dart';

void main() {
  // Initialize sqflite ffi for desktop platforms (Windows/Linux/macOS).
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => MyAppState()),
        ChangeNotifierProvider(create: (context) => RecordsModel()),
      ],
      child: Consumer<MyAppState>(
        builder: (context, appState, _) => MaterialApp(
          title: '记账',
          // 强制使用中文本地化（用于日期/时间选择器等）
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN')],
          locale: const Locale('zh', 'CN'),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: appState.seedColor),
          ),
          themeMode: appState.themeMode,
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                brightness: Brightness.dark, seedColor: appState.seedColor),
            brightness: Brightness.dark,
          ),
          home: MyHomePage(),
        ),
      ),
    );
  }
}

// RecordsModel moved to `lib/models/records_model.dart` to avoid circular imports

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;
  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = HomePage();
        break;
      case 1:
        page = WalletPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }
    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        extendBody: true,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            final model = context.read<RecordsModel>();
            // ignore: use_build_context_synchronously
            showDialog(
                context: context,
                builder: (ctx) => AddRecordDialog(onSaved: (record) async {
                      await model.addRecord(record);
                      Navigator.of(ctx).pop();
                    }));
          },
          child: Icon(Icons.add),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Theme.of(context).colorScheme.background,
          child: SafeArea(child: page),
        ),
        bottomNavigationBar: BottomAppBar(
          shape: CircularNotchedRectangle(),
          notchMargin: 6.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.home),
                onPressed: () => setState(() => selectedIndex = 0),
              ),
              // spacer for center FAB notch
              SizedBox(width: 48),
              IconButton(
                icon: Icon(Icons.calendar_month),
                onPressed: () => setState(() => selectedIndex = 1),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class EmptyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('页面暂未实现'));
  }
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final model = Provider.of<RecordsModel>(context, listen: false);
      if (model.isYearView) {
        model.loadYearSummaries(model.selectedYear);
      } else {
        model.loadForMonth(model.selectedYear, model.selectedMonth);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recordsModel = context.watch<RecordsModel>();
    final years =
        List.generate(DateTime.now().year + 5 - 2020, (i) => 2020 + i);
    final months = List.generate(12, (i) => i + 1);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DropdownButton<int>(
                value: recordsModel.selectedYear,
                items: years
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    if (recordsModel.isYearView) {
                      recordsModel.loadYearSummaries(v);
                    } else {
                      recordsModel.loadForMonth(v, recordsModel.selectedMonth);
                    }
                  }
                },
              ),
              SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (!recordsModel.isYearView) {
                    recordsModel.setYearView(true);
                  }
                },
                child: Card(
                  color: recordsModel.isYearView
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surface,
                  elevation: recordsModel.isYearView ? 4 : 1,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Text('按年',
                        style: TextStyle(
                            color: recordsModel.isYearView
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (recordsModel.isYearView) {
                    recordsModel.setYearView(false);
                  }
                },
                child: Card(
                  color: !recordsModel.isYearView
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surface,
                  elevation: !recordsModel.isYearView ? 4 : 1,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Text('按月',
                        style: TextStyle(
                            color: !recordsModel.isYearView
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              SizedBox(width: 12),
              if (!recordsModel.isYearView) ...[
                DropdownButton<int>(
                  value: recordsModel.selectedMonth,
                  items: months
                      .map((m) =>
                          DropdownMenuItem(value: m, child: Text('$m 月')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      recordsModel.loadForMonth(recordsModel.selectedYear, v);
                    }
                  },
                ),
              ]
            ],
          ),
          SizedBox(height: 12),
          if (recordsModel.isYearView) ...[
            // 只显示有数据的月份，并按月份倒序排列
            Expanded(
              child: ListView(
                children: List.generate(12, (i) => 12 - i).where((m) {
                  final s = recordsModel.monthSummaries[m];
                  final income = s?['income'] ?? 0.0;
                  final expense = s?['expense'] ?? 0.0;
                  return (income != 0.0 || expense != 0.0);
                }).map((m) {
                  final s = recordsModel.monthSummaries[m];
                  final income = s?['income'] ?? 0.0;
                  final expense = s?['expense'] ?? 0.0;
                  return ListTile(
                    title: Text('${m} 月'),
                    subtitle: Text(
                        '收入: ¥${income.toStringAsFixed(2)}  支出: ¥${expense.toStringAsFixed(2)}'),
                    onTap: () {
                      recordsModel.setYearView(false).then((_) => recordsModel
                          .loadForMonth(recordsModel.selectedYear, m));
                    },
                  );
                }).toList(),
              ),
            )
          ] else ...[
            // month view: show summary + details
            FutureBuilder<Map<String, double>>(
              future: RecordsDatabase.instance.getMonthSummary(
                  recordsModel.selectedYear, recordsModel.selectedMonth),
              builder: (context, snap) {
                if (!snap.hasData) return CircularProgressIndicator();
                final sum = snap.data!;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${recordsModel.selectedYear}-${recordsModel.selectedMonth.toString().padLeft(2, '0')}',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('收入: ¥${sum['income']!.toStringAsFixed(2)}',
                                style: TextStyle(color: Colors.green)),
                            Text('支出: ¥${sum['expense']!.toStringAsFixed(2)}',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 12),
            Expanded(child: MonthDetailList()),
          ]
        ],
      ),
    );
  }
}

class AddRecordDialog extends StatefulWidget {
  final Future<void> Function(Record) onSaved;
  AddRecordDialog({required this.onSaved});

  @override
  State<AddRecordDialog> createState() => _AddRecordDialogState();
}

class _AddRecordDialogState extends State<AddRecordDialog> {
  DateTime _dt = DateTime.now();
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isIncome = false;
  final _amountCtl = TextEditingController();
  final _noteCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await RecordsDatabase.instance.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats.map((c) => c.name).toList();
      if (_categories.isNotEmpty) _selectedCategory = _categories.first;
    });
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text('添加记录',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold))),
                  TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _dt,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          locale: const Locale('zh', 'CN'),
                        );
                        if (d == null) return;
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_dt),
                          builder: (context, child) => Localizations.override(
                              context: context,
                              locale: const Locale('zh', 'CN'),
                              child: child),
                        );
                        if (!mounted) return;
                        setState(() {
                          _dt = DateTime(d.year, d.month, d.day, t?.hour ?? 0,
                              t?.minute ?? 0);
                        });
                      },
                      child: Text(
                          '${_dt.year}年${_dt.month}月${_dt.day}日 ${_dt.hour.toString().padLeft(2, '0')}时${_dt.minute.toString().padLeft(2, '0')}分'))
                ],
              ),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(labelText: '记账分类'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCategory = v);
                },
              ),
              Row(
                children: [
                  Expanded(child: Text('类型')),
                  Switch(
                      value: _isIncome,
                      onChanged: (v) => setState(() => _isIncome = v)),
                  Text(_isIncome ? '收入' : '支出')
                ],
              ),
              TextField(
                  controller: _amountCtl,
                  decoration: InputDecoration(labelText: '金额'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true)),
              TextField(
                  controller: _noteCtl,
                  decoration: InputDecoration(labelText: '备注')),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('取消')),
                  ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(_amountCtl.text) ?? 0.0;
                        final rec = Record(
                            dateTime: _dt,
                            category: _selectedCategory ?? '其他',
                            isIncome: _isIncome,
                            amount: amount,
                            note: _noteCtl.text);
                        await widget.onSaved(rec);
                      },
                      child: Text('保存')),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
