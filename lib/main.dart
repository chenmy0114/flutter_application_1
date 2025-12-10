import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Theme.of(context).colorScheme.background,
          child: SafeArea(child: page),
        ),
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
    final startYear = 2020;
    final endYear = DateTime.now().year + 5;
    final years = List.generate(endYear - startYear + 1, (i) => startYear + i);
    final months = List.generate(12, (i) => i + 1);

    Future<void> _showYearPicker() async {
      int sel = recordsModel.selectedYear;
      final controller =
          FixedExtentScrollController(initialItem: sel - startYear);
      final res = await showModalBottomSheet<int>(
        context: context,
        builder: (ctx) {
          return Container(
            height: 450,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text('取消')),
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(sel),
                          child: Text('确定')),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: controller,
                    itemExtent: 55,
                    onSelectedItemChanged: (i) => sel = years[i],
                    children:
                        years.map((y) => Center(child: Text('$y'))).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (res != null) {
        if (recordsModel.isYearView) {
          await recordsModel.loadYearSummaries(res);
        } else {
          await recordsModel.loadForMonth(res, recordsModel.selectedMonth);
        }
      }
    }

    Future<void> _showMonthPicker() async {
      int sel = recordsModel.selectedMonth;
      final controller = FixedExtentScrollController(initialItem: sel - 1);
      final res = await showModalBottomSheet<int>(
        context: context,
        builder: (ctx) {
          return Container(
            height: 450,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text('取消')),
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(sel),
                          child: Text('确定')),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: controller,
                    itemExtent: 55,
                    onSelectedItemChanged: (i) => sel = i + 1,
                    children:
                        months.map((m) => Center(child: Text('$m'))).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (res != null) {
        await recordsModel.loadForMonth(recordsModel.selectedYear, res);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _showYearPicker,
                child: Card(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 1,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text('${recordsModel.selectedYear}'),
                  ),
                ),
              ),
              // SizedBox(width: 8),
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
              // SizedBox(width: 8),
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
              // SizedBox(width: 8),
              if (!recordsModel.isYearView) ...[
                GestureDetector(
                  onTap: _showMonthPicker,
                  child: Card(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Text('${recordsModel.selectedMonth}'),
                    ),
                  ),
                ),
              ],
              Spacer(),
              GestureDetector(
                child: IconButton(
                  tooltip: '计算器',
                  icon: Icon(Icons.calculate),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SimpleCalculatorPage()));
                  },
                ),
              ),
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
                    onLongPress: () async {
                      final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                                title: Text('删除整月记录'),
                                content: Text(
                                    '确定要删除 ${recordsModel.selectedYear} 年 ${m} 月的所有记录吗？此操作不可撤销。'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: Text('取消')),
                                  ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: Text('删除'))
                                ],
                              ));
                      if (confirmed == true) {
                        try {
                          await RecordsDatabase.instance.deleteRecordsForMonth(
                              recordsModel.selectedYear, m);
                          await recordsModel
                              .loadYearSummaries(recordsModel.selectedYear);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                '已删除 ${recordsModel.selectedYear} 年 ${m} 月的记录'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('删除失败：$e'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      }
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
              GestureDetector(
                onTap: () async {
                  if (_categories.isEmpty) return;
                  int sel = _selectedCategory != null
                      ? _categories.indexOf(_selectedCategory!)
                      : 0;
                  final controller = FixedExtentScrollController(
                      initialItem: sel < 0 ? 0 : sel);
                  final res = await showModalBottomSheet<int>(
                    context: context,
                    builder: (ctx) {
                      return Container(
                        height: 450,
                        child: Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: Text('取消')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(sel),
                                      child: Text('确定')),
                                ],
                              ),
                            ),
                            Expanded(
                              child: CupertinoPicker(
                                scrollController: controller,
                                itemExtent: 55,
                                onSelectedItemChanged: (i) => sel = i,
                                children: _categories
                                    .map((c) => Center(child: Text(c)))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                  if (res != null && res >= 0 && res < _categories.length) {
                    setState(() => _selectedCategory = _categories[res]);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: '记账分类'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_selectedCategory ?? '请选择'),
                      // Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
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

// Simple calculator page
class SimpleCalculatorPage extends StatefulWidget {
  @override
  State<SimpleCalculatorPage> createState() => _SimpleCalculatorPageState();
}

class _SimpleCalculatorPageState extends State<SimpleCalculatorPage> {
  String _display = '0';
  double? _first;
  String? _op;
  bool _shouldClear = false;

  void _numPress(String s) {
    setState(() {
      if (_shouldClear || _display == '0') {
        _display = s;
        _shouldClear = false;
      } else {
        _display = _display + s;
      }
    });
  }

  void _dot() {
    if (!_display.contains('.')) {
      setState(() => _display = _display + '.');
    }
  }

  void _opPress(String op) {
    setState(() {
      _first = double.tryParse(_display) ?? 0.0;
      _op = op;
      _shouldClear = true;
      _display = _display + op;
    });
  }

  void _clear() {
    setState(() {
      _display = '0';
      _first = null;
      _op = null;
      _shouldClear = false;
    });
  }

  void _equals() {
    if (_op == null || _first == null) return;
    final second = double.tryParse(_display) ?? 0.0;
    double res = 0.0;
    switch (_op) {
      case '+':
        res = _first! + second;
        break;
      case '-':
        res = _first! - second;
        break;
      case '×':
        res = _first! * second;
        break;
      case '÷':
        res = second == 0 ? double.nan : _first! / second;
        break;
    }
    setState(() {
      _display = res.isNaN ? '错误' : res.toString();
      _first = null;
      _op = null;
      _shouldClear = true;
    });
  }

  Widget _button(String label, {Color? color, VoidCallback? onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 18),
            backgroundColor: color,
          ),
          onPressed: onTap,
          child: Text(label, style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('计算器')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.bottomRight,
              padding: EdgeInsets.all(16),
              child: Text(_display, style: TextStyle(fontSize: 36)),
            ),
          ),
          Column(
            children: [
              Row(children: [
                _button('7', onTap: () => _numPress('7')),
                _button('8', onTap: () => _numPress('8')),
                _button('9', onTap: () => _numPress('9')),
                _button('÷', color: Colors.orange, onTap: () => _opPress('÷')),
              ]),
              Row(children: [
                _button('4', onTap: () => _numPress('4')),
                _button('5', onTap: () => _numPress('5')),
                _button('6', onTap: () => _numPress('6')),
                _button('×', color: Colors.orange, onTap: () => _opPress('×')),
              ]),
              Row(children: [
                _button('1', onTap: () => _numPress('1')),
                _button('2', onTap: () => _numPress('2')),
                _button('3', onTap: () => _numPress('3')),
                _button('-', color: Colors.orange, onTap: () => _opPress('-')),
              ]),
              Row(children: [
                _button('0', onTap: () => _numPress('0')),
                _button('.', onTap: () => _dot()),
                _button('C', color: Colors.grey, onTap: () => _clear()),
                _button('+', color: Colors.orange, onTap: () => _opPress('+')),
              ]),
              Row(children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        bottom: 36.0, left: 6.0, right: 6.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 18)),
                      onPressed: _equals,
                      child: Text('=', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                )
              ])
            ],
          )
        ],
      ),
    );
  }
}
