import 'package:flutter/material.dart';
import 'db.dart';
import 'models/category.dart';
import 'app_state.dart';
import 'package:provider/provider.dart';

/// Settings landing page: lists available settings items.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('设置')),
      body: ListView(
        children: [
          ListTile(
            title: Text('记账类型配置'),
            subtitle: Text('管理记账分类，支持排序/添加/删除'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CategorySettingsPage()));
            },
          ),
          ListTile(
            title: Text('主题色调整'),
            subtitle: Text('更改应用的主题主色'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => ThemeSettingsPage()));
            },
          ),
          // Add more settings items here in the future
        ],
      ),
    );
  }
}

/// Category settings page (moved from previous SettingsPage implementation)
class CategorySettingsPage extends StatefulWidget {
  const CategorySettingsPage({super.key});

  @override
  State<CategorySettingsPage> createState() => _CategorySettingsPageState();
}

class _CategorySettingsPageState extends State<CategorySettingsPage> {
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    final cats = await RecordsDatabase.instance.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _loading = false;
    });
  }

  Future<void> _addCategory() async {
    final nameCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('添加记账类型'),
        content: TextField(
            controller: nameCtl,
            decoration: InputDecoration(labelText: '类型名称')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('添加')),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtl.text.trim();
    if (name.isEmpty) return;
    try {
      await RecordsDatabase.instance.insertCategory(name, _categories.length);
      await _loadCategories();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('添加失败：$e')));
    }
  }

  Future<void> _editCategory(Category c) async {
    final ctl = TextEditingController(text: c.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑记账类型'),
        content: TextField(
            controller: ctl, decoration: InputDecoration(labelText: '类型名称')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    final newName = ctl.text.trim();
    if (newName.isEmpty) return;
    await RecordsDatabase.instance.updateCategoryName(c.id!, newName);
    await _loadCategories();
  }

  Future<void> _deleteCategory(Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除记账类型'),
        content: Text('确定删除「${c.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await RecordsDatabase.instance.deleteCategory(c.id!);
    await _loadCategories();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, item);
    // persist ordering
    for (var i = 0; i < _categories.length; i++) {
      await RecordsDatabase.instance.updateCategoryOrder(_categories[i].id!, i);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('记账类型配置')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ReorderableListView(
                    onReorder: _onReorder,
                    children: _categories
                        .map((c) => ListTile(
                              key: ValueKey(c.id),
                              title: Text(c.name),
                              leading: Icon(Icons.drag_handle),
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: Icon(Icons.edit),
                                        onPressed: () => _editCategory(c)),
                                    IconButton(
                                        icon: Icon(Icons.delete),
                                        onPressed: () => _deleteCategory(c)),
                                  ]),
                            ))
                        .toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                          onPressed: _addCategory,
                          icon: Icon(Icons.add),
                          label: Text('添加类型')),
                      SizedBox(width: 12),
                      Text('拖动以调整顺序')
                    ],
                  ),
                )
              ],
            ),
    );
  }
}

class ThemeSettingsPage extends StatefulWidget {
  ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  late int _r;
  late int _g;
  late int _b;
  late TextEditingController _hexCtl;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    final seed = Provider.of<MyAppState>(context, listen: false).seedColor;
    _r = seed.red;
    _g = seed.green;
    _b = seed.blue;
    _hexCtl = TextEditingController(text: _rgbToHex(_r, _g, _b));
    _themeMode = Provider.of<MyAppState>(context, listen: false).themeMode;
  }

  @override
  void dispose() {
    _hexCtl.dispose();
    super.dispose();
  }

  String _rgbToHex(int r, int g, int b) =>
      '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

  Color _currentColor() => Color.fromARGB(0xFF, _r, _g, _b);

  void _applyColor(Color c) {
    Provider.of<MyAppState>(context, listen: false).setSeedColor(c);
  }

  void _onHexChanged(String v) {
    final hex = v.replaceAll('#', '').trim();
    if (hex.length == 6) {
      try {
        final val = int.parse(hex, radix: 16);
        setState(() {
          _r = (val >> 16) & 0xFF;
          _g = (val >> 8) & 0xFF;
          _b = val & 0xFF;
        });
        _applyColor(_currentColor());
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _currentColor();
    return Scaffold(
      appBar: AppBar(title: Text('主题色调整')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            SizedBox(height: 8),
            Text('拖动滑块或输入 HEX 代码选择任意颜色', style: TextStyle(fontSize: 14)),
            SizedBox(height: 12),
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: preview,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              alignment: Alignment.center,
              child: Text(_rgbToHex(_r, _g, _b),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
            ),
            SizedBox(height: 12),
            _buildSlider('R', _r, (v) {
              setState(() => _r = v);
              _hexCtl.text = _rgbToHex(_r, _g, _b);
              _applyColor(_currentColor());
            }),
            _buildSlider('G', _g, (v) {
              setState(() => _g = v);
              _hexCtl.text = _rgbToHex(_r, _g, _b);
              _applyColor(_currentColor());
            }),
            _buildSlider('B', _b, (v) {
              setState(() => _b = v);
              _hexCtl.text = _rgbToHex(_r, _g, _b);
              _applyColor(_currentColor());
            }),
            SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _hexCtl,
                  decoration: InputDecoration(labelText: 'HEX (例如 #FF3366)'),
                  onChanged: _onHexChanged,
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  _applyColor(_currentColor());
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('已应用颜色 ${_rgbToHex(_r, _g, _b)}'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                child: Text('应用'),
              )
            ]),
            SizedBox(height: 10),
            // Theme mode selection
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('跟随系统'),
                  value: ThemeMode.system,
                  groupValue: _themeMode,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _themeMode = v);
                    Provider.of<MyAppState>(context, listen: false)
                        .setThemeMode(v);
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: Text('浅色模式'),
                  value: ThemeMode.light,
                  groupValue: _themeMode,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _themeMode = v);
                    Provider.of<MyAppState>(context, listen: false)
                        .setThemeMode(v);
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: Text('深色模式'),
                  value: ThemeMode.dark,
                  groupValue: _themeMode,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _themeMode = v);
                    Provider.of<MyAppState>(context, listen: false)
                        .setThemeMode(v);
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 28, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            label: value.toString(),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
            width: 44,
            child: Text(value.toString(), textAlign: TextAlign.right)),
      ],
    );
  }
}
