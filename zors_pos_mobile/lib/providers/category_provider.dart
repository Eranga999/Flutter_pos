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

    try {
      final res = await ApiService.getCategories();
      if (res['success'] == true) {
        final data = res['data'];
        _categories.clear();

        if (data is List) {
          _categories.addAll(
            data.map((j) => Category.fromJson(j as Map<String, dynamic>)),
          );
        }
        _error = null;
      } else {
        _error = res['message']?.toString() ?? 'Failed to load categories';
      }
    } catch (e) {
      _error = 'Error fetching categories: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> createCategory(String name) async {
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService.createCategory(name);
      if (res['success'] == true) {
        final data = res['data'];
        // Handle different response formats
        Map<String, dynamic>? catJson;
        if (data is Map<String, dynamic>) {
          catJson =
              data['category'] as Map<String, dynamic>? ??
              data['data'] as Map<String, dynamic>? ??
              data;
        }
        if (catJson != null) {
          _categories.add(Category.fromJson(catJson));
          notifyListeners();
        }
        return true;
      } else {
        _error = res['message']?.toString() ?? 'Failed to create category';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error creating category: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCategory(String id, String name) async {
    try {
      final res = await ApiService.updateCategory(id, {'name': name});
      if (res['success'] == true) {
        final data = res['data'];
        Map<String, dynamic>? catJson;
        if (data is Map<String, dynamic>) {
          catJson =
              data['category'] as Map<String, dynamic>? ??
              data['data'] as Map<String, dynamic>? ??
              data;
        }
        if (catJson != null) {
          final updated = Category.fromJson(catJson);
          final idx = _categories.indexWhere((c) => c.id == id);
          if (idx != -1) {
            _categories[idx] = updated;
            notifyListeners();
          }
        }
        return true;
      }
      _error = res['message']?.toString();
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error updating category: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      final res = await ApiService.deleteCategory(id);
      if (res['success'] == true) {
        _categories.removeWhere((c) => c.id == id);
        notifyListeners();
        return true;
      }
      _error = res['message']?.toString();
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error deleting category: $e';
      notifyListeners();
      return false;
    }
  }
}
