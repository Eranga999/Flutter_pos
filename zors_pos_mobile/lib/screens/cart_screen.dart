import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../services/api_service.dart';
import '../models/discount.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _searchController = TextEditingController();
  final String _selectedPaymentMethod = 'cash';
  List<Discount> _discounts = [];
  Discount? _selectedDiscount;
  Discount? _globalDiscount;
  bool _loadingDiscounts = false;
  double _lastDiscountAmount = 0.0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchDiscounts();
  }

  Future<void> _fetchDiscounts() async {
    setState(() => _loadingDiscounts = true);
    final res = await ApiService.getDiscounts();
    if (res['success'] == true) {
      final list = (res['data'] as List)
          .map((d) => Discount.fromJson(d))
          .where((d) => d.isActive)
          .toList();

      // Identify global discount by flag
      final global = list.firstWhere(
        (d) => d.isGlobal,
        orElse: () => Discount(
          id: '',
          codeOrName: '',
          description: null,
          discountType: 'fixed',
          discountValue: 0,
          minAmount: null,
          maxUses: null,
          usedCount: 0,
          isActive: false,
          isGlobal: false,
        ),
      );
      setState(() {
        _discounts = list.where((d) => !d.isGlobal).toList();
        _globalDiscount = global.isActive && global.isGlobal ? global : null;
        _selectedDiscount = null;
        _loadingDiscounts = false;
      });
    } else {
      setState(() => _loadingDiscounts = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to load discounts')),
        );
      }
    }
  }

  void _handleNewOrder() {
    context.read<OrderProvider>().clearCart();
    _searchController.clear();
    setState(() {
      _selectedDiscount = null;
    });
  }

  double _computeDiscountAmount(double subtotal) {
    double amount = 0.0;
    // Selected discount
    if (_selectedDiscount != null) {
      final d = _selectedDiscount!;
      if (d.minAmount == null || subtotal >= (d.minAmount ?? 0)) {
        amount += d.discountType == 'percentage'
            ? (subtotal * d.discountValue) / 100
            : d.discountValue;
      }
    }
    // Global discount (automatic)
    if (_globalDiscount != null) {
      final g = _globalDiscount!;
      if (g.minAmount == null || subtotal >= (g.minAmount ?? 0)) {
        amount += g.discountType == 'percentage'
            ? (subtotal * g.discountValue) / 100
            : g.discountValue;
      }
    }
    return amount;
  }

  void _handleProceedToCheckout() {
    final orderProvider = context.read<OrderProvider>();
    if (orderProvider.cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }

    // Navigate to checkout screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CheckoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: SafeArea(
        child: Consumer<OrderProvider>(
          builder: (context, orderProvider, _) {
            // Calculate totals
            final subtotal = orderProvider.cartItems.fold<double>(
              0.0,
              (sum, item) => sum + (item.unitPrice * item.quantity),
            );
            final discountAmount = _computeDiscountAmount(subtotal);

            // Update discount only if it changed
            if (_lastDiscountAmount != discountAmount) {
              _lastDiscountAmount = discountAmount;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                orderProvider.setDiscount(discountAmount);
              });
            }

            final total = subtotal - discountAmount;

            return Column(
              children: [
                // Header with Back Button, "Active Orders" title
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF324137),
                        const Color(0xFF000000),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Back Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title
                      const Expanded(
                        child: Text(
                          'Active Orders',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: orderProvider.cartItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Your cart is empty',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cart Items Section
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.grey[200]!,
                                    width: 0.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: orderProvider.cartItems.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Colors.grey[200],
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                                  itemBuilder: (context, index) {
                                    final item = orderProvider.cartItems[index];
                                    return Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.productName,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF324137,
                                                        ),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'x${item.quantity} • Product',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    'Rs. ${item.unitPrice.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF324137),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  GestureDetector(
                                                    onTap: () {
                                                      context
                                                          .read<OrderProvider>()
                                                          .removeFromCart(
                                                            item.productId,
                                                          );
                                                    },
                                                    child: const Text(
                                                      'Remove',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Live Bill Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC8E260),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFC8E260,
                                      ).withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Live Bill (${orderProvider.cartItems.length})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Product Search Bar
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Scan barcode or type product code...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1.6,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1.6,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFC8E260),
                                      width: 1.6,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Quantity Selector for each item in cart
                              if (orderProvider.cartItems.isNotEmpty)
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: orderProvider.cartItems.length,
                                  itemBuilder: (context, index) {
                                    final item = orderProvider.cartItems[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[200]!,
                                            width: 1.6,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.08,
                                              ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 16,
                                                ),
                                                child: Text(
                                                  item.productName,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF324137),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                IconButton(
                                                  onPressed: () {
                                                    if (item.quantity > 1) {
                                                      context
                                                          .read<OrderProvider>()
                                                          .updateCartItemQuantity(
                                                            item.productId,
                                                            item.quantity - 1,
                                                          );
                                                    }
                                                  },
                                                  icon: const Icon(
                                                    Icons.remove,
                                                  ),
                                                  color: const Color(
                                                    0xFF324137,
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8,
                                                      ),
                                                  child: Text(
                                                    '${item.quantity}',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () {
                                                    context
                                                        .read<OrderProvider>()
                                                        .updateCartItemQuantity(
                                                          item.productId,
                                                          item.quantity + 1,
                                                        );
                                                  },
                                                  icon: const Icon(Icons.add),
                                                  color: const Color(
                                                    0xFF324137,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              const SizedBox(height: 16),

                              // Discount Selection (from backend)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey[200]!,
                                    width: 1.6,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Discount',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF324137),
                                          ),
                                        ),
                                        if (_loadingDiscounts)
                                          const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        else
                                          TextButton(
                                            onPressed: _fetchDiscounts,
                                            child: const Text('Refresh'),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<Discount?>(
                                      initialValue: _selectedDiscount,
                                      items: [
                                        const DropdownMenuItem<Discount?>(
                                          value: null,
                                          child: Text('No Discount'),
                                        ),
                                        ..._discounts.map(
                                          (d) => DropdownMenuItem<Discount?>(
                                            value: d,
                                            child: Text(
                                              d.discountType == 'percentage'
                                                  ? '${d.codeOrName} - ${d.discountValue.toStringAsFixed(0)}%'
                                                  : '${d.codeOrName} - Rs. ${d.discountValue.toStringAsFixed(2)}',
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedDiscount = val;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                            width: 1.6,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                            width: 1.6,
                                          ),
                                        ),
                                        focusedBorder: const OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(12),
                                          ),
                                          borderSide: BorderSide(
                                            color: Color(0xFFC8E260),
                                            width: 1.6,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                      ),
                                    ),
                                    if (_globalDiscount != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Global Discount automatically applied: '
                                        '${_globalDiscount!.discountType == 'percentage' ? '${_globalDiscount!.discountValue.toStringAsFixed(0)}%' : 'Rs. ${_globalDiscount!.discountValue.toStringAsFixed(2)}'}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Order Summary
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.grey[200]!,
                                    width: 0.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Subtotal',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF324137),
                                          ),
                                        ),
                                        Text(
                                          'Rs. ${subtotal.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF324137),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Discount',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF324137),
                                          ),
                                        ),
                                        Text(
                                          '- Rs. ${discountAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF324137),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4FFF0),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFC8E260),
                                          width: 1.6,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Total',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF324137),
                                            ),
                                          ),
                                          Text(
                                            'Rs. ${total.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF324137),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Proceed to Checkout Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _handleProceedToCheckout,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF324137),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text(
                                    'Proceed to Checkout',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
