import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:decimal/decimal.dart';

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
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(30))),
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
              // SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (!recordsModel.isYearView) {
                    recordsModel.setYearView(true);
                  }
                },
                child: Card(
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(30))),
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
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(30))),
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
              GestureDetector(
                onTap: _showYearPicker,
                child: Card(
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(30))),
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
              if (!recordsModel.isYearView) ...[
                GestureDetector(
                  onTap: _showMonthPicker,
                  child: Card(
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(30))),
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
            FutureBuilder<Map<String, double>>(
              future: RecordsDatabase.instance
                  .getYearSummary(recordsModel.selectedYear),
              builder: (context, snap) {
                if (!snap.hasData) return CircularProgressIndicator();
                final sum = snap.data!;
                final income = sum['income'] ?? 0.0;
                final expense = sum['expense'] ?? 0.0;
                final net = income - expense;
                final positive = net >= 0;
                final textColor = positive ? Colors.green : Colors.red;
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25))),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${recordsModel.selectedYear}',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (positive) ...[
                              Text('净收入: ¥${net.abs().toStringAsFixed(2)}',
                                  style: TextStyle(color: textColor)),
                            ] else ...[
                              Text('净支出: ¥${net.abs().toStringAsFixed(2)}',
                                  style: TextStyle(color: textColor)),
                            ],
                            Row(
                              children: [
                                Text(
                                    '收入: ¥${sum['income']!.toStringAsFixed(2)}'),
                                SizedBox(width: 16),
                                Text(
                                    '支出: ¥${sum['expense']!.toStringAsFixed(2)}'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 12),

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
                final income = sum['income'] ?? 0.0;
                final expense = sum['expense'] ?? 0.0;
                final net = income - expense;
                final positive = net >= 0;
                final textColor = positive ? Colors.green : Colors.red;
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25))),
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
                            if (positive) ...[
                              Text('净收入: ¥${net.abs().toStringAsFixed(2)}',
                                  style: TextStyle(color: textColor)),
                            ] else ...[
                              Text('净支出: ¥${net.abs().toStringAsFixed(2)}',
                                  style: TextStyle(color: textColor)),
                            ],
                            Row(
                              children: [
                                Text(
                                    '收入: ¥${sum['income']!.toStringAsFixed(2)}'),
                                SizedBox(width: 16),
                                Text(
                                    '支出: ¥${sum['expense']!.toStringAsFixed(2)}'),
                              ],
                            ),
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

// 历史记录模型
class CalcHistory {
  final String expression; // 算式（如"2×3"）
  final String result; // 结果（如"6"）
  final DateTime time; // 计算时间

  CalcHistory({
    required this.expression,
    required this.result,
    required this.time,
  });

  // 转JSON（用于持久化）
  Map<String, dynamic> toJson() {
    return {
      'expression': expression,
      'result': result,
      'time': time.toIso8601String(),
    };
  }

  // 从JSON解析
  static CalcHistory fromJson(Map<String, dynamic> json) {
    return CalcHistory(
      expression: json['expression'],
      result: json['result'],
      time: DateTime.parse(json['time']),
    );
  }
}

// Simple calculator page
class SimpleCalculatorPage extends StatefulWidget {
  @override
  State<SimpleCalculatorPage> createState() => _SimpleCalculatorPageState();
}

class _SimpleCalculatorPageState extends State<SimpleCalculatorPage> {
  String _displayText = ''; // 显示区域文本
  String _expression = ''; // 完整算式
  bool _isCalculated = false; // 是否计算完成
  List<CalcHistory> _historyList = []; // 历史记录列表
  bool _showHistory = false; // 是否显示历史记录面板
  double _fontSize = 48;

