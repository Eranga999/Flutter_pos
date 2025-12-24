import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ApiService.getProducts();
      if (result['success']) {
        _products = (result['data'] as List)
            .map((p) => Product.fromJson(p))
            .toList();
        _error = null;
      } else {
        _error = result['message'];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh products from backend (used after order completion)
  Future<void> refreshProducts() async {
    try {
      final result = await ApiService.getProducts();
      if (result['success']) {
        _products = (result['data'] as List)
            .map((p) => Product.fromJson(p))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing products: $e');
    }
  }

  Future<void> fetchCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ApiService.getCategories();
      if (result['success']) {
        _categories = (result['data'] as List)
            .map((c) => Category.fromJson(c))
            .toList();
        _error = null;
      } else {
        _error = result['message'];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createProduct(Product product) async {
    try {
      final result = await ApiService.createProduct(product.toJson());
      if (result['success']) {
        final created = (result['data']?['product']) ?? result['data'];
        if (created != null) {
          _products.add(Product.fromJson(created));
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(String id, Product product) async {
    try {
      final result = await ApiService.updateProduct(id, product.toJson());
      if (result['success']) {
        final updated = (result['data']?['product']) ?? result['data'];
        final index = _products.indexWhere((p) => p.id == id);
        if (index != -1 && updated != null) {
          _products[index] = Product.fromJson(updated);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      final result = await ApiService.deleteProduct(id);
      if (result['success']) {
        _products.removeWhere((p) => p.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Product? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Product> searchProducts(String query) {
    return _products
        .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // Optimistically apply stock deductions for the given product quantities
  void applyStockDeduction(Map<String, int> qtyByProductId) {
    bool changed = false;
    qtyByProductId.forEach((productId, qty) {
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        final p = _products[index];
        final newStock = (p.stock - qty);
        _products[index] = Product(
          id: p.id,
          name: p.name,
          description: p.description,
          category: p.category,
          costPrice: p.costPrice,
          sellingPrice: p.sellingPrice,
          stock: newStock < 0 ? 0 : newStock,
          minStock: p.minStock,
          barcode: p.barcode,
          image: p.image,
          supplier: p.supplier,
          discount: p.discount,
          size: p.size,
          dryfood: p.dryfood,
          createdAt: p.createdAt,
          updatedAt: DateTime.now(),
        );
        changed = true;
      }
    });
    if (changed) notifyListeners();
  }
}
