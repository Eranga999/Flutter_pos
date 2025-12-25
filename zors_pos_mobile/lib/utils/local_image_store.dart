import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalImageStore {
  static const String _keyPrefix = 'product_image_';
  static const String _extKeyPrefix = 'product_image_ext_';
  static const String _folderName = 'product_images';

  static Future<void> saveProductImage(
    String productId,
    Uint8List bytes, {
    String? extension,
  }) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final b64 = base64Encode(bytes);
      await prefs.setString('$_keyPrefix$productId', b64);
      if (extension != null && extension.isNotEmpty) {
        await prefs.setString('$_extKeyPrefix$productId', extension);
      }
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = io.Directory('${dir.path}/$_folderName');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final ext = (extension ?? 'png').replaceAll('.', '');
      final file = io.File('${imagesDir.path}/$productId.$ext');
      await file.writeAsBytes(bytes, flush: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_extKeyPrefix$productId', ext);
    } catch (_) {
      // Fallback to SharedPreferences if file write fails
      final prefs = await SharedPreferences.getInstance();
      final b64 = base64Encode(bytes);
      await prefs.setString('$_keyPrefix$productId', b64);
      if (extension != null && extension.isNotEmpty) {
        await prefs.setString('$_extKeyPrefix$productId', extension);
      }
    }
  }

  static Future<Uint8List?> getProductImage(String productId) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final b64 = prefs.getString('$_keyPrefix$productId');
        if (b64 == null || b64.isEmpty) return null;
        return base64Decode(b64);
      } catch (_) {
        return null;
      }
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final prefs = await SharedPreferences.getInstance();
      final ext = prefs.getString('$_extKeyPrefix$productId') ?? 'png';
      final file = io.File('${dir.path}/$_folderName/$productId.$ext');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      // Fallback: try preferences
      final b64 = prefs.getString('$_keyPrefix$productId');
      if (b64 == null || b64.isEmpty) return null;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  static Future<void> removeProductImage(String productId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyPrefix$productId');
      await prefs.remove('$_extKeyPrefix$productId');
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final prefs = await SharedPreferences.getInstance();
      final ext = prefs.getString('$_extKeyPrefix$productId') ?? 'png';
      final file = io.File('${dir.path}/$_folderName/$productId.$ext');
      if (await file.exists()) {
        await file.delete();
      }
      await prefs.remove('$_extKeyPrefix$productId');
      await prefs.remove('$_keyPrefix$productId');
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyPrefix$productId');
      await prefs.remove('$_extKeyPrefix$productId');
    }
  }
}