  // 初始化：加载本地历史记录
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // 加载持久化的历史记录
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? historyJson = prefs.getStringList('calc_history');
    if (historyJson != null) {
      setState(() {
        _historyList = historyJson
            .map((json) => CalcHistory.fromJson(Map<String, dynamic>.from(
                  Uri.splitQueryString(json), // 简易JSON解析（也可使用json_serializable）
                )))
            .toList();
      });
    }
  }

  // 保存历史记录到本地
  Future<void> _saveHistory(CalcHistory history) async {
    setState(() {
      _historyList.insert(0, history); // 最新记录插入顶部
      if (_historyList.length > 20) _historyList.removeLast(); // 限制最多20条
    });

    final prefs = await SharedPreferences.getInstance();
    final List<String> historyJson = _historyList
        .map((h) => Uri(
              queryParameters: {
                'expression': h.expression,
                'result': h.result,
                'time': h.time.toIso8601String(),
              },
            ).query)
        .toList();
    await prefs.setStringList('calc_history', historyJson);
  }

  // 清空历史记录
  Future<void> _clearHistory() async {
    setState(() {
      _historyList.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('calc_history');
  }

  // 精度处理：修正浮点数误差（如0.1+0.2=0.3）
  String _formatResult(double value) {
    // 转换为Decimal处理精度
    final decimal = Decimal.parse(value.toString());
    // 去除末尾的0和小数点
    String result = decimal
        .toString()
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    // 兼容整数显示（如6.0→6）
    return result.isEmpty ? '0' : result;
  }

  // 格式化算式（适配math_expressions）
  String _formatExpression(String expr) {
    return expr
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('%', '/100');
  }

  // 按键点击事件（数字/运算符）
  void _onButtonPressed(String value) {
    setState(() {
      // 连续计算：计算完成后点击运算符，将结果作为新算式开头
      if (_isCalculated) {
        if (['+', '-', '×', '÷'].contains(value)) {
          _expression = _displayText + value; // 结果+新运算符
          _displayText = _expression;
          _adjustFontSize();
          _isCalculated = false;
        } else {
          // 计算完成后点击数字，清空重新输入
          _expression = value;
          _displayText = value;
          _adjustFontSize();
          _isCalculated = false;
        }
      } else {
        // 禁止开头直接输入运算符
        if (_expression.isEmpty && ['+', '-', '×', '÷'].contains(value)) return;
        // 拼接算式
        _expression += value;
        _displayText = _expression;
        _adjustFontSize();
      }
    });
  }

  // 等号计算逻辑
  void _onEqualsPressed() {
    if (_expression.isEmpty || _isCalculated) return;

    try {
      // 解析并计算算式
      final formattedExpr = _formatExpression(_expression);
      final parser = Parser();
      final exp = parser.parse(formattedExpr);
      final cm = ContextModel();
      final double rawResult = exp.evaluate(EvaluationType.REAL, cm);

      // 精度处理后的结果
      final String result = _formatResult(rawResult);

      // 保存历史记录
      final history = CalcHistory(
        expression: _expression,
        result: result,
        time: DateTime.now(),
      );
      _saveHistory(history);

      // 更新显示
      setState(() {
        _displayText = result;
        _adjustFontSize();
        _isCalculated = true;
      });
    } catch (e) {
      setState(() {
        _displayText = '计算错误';
        _isCalculated = true;
      });
    }
  }

  // 清空当前输入
  void _onClearPressed() {
    setState(() {
      _displayText = '';
      _adjustFontSize();
      _expression = '';
      _isCalculated = false;
    });
  }

  // 退格功能
  void _onBackspacePressed() {
    if (_expression.isEmpty || _isCalculated) return;

    setState(() {
      _expression = _expression.substring(0, _expression.length - 1);
      _displayText = _expression;
      _adjustFontSize();
    });
  }

  void _adjustFontSize() {
    setState(() {
      if (_displayText.length <= 12) {
        _fontSize = 48;
      } else if (_displayText.length <= 16) {
        _fontSize = 36;
      } else if (_displayText.length <= 24) {
        _fontSize = 24;
      } else if (_displayText.length <= 28) {
        _fontSize = 20;
      } else {
        _fontSize = 16;
      }
    });
  }

  // 构建按键
  Widget _buildButton({
    required String label,
    Color textColor = Colors.white,
    Color bgColor = const Color.fromARGB(255, 135, 135, 135),
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 24, color: textColor),
          ),
        ),
      ),
    );
  }

  // 构建历史记录面板
  Widget _buildHistoryPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showHistory ? MediaQuery.of(context).size.height * 0.4 : 0,
      child: Column(
        children: [
          // 历史记录标题栏
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            // color: Colors.blue[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '计算历史',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _clearHistory,
                  child: const Text(
                    '清空',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          // 历史记录列表
          Expanded(
            child: _historyList.isEmpty
                ? const Center(child: Text('暂无记录'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _historyList.length,
                    itemBuilder: (context, index) {
                      final history = _historyList[index];
                      return Container(
                        height: 50,
                        child: ListTile(
                          title: Text(
                            '${history.expression} = ${history.result}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            '${history.time.hour.toString().padLeft(2, '0')}:${history.time.minute.toString().padLeft(2, '0')}:${history.time.second.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                          //点击历史记录，回填到输入框
                          onTap: () {
                            setState(() {
                              _expression = history.expression;
                              _displayText = history.expression;
                              _isCalculated = false;
                              _showHistory = false; // 隐藏历史面板
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('计算器'),
        actions: [
          // 历史记录开关按钮
          IconButton(
            icon: Icon(_showHistory ? Icons.history_edu : Icons.history),
            onPressed: () {
              setState(() {
                _showHistory = !_showHistory;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 历史记录面板
          _buildHistoryPanel(),
          // 显示区域
          Expanded(
            child: Container(
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(20),
              child: Text(
                _displayText.isEmpty ? '0' : _displayText,
                style:
                    TextStyle(fontSize: _fontSize, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // 按键区域
          const Divider(height: 1),
          Column(
            children: [
              // 第一行：C、←、%、÷
              Row(
                children: [
                  _buildButton(
                      label: 'C',
                      bgColor: Colors.orange,
                      onPressed: _onClearPressed),
                  _buildButton(
                      label: '←',
                      bgColor: Colors.orange,
                      onPressed: _onBackspacePressed),
                  _buildButton(
                      label: '%',
                      bgColor: Colors.orange,
                      onPressed: () => _onButtonPressed('%')),
                  _buildButton(
                      label: '÷',
                      textColor: Colors.white,
                      bgColor: Colors.orange,
                      onPressed: () => _onButtonPressed('÷')),
                ],
              ),
              // 第二行：7、8、9、×
              Row(
                children: [
                  _buildButton(
                      label: '7',
                      textColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                      bgColor: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () => _onButtonPressed('7')),
                  _buildButton(
                      label: '8',
                      textColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                      bgColor: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () => _onButtonPressed('8')),
                  _buildButton(
                      label: '9',
                      textColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                      bgColor: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () => _onButtonPressed('9')),
                  _buildButton(
                      label: '×',
                      textColor: Colors.white,
                      bgColor: Colors.orange,
                      onPressed: () => _onButtonPressed('×')),
                ],
              ),
              // 第三行：4、5、6、-
              Row(
                children: [
                  _buildButton(
                      label: '4',
                      textColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                      bgColor: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () => _onButtonPressed('4')),
                  _buildButton(
                      label: '5',
                      textColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                      bgColor: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () => _onButtonPressed('5')),
                  _buildButton(
                      label: '6',
                      textColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                      bgColor: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () => _onButtonPressed('6')),
                  _buildButton(
                      label: '-',
                      textColor: Colors.white,
                      bgColor: Colors.orange,
                      onPressed: () => _onButtonPressed('-')),
                ],
              ),
              // 第四行：1、2、3、+
              Row(
                children: [
                  _buildButton(
                      label: '1',
                      textColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                      bgColor: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () => _onButtonPressed('1')),
                  _buildButton(
                      label: '2',
                      textColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                      bgColor: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () => _onButtonPressed('2')),
                  _buildButton(
                      label: '3',
                      textColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                      bgColor: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () => _onButtonPressed('3')),
                  _buildButton(
                      label: '+',
                      textColor: Colors.white,
                      bgColor: Colors.orange,
                      onPressed: () => _onButtonPressed('+')),
                ],
              ),
              // 第五行：0、.、=
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ElevatedButton(
                        onPressed: () => _onButtonPressed('0'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 40),
                        ),
                        child: Text('0',
                            style: TextStyle(
                              fontSize: 24,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            )),
                      ),
                    ),
                  ),
                  _buildButton(
                      label: '.',
                      textColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                      bgColor: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () => _onButtonPressed('.')),
                  _buildButton(
                      label: '=',
                      textColor: Colors.white,
                      bgColor: Colors.orange,
                      onPressed: _onEqualsPressed),
                ],
              ),
              SizedBox(height: 30),
            ],
          ),
        ],
      ),
    );
  }
}
