import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show FontFeature;
import 'dart:convert' show base64Decode;
import 'dart:typed_data' show Uint8List;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';
import 'add_product_screen.dart';
import '../services/api_service.dart';
import '../utils/local_image_store.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  String? _selectedCategoryFilter;
  String _stockFilter = 'all'; // 'all', 'low', 'inStock', 'outOfStock'
  bool _initialized = false;
  bool _isSearchFocused = false;

  // Animation controllers
  late AnimationController _headerController;
  late AnimationController _contentController;

  late Animation<double> _headerAnimation;
  late Animation<double> _contentAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setupSearchListener();
  }

  void _initAnimations() {
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _contentAnimation = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _contentController.forward();
    });
  }

  void _setupSearchListener() {
    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        provider.fetchProducts();
        provider.fetchCategories();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _headerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // Search products by name OR barcode
  List<Product> _searchProducts(List<Product> products, String query) {
    if (query.isEmpty) return products;
    final lowerQuery = query.toLowerCase();
    return products.where((p) {
      final nameMatch = p.name.toLowerCase().contains(lowerQuery);
      final barcodeMatch =
          p.barcode != null && p.barcode!.toLowerCase().contains(lowerQuery);
      return nameMatch || barcodeMatch;
    }).toList();
  }

  void _editProduct(BuildContext context, Product product) async {
    HapticFeedback.lightImpact();
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final updated = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AddProductScreen(product: product),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    if (updated == true && mounted) {
      provider.refreshProducts();
    }
  }

  void _deleteProduct(BuildContext context, Product product) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red.shade400),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Product',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${product.name}"?\n\nThis action cannot be undone.',
          style: const TextStyle(fontSize: 15, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<ProductProvider>(
                context,
                listen: false,
              );
              await provider.deleteProduct(product.id);
              await LocalImageStore.removeProductImage(product.id);
              if (mounted) {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 12),
                        Text('${product.name} deleted'),
                      ],
                    ),
                    backgroundColor: Colors.red.shade400,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final provider = Provider.of<ProductProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF324137).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Color(0xFF324137),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Filter Products',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF324137),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Stock Status Section
                const Text(
                  'Stock Status',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF324137),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _stockFilter == 'all',
                      onTap: () => setSheetState(() => _stockFilter = 'all'),
                    ),
                    _FilterChip(
                      label: 'In Stock',
                      icon: Icons.check_circle_outline,
                      isSelected: _stockFilter == 'inStock',
                      color: const Color(0xFF35AE4A),
                      onTap: () =>
                          setSheetState(() => _stockFilter = 'inStock'),
                    ),
                    _FilterChip(
                      label: 'Low Stock',
                      icon: Icons.warning_amber_rounded,
                      isSelected: _stockFilter == 'low',
                      color: Colors.orange,
                      onTap: () => setSheetState(() => _stockFilter = 'low'),
                    ),
                    _FilterChip(
                      label: 'Out of Stock',
                      icon: Icons.error_outline,
                      isSelected: _stockFilter == 'outOfStock',
                      color: Colors.red,
                      onTap: () =>
                          setSheetState(() => _stockFilter = 'outOfStock'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Category Section
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF324137),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedCategoryFilter,
                      isExpanded: true,
                      hint: const Text('All Categories'),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      borderRadius: BorderRadius.circular(14),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ...provider.categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat.name,
                            child: Text(cat.name),
                          );
                        }),
                      ],
                      onChanged: (val) =>
                          setSheetState(() => _selectedCategoryFilter = val),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setSheetState(() {
                            _stockFilter = 'all';
                            _selectedCategoryFilter = null;
                          });
                          setState(() {});
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Clear All',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(ctx);
                          HapticFeedback.mediumImpact();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF324137),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Product> _applyFilters(List<Product> products) {
    var filtered = products;

    // Apply category filter
    if (_selectedCategoryFilter != null) {
      filtered = filtered
          .where((p) => p.category == _selectedCategoryFilter)
          .toList();
    }

    // Apply stock filter
    switch (_stockFilter) {
      case 'low':
        filtered = filtered
            .where((p) => p.stock > 0 && p.stock <= p.minStock)
            .toList();
        break;
      case 'inStock':
        filtered = filtered.where((p) => p.stock > p.minStock).toList();
        break;
      case 'outOfStock':
        filtered = filtered.where((p) => p.stock <= 0).toList();
        break;
    }

    return filtered;
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_stockFilter != 'all') count++;
    if (_selectedCategoryFilter != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);
    // Use custom search that includes barcode
    var products = _query.isEmpty
        ? provider.products
        : _searchProducts(provider.products, _query);

    // Apply filters
    products = _applyFilters(products);

    final currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);
    final totalValue = products.fold<double>(
      0,
      (sum, p) => sum + (p.sellingPrice * p.stock),
    );
    final lowStockCount = provider.products
        .where((p) => p.stock > 0 && p.stock <= p.minStock)
        .length;
    final outOfStockCount = provider.products.where((p) => p.stock <= 0).length;
    final filterCount = _getActiveFilterCount();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Animated Header
            FadeTransition(
              opacity: _headerAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.3),
                  end: Offset.zero,
                ).animate(_headerAnimation),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF324137), Color(0xFF1A2B1F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF324137).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Top Row with back button, title, and refresh
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'Inventory',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              provider.refreshProducts();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(
                                        Icons.refresh,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text('Refreshing inventory...'),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF35AE4A),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: const EdgeInsets.all(16),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Quick Stats Summary
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _QuickStat(
                              icon: Icons.inventory_2_rounded,
                              value: provider.products.length.toString(),
                              label: 'Total',
                              color: const Color(0xFFC8E260),
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            _QuickStat(
                              icon: Icons.warning_amber_rounded,
                              value: lowStockCount.toString(),
                              label: 'Low Stock',
                              color: Colors.orange,
                            ),
                            Container(
                              width: 1,
                              height: 36,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            _QuickStat(
                              icon: Icons.error_outline_rounded,
                              value: outOfStockCount.toString(),
                              label: 'Out',
                              color: Colors.red.shade300,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Modern Search Bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _isSearchFocused
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFC8E260,
                                    ).withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocusNode,
                          onChanged: (v) => setState(() => _query = v.trim()),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF324137),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by name or barcode...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: _isSearchFocused
                                  ? const Color(0xFF324137)
                                  : Colors.grey.shade400,
                            ),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _query = '');
                                      HapticFeedback.selectionClick();
                                    },
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.qr_code_2_rounded,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Barcode',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Content Area
            Expanded(
              child: FadeTransition(
                opacity: _contentAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(_contentAnimation),
                  child: Column(
                    children: [
                      // Filter Row and Value Summary
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Inventory Value',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currency.format(totalValue),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF324137),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Filter Button
                            GestureDetector(
                              onTap: () => _showFilterBottomSheet(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: filterCount > 0
                                      ? const Color(0xFF324137)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: filterCount > 0
                                        ? const Color(0xFF324137)
                                        : Colors.grey.shade300,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 18,
                                      color: filterCount > 0
                                          ? Colors.white
                                          : const Color(0xFF324137),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      filterCount > 0
                                          ? 'Filters ($filterCount)'
                                          : 'Filter',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: filterCount > 0
                                            ? Colors.white
                                            : const Color(0xFF324137),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Results Info
                      if (_query.isNotEmpty || filterCount > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFC8E260,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${products.length} result${products.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF324137),
                                  ),
                                ),
                              ),
                              if (_query.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'for "$_query"',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Products List
                      Expanded(
                        child: provider.isLoading
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFC8E260,
                                        ).withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const CircularProgressIndicator(
                                        color: Color(0xFF324137),
                                        strokeWidth: 3,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Loading inventory...',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : products.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  100,
                                ),
                                itemCount: products.length,
                                itemBuilder: (context, i) {
                                  final p = products[i];
                                  return TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: Duration(
                                      milliseconds:
                                          300 + (i * 50).clamp(0, 300),
                                    ),
                                    curve: Curves.easeOut,
                                    builder: (context, value, child) {
                                      return Opacity(
                                        opacity: value,
                                        child: Transform.translate(
                                          offset: Offset(0, 20 * (1 - value)),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _ModernProductCard(
                                        product: p,
                                        onEdit: () => _editProduct(context, p),
                                        onDelete: () =>
                                            _deleteProduct(context, p),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF35AE4A),
          foregroundColor: Colors.white,
          elevation: 6,
          onPressed: () async {
            HapticFeedback.lightImpact();
            final provider = Provider.of<ProductProvider>(
              context,
              listen: false,
            );
            final created = await Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const AddProductScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut,
                              ),
                            ),
                        child: child,
                      );
                    },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
            if (created == true && mounted) {
              provider.refreshProducts();
            }
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Add Product',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with a different name or barcode',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFC8E260).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Color(0xFF324137),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No products yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first product',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// Quick Stat widget for header
class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _QuickStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
        ),
      ],
    );
  }
}

