import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/api_service.dart';

class CategoryProvider extends ChangeNotifier {
  final List<Category> _categories = [];
  bool _loading = false;
  String? _error;

  List<Category> get categories => List.unmodifiable(_categories);
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchCategories() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final res = await ApiService.getCategories();
    if (res['success'] == true) {
      _categories
        ..clear()
        ..addAll(
          (res['data'] as List<dynamic>).map(
            (j) => Category.fromJson(j as Map<String, dynamic>),
          ),
        );
    } else {
      _error = res['message']?.toString() ?? 'Failed to load categories';
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> createCategory(String name) async {
    _error = null;
    notifyListeners();

    final res = await ApiService.createCategory(name);
    if (res['success'] == true) {
      final data = res['data'];
      final catJson = (data is Map<String, dynamic>) && data['category'] != null
          ? data['category'] as Map<String, dynamic>
          : data as Map<String, dynamic>;
      _categories.add(Category.fromJson(catJson));
      notifyListeners();
      return true;
    } else {
      _error = res['message']?.toString() ?? 'Failed to create category';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCategory(String id, String name) async {
    final res = await ApiService.updateCategory(id, {'name': name});
    if (res['success'] == true) {
      final updated = Category.fromJson(
        (res['data']['category'] ?? res['data']) as Map<String, dynamic>,
      );
      final idx = _categories.indexWhere((c) => c.id == id);
      if (idx != -1) {
        _categories[idx] = updated;
        notifyListeners();
      }
      return true;
    }
    _error = res['message']?.toString();
    notifyListeners();
    return false;
  }

  Future<bool> deleteCategory(String id) async {
    final res = await ApiService.deleteCategory(id);
    if (res['success'] == true) {
      _categories.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    }
    _error = res['message']?.toString();
    notifyListeners();
    return false;
  }
}
