import 'package:flutter/material.dart';

import '../db.dart';
import 'record.dart';

class RecordsModel extends ChangeNotifier {
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  List<Record> records = [];
  bool isYearView = true;
  // month -> { 'income': x, 'expense': y }
  Map<int, Map<String, double>> monthSummaries = {};

  RecordsModel() {
    // Do not load data in constructor to avoid performing async work
    // during provider initialization which can block the UI or cause
    // rebuilds during build. HomePage will trigger initial load in
    // a post-frame callback.
  }

  Future<void> loadForMonth(int year, int month) async {
    selectedYear = year;
    selectedMonth = month;
    records = await RecordsDatabase.instance.getRecordsForMonth(year, month);
    notifyListeners();
  }

  Future<void> loadYearSummaries(int year) async {
    selectedYear = year;
    monthSummaries.clear();
    final sums = await RecordsDatabase.instance.getYearSummaries(year);
    monthSummaries.addAll(sums);
    notifyListeners();
  }

  Future<void> setYearView(bool yearView) async {
    isYearView = yearView;
    notifyListeners();
    if (isYearView) {
      await loadYearSummaries(selectedYear);
    } else {
      await loadForMonth(selectedYear, selectedMonth);
    }
  }

  Future<void> addRecord(Record r) async {
    await RecordsDatabase.instance.insertRecord(r);
    // refresh views for the month of the newly added record
    final y = r.dateTime.year;
    final m = r.dateTime.month;
    await loadForMonth(y, m);
    if (isYearView) await loadYearSummaries(y);
  }
}
