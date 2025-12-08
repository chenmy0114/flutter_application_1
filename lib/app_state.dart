import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();

  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }

  var favorites = <WordPair>[];
  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }
    notifyListeners();
  }

  void removeFavorite(WordPair pair) {
    favorites.remove(pair);
    notifyListeners();
  }

  Color seedColor = Colors.deepOrange;
  ThemeMode themeMode = ThemeMode.system;

  MyAppState() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getInt('seedColor');
      if (v != null) seedColor = Color(v);
      final tm = prefs.getInt('themeMode');
      if (tm != null) {
        int idx = tm;
        if (idx < 0 || idx >= ThemeMode.values.length) idx = 0;
        themeMode = ThemeMode.values[idx];
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setSeedColor(Color c) async {
    seedColor = c;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('seedColor', c.value);
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('themeMode', m.index);
    } catch (_) {}
  }
}
