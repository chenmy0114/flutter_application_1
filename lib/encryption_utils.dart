import 'dart:convert';
import 'dart:math'; // 新增：导入Random所需的库
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

class EncryptionUtils {
  // 加密密钥（建议改为从安全存储读取，此处为示例）
  static const String _secretKey = "8e7d2a9f4c8b7e3d1f9a8b7c6d5e4f3a";

  // 获取加密配置
  static Encrypter _getEncrypter() {
    final key = Key.fromUtf8(_secretKey);
    final iv = IV.fromLength(16); // 初始化向量
    return Encrypter(AES(key, mode: AESMode.cbc));
  }

  // 加密数据
  static String encryptData(Map<String, dynamic> data) {
    final encrypter = _getEncrypter();
    final iv = IV.fromLength(16);

    // 转换为JSON字符串
    final jsonString = json.encode(data);
    // 加密
    final encrypted = encrypter.encrypt(jsonString, iv: iv);

    // 组合IV和加密数据（解密时需要IV）
    final ivBase64 = iv.base64;
    final encryptedBase64 = encrypted.base64;

    // 返回组合后的字符串
    return "$ivBase64:$encryptedBase64";
  }

  // 解密数据
  static Map<String, dynamic>? decryptData(String encryptedString) {
    try {
      final encrypter = _getEncrypter();

      // 拆分IV和加密数据
      final parts = encryptedString.split(":");
      if (parts.length != 2) return null;

      final iv = IV.fromBase64(parts[0]);
      final encrypted = Encrypted.fromBase64(parts[1]);

      // 解密
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      // 转换为Map
      return json.decode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      print("解密失败: $e");
      return null;
    }
  }

  // 生成32位随机密钥（用于初始化）
  static String generateRandomKey() {
    final randomBytes = Uint8List(32);
    final secureRandom = Random.secure(); // 现在可正常使用
    for (int i = 0; i < 32; i++) {
      randomBytes[i] = secureRandom.nextInt(256);
    }
    return base64.encode(randomBytes).substring(0, 32);
  }
}
