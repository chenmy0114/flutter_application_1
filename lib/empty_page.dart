import 'package:flutter/material.dart';

import 'db.dart';
import 'models/record.dart';
// 假设你的数据模型和数据库操作类如下（如果已有可忽略）
// import 'your_records_model_path.dart';
// import 'your_database_path.dart';

class EmptyPage extends StatefulWidget {
  @override
  State<EmptyPage> createState() => _EmptyPageState();
}

class _EmptyPageState extends State<EmptyPage> {
  // 起始和结束日期
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    // 初始化默认时间范围（近30天）
    final now = DateTime.now();
    endDate = now;
    startDate = DateTime(now.year, now.month, now.day - 6);
  }

  // 显示日期选择器
  Future<void> _showDatePicker(bool isStartDate) async {
    final initialDate = isStartDate ? startDate : endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
          // 确保起始日期不晚于结束日期
          if (endDate != null && startDate!.isAfter(endDate!)) {
            endDate = startDate;
          }
        } else {
          endDate = picked;
          // 确保结束日期不早于起始日期
          if (startDate != null && endDate!.isBefore(startDate!)) {
            startDate = endDate;
          }
        }
      });
    }
  }

  // 查询时间段内的记账数据
  Future<Map<String, double>> _queryRecordsInRange() async {
    if (startDate == null || endDate == null) {
      return {'income': 0.0, 'expense': 0.0};
    }

    // 调用数据库查询方法（仿HomePage的数据库操作风格）
    try {
      final data = await RecordsDatabase.instance.getRecordsInDateRange(
        startDate!,
        endDate!,
      );
      return {
        'income': data['income'] ?? 0.0,
        'expense': data['expense'] ?? 0.0,
      };
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('查询失败：$e')),
      );
      return {'income': 0.0, 'expense': 0.0};
    }
  }

  @override
  Widget build(BuildContext context) {
    // 格式化日期显示
    String _formatDate(DateTime? date) {
      if (date == null) return '未选择';
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('详情查询'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部日期选择栏（仿HomePage的按钮样式）
            Row(
              children: [
                // 起始日期选择器
                GestureDetector(
                  onTap: () => _showDatePicker(true),
                  child: Card(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(30)),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            _formatDate(startDate),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),

                Text('~',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),

                // 结束日期选择器
                GestureDetector(
                  onTap: () => _showDatePicker(false),
                  child: Card(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(30)),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            _formatDate(endDate),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Spacer(),

                // 查询按钮
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    // 核心：设置透明背景
                    backgroundColor: Colors.transparent,
                    // 去掉按钮的阴影（可选，透明背景通常不需要阴影）
                    elevation: 0,
                    // 去掉内边距（可选，根据你的布局调整）
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),

                    // 圆角（保持和其他按钮一致的风格）
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    setState(() {}); // 触发重新构建，刷新数据
                  },
                  child: Icon(Icons.search),
                ),
              ],
            ),

            SizedBox(height: 12),

            // 时间段汇总卡片（仿HomePage的汇总样式）
            FutureBuilder<Map<String, double>>(
              future: _queryRecordsInRange(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final sum = snap.data!;
                final income = sum['income'] ?? 0.0;
                final expense = sum['expense'] ?? 0.0;
                final net = income - expense;
                final positive = net >= 0;
                final textColor = positive ? Colors.green : Colors.red;

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '汇总',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              positive
                                  ? '净收入: ¥${net.abs().toStringAsFixed(2)}'
                                  : '净支出: ¥${net.abs().toStringAsFixed(2)}',
                              style: TextStyle(color: textColor),
                            ),
                            Row(
                              children: [
                                Text('收入: ¥${income.toStringAsFixed(2)}'),
                                SizedBox(width: 16),
                                Text('支出: ¥${expense.toStringAsFixed(2)}'),
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

            // 时间段明细列表
            Expanded(
              child: FutureBuilder<List<Record>>(
                // 假设Record是你的记账数据模型
                future: RecordsDatabase.instance
                    .getRecordListInDateRange(startDate!, endDate!),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.description_outlined,
                              size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('该时间段内暂无记账数据'),
                        ],
                      ),
                    );
                  }
                  final theme = Theme.of(context);
                  final records = snap.data!;
                  return ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return ListTile(
                        title: Text(
                          '${record.category} ${record.isIncome ? '+' : '-'}¥${record.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: record.isIncome
                                  ? Colors.green
                                      .shade700 //theme.colorScheme.onSecondaryContainer
                                  : theme.textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                            '${record.dateTime.toLocal()}\n${record.note ?? ''}'), // 日期+分类
                        onTap: () {
                          // 可添加编辑功能
                        },
                        onLongPress: () async {
                          // 可添加删除功能（仿HomePage的删除逻辑）
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('删除记录'),
                              content: Text('确定要删除这条记账记录吗？此操作不可撤销。'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text('取消'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text('删除'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            try {
                              await RecordsDatabase.instance
                                  .deleteRecord(record.id!);
                              setState(() {}); // 刷新列表
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已删除该记录'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('删除失败：$e'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
