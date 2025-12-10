import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'db.dart';
import 'models/records_model.dart';

class MonthDetailList extends StatefulWidget {
  @override
  State<MonthDetailList> createState() => _MonthDetailListState();
}

class _MonthDetailListState extends State<MonthDetailList> {
  Set<int> selectedIds = {};
  bool selectionMode = false;

  @override
  Widget build(BuildContext context) {
    final recordsModel = Provider.of<RecordsModel>(context);
    final records = recordsModel.records;
    if (records.isEmpty) {
      return Center(child: Text('该月暂无记录'));
    }
    return CustomScrollView(
      shrinkWrap: true,
      physics: AlwaysScrollableScrollPhysics(),
      slivers: [
        if (selectionMode)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  // Checkbox to toggle select-all
                  Checkbox(
                    value: selectedIds.isNotEmpty &&
                        selectedIds.length ==
                            records.where((r) => r.id != null).length,
                    onChanged: (v) {
                      setState(() {
                        final ids = records
                            .where((r) => r.id != null)
                            .map((r) => r.id!)
                            .toSet();
                        if (v == true) {
                          selectedIds = ids;
                        } else {
                          selectedIds.clear();
                        }
                      });
                    },
                  ),
                  SizedBox(width: 8),
                  Text('已选 ${selectedIds.length} 项'),
                  Spacer(),
                  ElevatedButton.icon(
                    icon: Icon(Icons.delete),
                    label: Text('删除'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.onPrimary),
                    onPressed: selectedIds.isEmpty
                        ? null
                        : () async {
                            final ids = selectedIds.toList();
                            try {
                              await RecordsDatabase.instance.deleteRecords(ids);
                            } catch (e, st) {
                              // ignore: avoid_print
                              print('Batch delete failed: $e\n$st');
                            }
                            selectedIds.clear();
                            selectionMode = false;
                            await recordsModel.loadForMonth(
                                recordsModel.selectedYear,
                                recordsModel.selectedMonth);
                            setState(() {});
                          },
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        selectionMode = false;
                        selectedIds.clear();
                      });
                    },
                  )
                ],
              ),
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, idx) {
            final r = records[idx];
            final selected = r.id != null && selectedIds.contains(r.id!);
            final theme = Theme.of(context);
            return ListTile(
              tileColor:
                  r.isIncome ? theme.colorScheme.secondaryContainer : null,
              leading: selectionMode
                  ? Checkbox(
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            if (r.id != null) selectedIds.add(r.id!);
                          } else {
                            if (r.id != null) selectedIds.remove(r.id!);
                          }
                        });
                      },
                    )
                  : null,
              title: Text(
                '${r.category} ${r.isIncome ? '+' : '-'}¥${r.amount.toStringAsFixed(2)}',
                style: TextStyle(
                    color: r.isIncome
                        ? Colors.green
                            .shade700 //theme.colorScheme.onSecondaryContainer
                        : theme.textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w600),
              ),
              subtitle: Text('${r.dateTime.toLocal()}\n${r.note ?? ''}'),
              isThreeLine: r.note != null && r.note!.isNotEmpty,
              selected: selected,
              onLongPress: () {
                setState(() {
                  selectionMode = true;
                  if (r.id != null) selectedIds.add(r.id!);
                });
              },
              onTap: selectionMode
                  ? () {
                      setState(() {
                        if (selected) {
                          if (r.id != null) selectedIds.remove(r.id!);
                        } else {
                          if (r.id != null) selectedIds.add(r.id!);
                        }
                      });
                    }
                  : null,
            );
          }, childCount: records.length),
        ),
      ],
    );
  }
}
