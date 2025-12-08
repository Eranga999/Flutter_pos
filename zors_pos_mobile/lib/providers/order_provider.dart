import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<OrderItem> _cartItems = [];
  double _subtotal = 0.0;
  double _tax = 0.0;
  double _discount = 0.0;
  String _paymentMethod = 'cash';
  List<Order> _orders = [];
  bool _isLoading = false;

  List<OrderItem> get cartItems => _cartItems;
  double get subtotal => _subtotal;
  double get tax => _tax;
  double get discount => _discount;
  double get total => _subtotal + _tax - _discount;
  String get paymentMethod => _paymentMethod;
  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;

  void addToCart(String productId, String productName, int quantity, double unitPrice) {
    final existingIndex = _cartItems.indexWhere((item) => item.productId == productId);

    if (existingIndex != -1) {
      _cartItems[existingIndex] = OrderItem(
        productId: productId,
        productName: productName,
        quantity: _cartItems[existingIndex].quantity + quantity,
        unitPrice: unitPrice,
        total: (_cartItems[existingIndex].quantity + quantity) * unitPrice,
      );
    } else {
      _cartItems.add(OrderItem(
        productId: productId,
        productName: productName,
        quantity: quantity,
        unitPrice: unitPrice,
        total: quantity * unitPrice,
      ));
    }
    _calculateTotals();
  }

  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.productId == productId);
    _calculateTotals();
  }

  void updateCartItemQuantity(String productId, int quantity) {
    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index != -1) {
      if (quantity <= 0) {
        removeFromCart(productId);
      } else {
        _cartItems[index] = OrderItem(
          productId: _cartItems[index].productId,
          productName: _cartItems[index].productName,
          quantity: quantity,
          unitPrice: _cartItems[index].unitPrice,
          total: quantity * _cartItems[index].unitPrice,
        );
        _calculateTotals();
      }
    }
  }

  void _calculateTotals() {
    _subtotal = _cartItems.fold(0, (sum, item) => sum + item.total);
    _tax = _subtotal * 0.1; // 10% tax
    notifyListeners();
  }

  void setDiscount(double discount) {
    _discount = discount;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _subtotal = 0.0;
    _tax = 0.0;
    _discount = 0.0;
    notifyListeners();
  }

  Future<bool> checkout(String customerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final orderData = {
        'customerId': customerId,
        'items': _cartItems.map((item) => item.toJson()).toList(),
        'subtotal': _subtotal,
        'tax': _tax,
        'discount': _discount,
        'total': total,
        'paymentMethod': _paymentMethod,
      };

      final result = await ApiService.createOrder(orderData);
      if (result['success']) {
        clearCart();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await ApiService.getOrders();
      if (result['success']) {
        _orders = (result['data'] as List)
            .map((o) => Order.fromJson(o))
            .toList();
      }
    } catch (e) {
      //
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