// Filter Chip for bottom sheet
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFF324137);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : chipColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modern Product Card
class _ModernProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ModernProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final price = NumberFormat.currency(
      symbol: 'Rs ',
      decimalDigits: 2,
    ).format(product.sellingPrice);

    final isLowStock = product.stock > 0 && product.stock <= product.minStock;
    final isOutOfStock = product.stock <= 0;
    final isNew = product.createdAt.isAfter(
      DateTime.now().subtract(const Duration(days: 7)),
    );

    Color statusColor = const Color(0xFF35AE4A);
    String statusText = 'In Stock';
    if (isOutOfStock) {
      statusColor = Colors.red;
      statusText = 'Out of Stock';
    } else if (isLowStock) {
      statusColor = Colors.orange;
      statusText = 'Low Stock';
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onEdit();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOutOfStock
                ? Colors.red.withOpacity(0.3)
                : isLowStock
                ? Colors.orange.withOpacity(0.3)
                : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Stack(
                children: [
                  _ProductImage(
                    productId: product.id,
                    imagePath: product.image,
                  ),
                  if (isNew)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF35AE4A), Color(0xFF2E7D32)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 14),

              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF324137),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Tags (Category & Supplier)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (product.category.isNotEmpty)
                            _ModernTag(
                              text: product.category,
                              icon: Icons.category_rounded,
                            ),
                          if ((product.supplier ?? '').isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _ModernTag(
                              text: product.supplier!,
                              icon: Icons.store_rounded,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Price and Barcode Row
                    Row(
                      children: [
                        Text(
                          price,
                          style: const TextStyle(
                            color: Color(0xFF324137),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (product.barcode != null &&
                            product.barcode!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      product.barcode!,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Stock & Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Stock Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          product.stock.toString(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          'in stock',
                          style: TextStyle(color: statusColor, fontSize: 10),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Action Menu
                  PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (value) {
                      HapticFeedback.selectionClick();
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF324137).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: Color(0xFF324137),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text('Edit Product'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.delete_rounded,
                                size: 16,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Modern Tag
class _ModernTag extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _ModernTag({required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E260).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: const Color(0xFF324137)),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF324137),
            ),
          ),
        ],
      ),
    );
  }
}

// Product Image widget with caching
class _ProductImage extends StatefulWidget {
  final String productId;
  final String? imagePath;
  const _ProductImage({required this.productId, this.imagePath});

  @override
  State<_ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<_ProductImage> {
  Uint8List? _localBytes;
  bool _triedLocal = false;

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  @override
  void didUpdateWidget(_ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _triedLocal = false;
      _localBytes = null;
      _loadLocal();
    }
  }

  void _loadLocal() async {
    if (_triedLocal) return;
    _triedLocal = true;
    final bytes = await LocalImageStore.getProductImage(widget.productId);
    if (!mounted) return;
    setState(() => _localBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    final path = widget.imagePath;

    if (_localBytes != null) {
      child = Image.memory(
        _localBytes!,
        fit: BoxFit.cover,
        width: 72,
        height: 72,
      );
    } else if (path != null && path.isNotEmpty) {
      final isHttp = path.startsWith('http://') || path.startsWith('https://');
      final looksLikeDataUri = path.startsWith('data:');
      final looksLikeBase64 =
          !looksLikeDataUri &&
          RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(path) &&
          path.length > 50;

      if (isHttp) {
        child = Image.network(
          path,
          fit: BoxFit.cover,
          width: 72,
          height: 72,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 72,
              height: 72,
              color: const Color(0xFFC8E260).withOpacity(0.1),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF324137),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            _loadLocal();
            return Icon(
              Icons.broken_image_rounded,
              color: Colors.grey.shade400,
              size: 32,
            );
          },
        );
      } else if (looksLikeDataUri || looksLikeBase64) {
        try {
          String cleanBase64 = path.trim();
          if (cleanBase64.startsWith('data:')) {
            final parts = cleanBase64.split(',');
            if (parts.length > 1) cleanBase64 = parts[1];
          }
          cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
          final decoded = base64Decode(cleanBase64);
          child = Image.memory(
            decoded,
            fit: BoxFit.cover,
            width: 72,
            height: 72,
          );
        } catch (_) {
          _loadLocal();
          child = Icon(
            Icons.image_not_supported_rounded,
            color: Colors.grey.shade400,
            size: 32,
          );
        }
      } else {
        final url = '${ApiService.baseUrl}/products/images/$path';
        child = Image.network(
          url,
          fit: BoxFit.cover,
          width: 72,
          height: 72,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 72,
              height: 72,
              color: const Color(0xFFC8E260).withOpacity(0.1),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF324137),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            _loadLocal();
            return Icon(
              Icons.broken_image_rounded,
              color: Colors.grey.shade400,
              size: 32,
            );
          },
        );
      }
    } else {
      child = Icon(
        Icons.inventory_2_rounded,
        color: const Color(0xFF324137).withOpacity(0.4),
        size: 32,
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFC8E260).withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: child),
    );
  }
}
