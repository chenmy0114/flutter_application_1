import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clipboard/clipboard.dart';
import 'db.dart';
import 'encryption_utils.dart';

class ImportExportPage extends StatefulWidget {
  const ImportExportPage({super.key});

  @override
  State<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends State<ImportExportPage> {
  final RecordsDatabase _dbHelper = RecordsDatabase.instance;
  final TextEditingController _dataController = TextEditingController();
  bool _isLoading = false;
  int _charCount = 0; // 单独维护字符数，用于实时更新

  @override
  void initState() {
    super.initState();
    // 监听文本框内容变化，实时更新字符数
    _dataController.addListener(() {
      setState(() {
        _charCount = _dataController.text.length;
      });
    });
  }

  @override
  void dispose() {
    // 移除监听，防止内存泄漏
    _dataController.removeListener(() {});
    _dataController.dispose();
    super.dispose();
  }

  // 导出数据并填充到文本框
  Future<void> _exportData() async {
    setState(() => _isLoading = true);
    try {
      // 1. 获取所有数据
      final data = await _dbHelper.exportAllData();
      // 2. 加密数据
      final encryptedData = EncryptionUtils.encryptData(data);
      // 3. 填充到文本框
      setState(() {
        _dataController.text = encryptedData;
        // 强制更新字符数（兜底）
        _charCount = encryptedData.length;
      });
      // 4. 复制到剪贴板
      await FlutterClipboard.copy(encryptedData);
      // 5. 提示成功
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("数据已加密并显示在文本框（已复制到剪贴板）！"),
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("导出失败: $e"), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 导入数据（解析文本框中的加密数据）
  Future<void> _importData() async {
    final encryptedString = _dataController.text.trim();
    if (encryptedString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("文本框不能为空，请粘贴加密数据！"),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. 解密文本框中的数据
      final decryptedData = EncryptionUtils.decryptData(encryptedString);
      if (decryptedData == null) {
        throw Exception("数据解密失败，请检查加密字符串格式是否正确！");
      }

      // 2. 导入数据库
      await _dbHelper.importData(decryptedData);

      // 3. 提示成功并清空文本框
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("数据导入成功！"), behavior: SnackBarBehavior.floating),
        );
        _dataController.clear();
        // 清空后更新字符数
        _charCount = 0;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("导入失败: $e"), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 粘贴剪贴板内容到文本框
  Future<void> _pasteFromClipboard() async {
    if (_isLoading) return;
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      setState(() {
        _dataController.text = clipboardData!.text!;
        _charCount = clipboardData.text!.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("已从剪贴板粘贴数据！"), behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("剪贴板为空！"), behavior: SnackBarBehavior.floating),
      );
    }
  }

  // 清空文本框
  void _clearText() {
    if (_isLoading) return;
    _dataController.clear();
    setState(() {
      _charCount = 0;
    });
  }

  // 复制文本框全部内容到剪贴板
  Future<void> _copyAllText() async {
    if (_isLoading || _dataController.text.isEmpty) return;
    await FlutterClipboard.copy(_dataController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("已复制文本框内容到剪贴板！"), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("数据导入导出"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 功能说明
            const Text(
              "加密数据区域",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "• 点击导出：加密后的记账数据会显示在此框（并复制到剪贴板）\n• 粘贴其他设备的加密数据后，点击导入即可解析并导入数据库",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // 核心数据文本框（导出显示/导入输入）
            Stack(
              children: [
                TextField(
                  controller: _dataController,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: "加密后的记账数据会显示在这里，或粘贴其他设备的加密数据到这里...",
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Color.fromARGB(255, 169, 211, 246), width: 2),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 复制文本框全部内容按钮
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: _copyAllText,
                          tooltip: "复制全部内容",
                        ),
                        // 粘贴按钮
                        IconButton(
                          icon: const Icon(Icons.paste),
                          onPressed: _pasteFromClipboard,
                          tooltip: "粘贴剪贴板内容",
                        ),
                        // 清空按钮
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearText,
                          tooltip: "清空内容",
                        ),
                      ],
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  enabled: !_isLoading,
                  style: const TextStyle(fontSize: 14),
                ),
                // 实时更新的字符数统计（右下角）
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "字符数: $_charCount", // 使用实时更新的_charCount
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 按钮区域
            Row(
              children: [
                // 导出按钮
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _exportData,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      //backgroundColor: Colors.green,
                      //foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : const Text(
                            "导出并加密数据",
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
                // 导入按钮
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _importData,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      //backgroundColor: Colors.blue,
                      //foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : const Text(
                            "解密并导入数据",
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
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
}
