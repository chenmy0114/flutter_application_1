import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;
import 'db.dart';
import 'package:provider/provider.dart';
import 'models/records_model.dart';
import 'models/record.dart';
import 'settings_page.dart';
import 'package:fl_chart/fl_chart.dart';

// Custom ScrollPhysics that prevents flinging across more than one page at a time.
// This avoids skipping months when the user swipes quickly.
class _OnePageScrollPhysics extends PageScrollPhysics {
  const _OnePageScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  PageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _OnePageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double getTargetPixels(ScrollMetrics position, double velocity) {
    final double page = position.pixels / position.viewportDimension;
    double targetPage;
    if (velocity.abs() < 0.5) {
      targetPage = page.roundToDouble();
    } else {
      targetPage = velocity > 0 ? page.ceilToDouble() : page.floorToDouble();
    }
    final double clampedPage =
        math.max(page - 1, math.min(page + 1, targetPage));
    return clampedPage * position.viewportDimension;
  }
}

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late DateTime _now;
  Map<int, Map<String, double>> _daySummaries = {};
  // stats state
  bool _viewYear = false; // false: month view, true: year view
  bool _showIncome = false; // false: show expense, true: show income
  List<Map<String, Object>> _categorySums = [];
  int _summaryCount = 0;
  double _summaryTotal = 0.0;
  double _walletTotal = 0.0;
  double _monthTotal = 0.0;
  late PageController _pageController;
  late int _currentPageIndex;
  late int _visiblePageIndex;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _currentPageIndex = _now.year * 12 + (_now.month - 1);
    _pageController = PageController(initialPage: _currentPageIndex);
    _visiblePageIndex = _currentPageIndex;
    _pageController.addListener(_onPageScroll);
    _loadData();
  }

  RecordsModel? _recordsModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final model = Provider.of<RecordsModel>(context, listen: false);
    if (_recordsModel != model) {
      _recordsModel?.removeListener(_onRecordsModelChanged);
      _recordsModel = model;
      _recordsModel?.addListener(_onRecordsModelChanged);
    }
  }

  @override
  void dispose() {
    _recordsModel?.removeListener(_onRecordsModelChanged);
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    final p = _pageController.page;
    if (p == null) return;
    final int center = p.round();
    if (center != _visiblePageIndex) {
      setState(() {
        _visiblePageIndex = center;
      });
    }
  }

  void _onRecordsModelChanged() {
    // When records model changes (e.g., after adding a record), refresh data
    // only when this page is visible; safe to always call _loadData() since it checks mounted
    _loadData();
  }

  void _changeMonth(int delta) {
    setState(() {
      _now = DateTime(_now.year, _now.month + delta, 1);
      _currentPageIndex = _now.year * 12 + (_now.month - 1);
      _visiblePageIndex = _currentPageIndex;
    });
    // load data for the new month
    Future.microtask(_loadData);
  }

  Future<void> _showYearMonthPicker() async {
    final int startYear = 2020;
    final int endYear = DateTime.now().year + 5;
    final years = List.generate(endYear - startYear + 1, (i) => startYear + i);
    int selYear = _now.year;
    int selMonth = _now.month;

    final yearController =
        FixedExtentScrollController(initialItem: selYear - startYear);
    final monthController =
        FixedExtentScrollController(initialItem: selMonth - 1);

    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      backgroundColor: Theme.of(context).canvasColor,
      builder: (ctx) {
        return Container(
          height: 450,
          padding: EdgeInsets.only(top: 8),
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
                        onPressed: () => Navigator.of(ctx)
                            .pop({'y': selYear, 'm': selMonth}),
                        child: Text('确定')),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: yearController,
                        itemExtent: 55,
                        onSelectedItemChanged: (i) {
                          selYear = years[i];
                        },
                        children: years
                            .map((y) => Center(child: Text('$y')))
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: monthController,
                        itemExtent: 55,
                        onSelectedItemChanged: (i) {
                          selMonth = i + 1;
                        },
                        children: List.generate(
                            12, (i) => Center(child: Text('${i + 1}'))),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      isDismissible: true,
      useRootNavigator: true,
    );

    if (result != null) {
      final y = result['y']!;
      final m = result['m']!;
      setState(() {
        _now = DateTime(y, m, 1);
        _currentPageIndex = _now.year * 12 + (_now.month - 1);
        _visiblePageIndex = _currentPageIndex;
      });
      Future.microtask(_loadData);
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final year = _now.year;
    final month = _now.month;
    final wallet = await RecordsDatabase.instance.getWalletTotal();
    final days = await RecordsDatabase.instance.getDaySummaries(year, month);
    final monthSummary =
        await RecordsDatabase.instance.getMonthSummary(year, month);
    final monthNet =
        (monthSummary['income'] ?? 0.0) - (monthSummary['expense'] ?? 0.0);
    if (!mounted) return;
    setState(() {
      _walletTotal = wallet;
      _daySummaries = days;
      _monthTotal = monthNet;
      _loading = false;
    });
    // load stats (default month view)
    await _loadStats();
  }

  Future<void> _loadStats() async {
    final now = _now;
    List<Map<String, Object>> sums;
    if (_viewYear) {
      sums = await RecordsDatabase.instance
          .getCategorySumsForYear(now.year, _showIncome);
    } else {
      sums = await RecordsDatabase.instance
          .getCategorySumsForMonth(now.year, now.month, _showIncome);
    }

    // compute total count and total amount
    int cnt = 0;
    double tot = 0.0;
    for (final s in sums) {
      cnt += (s['count'] as int?) ?? 0;
      tot += (s['total'] as double?) ?? 0.0;
    }

    setState(() {
      _categorySums = sums;
      _summaryCount = cnt;
      _summaryTotal = tot;
    });
  }

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);
    final year = _now.year;
    final month = _now.month;

    // calculate top padding so the settings button does not overlap the content
    final double settingsButtonTop = MediaQuery.of(context).padding.top + 8;
    final double settingsButtonSize =
        40.0; // approximate FloatingActionButton.small size
    final double topContentPadding =
        settingsButtonTop + settingsButtonSize + 8.0;

    return Stack(
      children: [
        // main scrollable content with extra top padding
        _loading
            ? Padding(
                padding: EdgeInsets.fromLTRB(12, topContentPadding, 12, 12),
                child: Center(child: CircularProgressIndicator()),
              )
            : Padding(
                padding: EdgeInsets.fromLTRB(12, topContentPadding, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('总记', style: TextStyle(fontSize: 14)),
                                  Text(
                                    '${_walletTotal >= 0 ? '+' : '-'}${_walletTotal.abs().toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _walletTotal >= 0
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // SizedBox(width: 8),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('当月', style: TextStyle(fontSize: 14)),
                                  Text(
                                    '${_monthTotal >= 0 ? '+' : '-'}${_monthTotal.abs().toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _monthTotal >= 0
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left),
                          onPressed: () => _changeMonth(-1),
                          tooltip: '上一月',
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: _showYearMonthPicker,
                            child: Center(
                              child: Text('${year}年${month}月',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right),
                          onPressed: () => _changeMonth(1),
                          tooltip: '下一月',
                        ),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCalendar(context, year, month),
                            _buildStatsArea(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        // fixed settings button at top-right of this page
        Positioned(
          top: settingsButtonTop,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'wallet_settings',
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => SettingsPage()));
            },
            child: Icon(Icons.settings),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context, int year, int month) {
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 1).difference(first).inDays;
    final firstWeekday = first.weekday; // Monday=1
    final leadingEmpty = (firstWeekday % 7); // Sunday -> 0

    final List<Widget> rows = [];
    rows.add(Row(
      children: ['日', '一', '二', '三', '四', '五', '六']
          .map((d) => Expanded(child: Center(child: Text(d))))
          .toList(),
    ));
    rows.add(SizedBox(height: 6));

    int day = 1;
    while (day <= daysInMonth) {
      final cells = <Widget>[];
      for (int wd = 0; wd < 7; wd++) {
        if (rows.length == 2 && wd < leadingEmpty) {
          cells.add(Expanded(child: SizedBox()));
        } else if (day > daysInMonth) {
          cells.add(Expanded(child: SizedBox()));
        } else {
          final summary = _daySummaries[day];
          final income = summary?['income'] ?? 0.0;
          final expense = summary?['expense'] ?? 0.0;
          final net = income - expense;
          final positive = net >= 0;
          final bgColor =
              positive ? Colors.green.shade100 : Colors.red.shade100;
          final textColor =
              positive ? Colors.green.shade900 : Colors.red.shade900;
          final curDay = day;

          cells.add(Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _showDayRecordsDialog(year, month, curDay);
              },
              child: Column(
                children: [
                  Text('$curDay'),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (income != 0 || expense != 0)
                          ? bgColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: (income != 0 || expense != 0)
                          ? Text(
                              '${positive ? '+' : '-'}¥${net.abs().toStringAsFixed(2)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textColor, fontSize: 12),
                            )
                          : SizedBox(width: 48, height: 14),
                    ),
                  ),
                ],
              ),
            ),
          ));
          day++;
        }
      }
      rows.add(Row(children: cells));
      rows.add(SizedBox(height: 6));
    }

    return Column(children: rows);
  }

  Widget _buildStatsArea() {
    // small pie chart placeholder and list
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ToggleButtons(
                  isSelected: [_viewYear, !_viewYear],
                  onPressed: (i) async {
                    setState(() => _viewYear = (i == 0));
                    await _loadStats();
                  },
                  children: [Text('年'), Text('月')],
                ),
                SizedBox(width: 8),
                ToggleButtons(
                  isSelected: [_showIncome, !_showIncome],
                  onPressed: (i) async {
                    setState(() => _showIncome = (i == 0));
                    await _loadStats();
                  },
                  children: [Text('收入'), Text('支出')],
                ),
                Spacer(),
                Text(
                    '${_viewYear ? _now.year.toString() : '${_now.year}-${_now.month}'}'),
              ],
            ),
            SizedBox(height: 8),
            Text('共 $_summaryCount 笔，合计 ￥${_summaryTotal.toStringAsFixed(2)}'),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // simple pie placeholder
                Container(
                  width: 120,
                  height: 120,
                  child: _buildPiePlaceholder(),
                ),
                SizedBox(width: 12),
                // category list
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 160),
                    child: ListView.builder(
                      itemCount: _categorySums.length,
                      itemBuilder: (context, idx) {
                        final s = _categorySums[idx];
                        final name = s['category'] as String? ?? '';
                        final total = (s['total'] as double?) ?? 0.0;
                        final count = (s['count'] as int?) ?? 0;
                        final color =
                            Colors.primaries[idx % Colors.primaries.length];
                        return ListTile(
                          dense: true,
                          title: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                margin: EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Text(name),
                            ],
                          ),
                          subtitle: Text('$count 笔'),
                          trailing: Text('￥${total.toStringAsFixed(2)}'),
                          onTap: () async {
                            // show records for this category
                            List<Record> recs;
                            if (_viewYear) {
                              recs = await RecordsDatabase.instance
                                  .getRecordsForCategoryInYear(
                                      _now.year, name, _showIncome);
                            } else {
                              recs = await RecordsDatabase.instance
                                  .getRecordsForCategoryInMonth(
                                      _now.year, _now.month, name, _showIncome);
                            }
                            _showRecordsListDialog(name, recs);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPiePlaceholder() {
    if (_categorySums.isEmpty) return Center(child: Text('无数据'));

    final totals =
        _categorySums.map((e) => (e['total'] as double?) ?? 0.0).toList();
    final sum = totals.fold(0.0, (a, b) => a + b);

    final sections = totals.asMap().entries.map((entry) {
      final idx = entry.key;
      final val = entry.value;
      final pct = sum > 0 ? (val / sum) : 0.0;
      final color = Colors.primaries[idx % Colors.primaries.length];
      return PieChartSectionData(
        value: val.abs(),
        title: pct > 0.05 ? '${(pct * 100).toStringAsFixed(0)}%' : '',
        color: color,
        radius: 40,
        titleStyle: TextStyle(fontSize: 12, color: Colors.white),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 28,
        sectionsSpace: 2,
        pieTouchData: PieTouchData(enabled: true),
      ),
    );
  }

  void _showRecordsListDialog(String title, List<Record> recs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            itemCount: recs.length,
            itemBuilder: (c, i) {
              final r = recs[i];
              final dt = r.dateTime;
              return ListTile(
                subtitle: Text(
                  r.note ?? '',
                  style: TextStyle(fontSize: 11),
                ),
                title: Text(
                    '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 11)),
                trailing: Text(
                    '${r.isIncome ? '+' : '-'}￥${r.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: r.isIncome ? Colors.green : Colors.red,
                        fontSize: 15)),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: Text('关闭'))
        ],
      ),
    );
  }

  Future<void> _showDayRecordsDialog(int year, int month, int day) async {
    final records =
        await RecordsDatabase.instance.getRecordsForDay(year, month, day);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$year年$month月$day日 - 记录'),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: records.isEmpty
                ? Center(child: Text('该日没有记录'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final r = records[index];
                      final time =
                          TimeOfDay.fromDateTime(r.dateTime).format(context);
                      final amountText =
                          '${r.isIncome ? '+' : '-'}¥${r.amount.toStringAsFixed(2)}';
                      final amountColor = r.isIncome
                          ? Colors.green.shade700
                          : Colors.red.shade700;
                      return ListTile(
                        dense: true,
                        title: Text('${r.category}  $time'),
                        subtitle: r.note != null && r.note!.isNotEmpty
                            ? Text(r.note!)
                            : null,
                        trailing: Text(amountText,
                            style: TextStyle(
                                color: amountColor,
                                fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('关闭'),
            )
          ],
        );
      },
    );
  }
}
