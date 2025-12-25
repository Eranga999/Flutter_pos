import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReportsProvider extends ChangeNotifier {
  bool _loading = false;
  String? _error;
  String _dateFilter = '30'; // Default: Last 30 days

  // Revenue metrics
  double _totalRevenue = 0;
  double _totalProfit = 0;
  double _avgOrderValue = 0;
  int _totalOrders = 0;
  double _todayRevenue = 0;

  // Top products
  List<Map<String, dynamic>> _topProducts = [];

  // Daily revenue
  List<Map<String, dynamic>> _dailyRevenue = [];

  // Summary stats
  Map<String, dynamic> _summaryStats = {};

  // Business insights
  double _profitMargin = 0;
  double _customerSatisfaction = 0;
  double _growthRate = 0;

  bool get loading => _loading;
  String? get error => _error;
  String get dateFilter => _dateFilter;

  double get totalRevenue => _totalRevenue;
  double get totalProfit => _totalProfit;
  double get avgOrderValue => _avgOrderValue;
  int get totalOrders => _totalOrders;

  List<Map<String, dynamic>> get topProducts => List.unmodifiable(_topProducts);
  List<Map<String, dynamic>> get dailyRevenue =>
      List.unmodifiable(_dailyRevenue);
  Map<String, dynamic> get summaryStats => Map.unmodifiable(_summaryStats);

  double get profitMargin => _profitMargin;
  double get customerSatisfaction => _customerSatisfaction;
  double get growthRate => _growthRate;
  double get todayRevenue => _todayRevenue;

  Future<void> fetchReports(String? days) async {
    if (days != null) {
      _dateFilter = days;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService.getOrders();
      if (res['success'] != true) {
        _error = res['message']?.toString() ?? 'Failed to fetch reports';
        _loading = false;
        notifyListeners();
        return;
      }

      final orders =
          (res['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      // Parse date filter
      final daysInt = int.tryParse(_dateFilter) ?? 30;
      final cutoffDate = DateTime.now().subtract(Duration(days: daysInt));

      // Filter orders by date
      final filteredOrders = orders.where((order) {
        final createdAt = order['createdAt'];
        if (createdAt == null) return false;
        try {
          final orderDate = DateTime.parse(createdAt.toString()).toLocal();
          return orderDate.isAfter(cutoffDate);
        } catch (_) {
          return false;
        }
      }).toList();

      _totalOrders = filteredOrders.length;
      _todayRevenue = 0;

      // Calculate totals
      _totalRevenue = 0;
      final productMap = <String, Map<String, dynamic>>{};

      for (final order in filteredOrders) {
        final totalAmount = order['totalAmount'] ?? 0;
        _totalRevenue += (totalAmount as num).toDouble();

        // Today revenue
        try {
          final orderDate = DateTime.parse(
            order['createdAt'].toString(),
          ).toLocal();
          final now = DateTime.now();
          final isToday =
              orderDate.year == now.year &&
              orderDate.month == now.month &&
              orderDate.day == now.day;
          if (isToday) {
            _todayRevenue += (totalAmount).toDouble();
          }
        } catch (_) {}

        // Track products
        final cart = order['cart'] as List<dynamic>?;
        if (cart != null) {
          for (final item in cart) {
            final itemMap = item as Map<String, dynamic>;

            // Robustly extract product fields with fallbacks
            final productName =
                (itemMap['productName'] ??
                        itemMap['name'] ??
                        (itemMap['product'] is Map
                            ? (itemMap['product'] as Map)['name']
                            : null) ??
                        'Unknown')
                    .toString();

            final quantity =
                (itemMap['quantity'] ?? itemMap['qty'] ?? 0) as num;
            final unitPrice =
                (itemMap['unitPrice'] ??
                        itemMap['price'] ??
                        itemMap['sellingPrice'] ??
                        (itemMap['product'] is Map
                            ? (itemMap['product'] as Map)['sellingPrice']
                            : 0) ??
                        0)
                    as num;

            final revenue = (quantity.toDouble() * unitPrice.toDouble());

            if (productMap.containsKey(productName)) {
              productMap[productName]!['quantity'] =
                  (productMap[productName]!['quantity'] as num) + quantity;
              productMap[productName]!['revenue'] =
                  (productMap[productName]!['revenue'] as num) + revenue;
              // Keep last seen unit price
              productMap[productName]!['price'] = unitPrice;
            } else {
              productMap[productName] = {
                'name': productName,
                'quantity': quantity,
                'revenue': revenue,
                'price': unitPrice,
              };
            }
          }
        }
      }

      // Top 5 products
      _topProducts = productMap.values.toList()
        ..sort(
          (a, b) => (b['quantity'] as num).compareTo(a['quantity'] as num),
        );
      _topProducts = _topProducts.take(5).toList();

      _totalProfit = _totalRevenue * 0.3; // Assume 30% profit margin
      _avgOrderValue = _totalOrders > 0 ? _totalRevenue / _totalOrders : 0;

      // Daily revenue
      _dailyRevenue = _calculateDailyRevenue(filteredOrders);

      // Summary stats
      _summaryStats = {
        'completedOrders': _totalOrders,
        'activeProducts': productMap.length,
        'totalCustomers': _estimateCustomers(filteredOrders),
      };

      // Calculate real business insights
      _calculateBusinessInsights(orders, filteredOrders, daysInt);

      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  List<Map<String, dynamic>> _calculateDailyRevenue(
    List<Map<String, dynamic>> orders,
  ) {
    final dailyMap = <String, double>{};

    for (final order in orders) {
      final createdAt = order['createdAt'];
      if (createdAt == null) continue;

      try {
        final date = DateTime.parse(createdAt.toString()).toLocal();
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final amount = (order['totalAmount'] ?? 0) as num;
        dailyMap[dateKey] = (dailyMap[dateKey] ?? 0) + amount.toDouble();
      } catch (_) {
        continue;
      }
    }

    return dailyMap.entries
        .map((e) => {'date': e.key, 'revenue': e.value})
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  int _estimateCustomers(List<Map<String, dynamic>> orders) {
    // Rough estimate: assume 1 customer per order
    return orders.length;
  }

  void setDateFilter(String days) {
    _dateFilter = days;
  }

  void _calculateBusinessInsights(
    List<Map<String, dynamic>> allOrders,
    List<Map<String, dynamic>> filteredOrders,
    int daysInt,
  ) {
    // 1. Profit Margin: (Total Profit / Total Revenue) * 100
    // Assuming 35% cost of goods, 65% margin
    if (_totalRevenue > 0) {
      _profitMargin = (_totalProfit / _totalRevenue) * 100;
    } else {
      _profitMargin = 0;
    }

    // 2. Customer Satisfaction: Based on successful orders
    // Assuming all completed orders = satisfied customers
    // Scale 1-5 based on successful order percentage
    int completedOrders = 0;
    for (final order in filteredOrders) {
      final status = order['status']?.toString().toLowerCase() ?? 'completed';
      if (status == 'completed') completedOrders++;
    }
    if (_totalOrders > 0) {
      final satisfactionRate = (completedOrders / _totalOrders);
      _customerSatisfaction = 3.0 + (satisfactionRate * 2.0);
      if (_customerSatisfaction > 5.0) _customerSatisfaction = 5.0;
    } else {
      _customerSatisfaction = 0;
    }

    // 3. Growth Rate: Compare current period with previous period
    final previousPeriodStart = DateTime.now().subtract(
      Duration(days: daysInt * 2),
    );
    final previousPeriodEnd = DateTime.now().subtract(Duration(days: daysInt));

    double previousRevenue = 0;
    for (final order in allOrders) {
      final createdAt = order['createdAt'];
      if (createdAt == null) continue;

      try {
        final orderDate = DateTime.parse(createdAt.toString());
        if (orderDate.isAfter(previousPeriodStart) &&
            orderDate.isBefore(previousPeriodEnd)) {
          final totalAmount = order['totalAmount'] ?? 0;
          previousRevenue += (totalAmount as num).toDouble();
        }
      } catch (_) {
        continue;
      }
    }

    if (previousRevenue > 0) {
      _growthRate = ((_totalRevenue - previousRevenue) / previousRevenue) * 100;
    } else {
      _growthRate = _totalRevenue > 0 ? 100 : 0;
    }
  }
}
