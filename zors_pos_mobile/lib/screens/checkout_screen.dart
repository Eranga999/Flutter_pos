import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../services/api_service.dart';
import 'receipt_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with TickerProviderStateMixin {
  String _selectedPaymentMethod = 'cash';
  bool _isProcessing = false;
  final TextEditingController _cashGivenController = TextEditingController();
  final TextEditingController _cardReferenceController =
      TextEditingController();
  final TextEditingController _customerNameController = TextEditingController(
    text: "CUSTOMER",
  );
  final TextEditingController _discountController = TextEditingController(
    text: "0",
  );

  // Focus nodes
  final FocusNode _customerNameFocusNode = FocusNode();
  final FocusNode _cashFocusNode = FocusNode();
  final FocusNode _cardFocusNode = FocusNode();
  final FocusNode _discountFocusNode = FocusNode();
  bool _isCustomerNameFocused = false;
  bool _isCashFocused = false;
  bool _isCardFocused = false;
  bool _isDiscountFocused = false;

  // Animation controllers
  late AnimationController _headerController;
  late AnimationController _contentController;
  late Animation<double> _headerAnimation;
  late Animation<double> _contentAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setupFocusListeners();
  }

  void _initAnimations() {
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _contentAnimation = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _contentController.forward();
    });
  }

  void _setupFocusListeners() {
    _customerNameFocusNode.addListener(() {
      setState(() => _isCustomerNameFocused = _customerNameFocusNode.hasFocus);
    });
    _cashFocusNode.addListener(() {
      setState(() => _isCashFocused = _cashFocusNode.hasFocus);
    });
    _cardFocusNode.addListener(() {
      setState(() => _isCardFocused = _cardFocusNode.hasFocus);
    });
    _discountFocusNode.addListener(() {
      setState(() => _isDiscountFocused = _discountFocusNode.hasFocus);
    });
  }

  void _applyDiscount() {
    final discountAmount =
        double.tryParse(_discountController.text.trim()) ?? 0.0;
    context.read<OrderProvider>().setDiscount(discountAmount);
  }

  @override
  void dispose() {
    _cashGivenController.dispose();
    _cardReferenceController.dispose();
    _customerNameController.dispose();
    _discountController.dispose();
    _customerNameFocusNode.dispose();
    _cashFocusNode.dispose();
    _cardFocusNode.dispose();
    _discountFocusNode.dispose();
    _headerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('userData');
      if (userJson != null) {
        return jsonDecode(userJson) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting current user: $e');
    }
    return null;
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    // Validate customer name
    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer name')),
      );
      return;
    }

    // Validate stock availability
    final productProvider = context.read<ProductProvider>();
    final orderProvider = context.read<OrderProvider>();

    List<String> outOfStockItems = [];
    List<String> lowStockWarnings = [];

    for (var cartItem in orderProvider.cartItems) {
      final product = productProvider.getProductById(cartItem.productId);
      if (product == null) continue;

      // Check if sufficient stock available
      if (product.stock < cartItem.quantity) {
        outOfStockItems.add(
          '${cartItem.productName} (Available: ${product.stock}, Requested: ${cartItem.quantity})',
        );
      }
      // Check if order will bring stock below minimum
      else if (product.stock - cartItem.quantity < product.minStock) {
        lowStockWarnings.add(
          '${cartItem.productName} will be below minimum stock (Min: ${product.minStock})',
        );
      }
    }

    // Show error if any items are out of stock
    if (outOfStockItems.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Insufficient Stock'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The following items have insufficient stock:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...outOfStockItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Show warning if stock will be low after order
    if (lowStockWarnings.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('Low Stock Warning'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The following items will be below minimum stock:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...lowStockWarnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(warning)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Do you want to proceed anyway?',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    // Validate cash payment: ensure received cash >= total
    if (_selectedPaymentMethod == 'cash') {
      final total =
          orderProvider.cartItems.fold<double>(
            0.0,
            (sum, item) => sum + (item.unitPrice * item.quantity),
          ) -
          orderProvider.discount;
      final cashGiven =
          double.tryParse(_cashGivenController.text.trim()) ?? 0.0;
      if (cashGiven < total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash received is less than total amount'),
          ),
        );
        return;
      }
    }

    // Validate card payment: ensure reference number is provided
    if (_selectedPaymentMethod == 'card') {
      if (_cardReferenceController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter card reference number')),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final subtotal = orderProvider.cartItems.fold<double>(
        0.0,
        (sum, item) => sum + (item.unitPrice * item.quantity),
      );
      final total = subtotal - orderProvider.discount;

      // Get current user info
      final currentUser = await _getCurrentUser();

      // Prepare order data matching backend expectations
      final discountPercentage = subtotal > 0
          ? (orderProvider.discount / subtotal) * 100
          : 0.0;

      // Build cart items matching backend CartItem interface exactly
      final cartItems = orderProvider.cartItems.map((item) {
        final product = productProvider.getProductById(item.productId);
        return {
          'product': {
            '_id': item.productId,
            'shortId': product?.id ?? item.productId,
            'name': item.productName,
            'costPrice': product?.costPrice ?? 0,
            'sellingPrice': item.unitPrice,
            'discount': product?.discount ?? 0,
            'category': product?.category ?? '',
            'size': product?.size,
            'dryfood': product?.dryfood ?? false,
            'image': product?.image,
            'stock': product?.stock ?? 0,
            'description': product?.description,
            'barcode': product?.barcode,
            'supplier': product?.supplier,
          },
          'quantity': item.quantity,
          'subtotal': item.quantity * item.unitPrice,
          'note': '',
        };
      }).toList();

      // Build payment details matching backend PaymentDetails interface
      final paymentDetails = <String, dynamic>{
        'method': _selectedPaymentMethod,
      };

      if (_selectedPaymentMethod == 'cash') {
        final cashReceived =
            double.tryParse(_cashGivenController.text.trim()) ?? 0.0;
        paymentDetails['cashGiven'] = cashReceived;
        paymentDetails['change'] = cashReceived - total;
      } else if (_selectedPaymentMethod == 'card') {
        paymentDetails['invoiceId'] = _cardReferenceController.text.trim();
      }

      // Store cart items before clearing for receipt
      final cartItemsForReceipt = List.from(orderProvider.cartItems);
      final discountForReceipt = orderProvider.discount;

      // Build customer object matching backend Customer interface
      final customer = {'name': _customerNameController.text.trim()};

      // Build cashier object matching backend expected format
      final cashier = currentUser != null
          ? {
              '_id': currentUser['_id'] ?? currentUser['id'] ?? 'guest',
              'username': currentUser['username'] ?? 'Unknown',
            }
          : {'_id': 'guest', 'username': 'Guest'};

      // Build order data matching backend Order interface
      final orderData = {
        'name': _customerNameController.text.trim(),
        'cart': cartItems,
        'customer': customer,
        'cashier': cashier,
        'orderType': 'takeaway',
        'status': 'completed',
        'paymentDetails': paymentDetails,
        'tableCharge': 0,
        'deliveryCharge': 0,
        'discountPercentage': discountPercentage,
        'totalAmount': total,
      };

      // Call backend API to create order
      final result = await ApiService.createOrder(orderData);

      if (mounted) {
        if (result['success'] == true) {
          // After successful order creation, update stock in backend
          final stockUpdateItems = orderProvider.cartItems.map((item) {
            final product = productProvider.getProductById(item.productId);
            return {
              'product': {
                '_id': item.productId,
                'name': item.productName,
                'sellingPrice': item.unitPrice,
                'stock': product?.stock ?? 0,
              },
              'quantity': item.quantity,
            };
          }).toList();

          // Update stock in backend
          await ApiService.updateStock(stockUpdateItems);

          // Refresh products to get updated stock from backend
          await productProvider.refreshProducts();

          setState(() => _isProcessing = false);

          // Navigate to receipt screen
          final cashGiven = _selectedPaymentMethod == 'cash'
              ? double.tryParse(_cashGivenController.text.trim()) ?? 0.0
              : null;
          final change = cashGiven != null ? cashGiven - total : null;

          // Clear the cart
          orderProvider.clearCart();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ReceiptScreen(
                orderId:
                    result['data']?['_id'] ??
                    result['data']?['order']?['_id'] ??
                    'N/A',
                items: cartItemsForReceipt,
                subtotal: subtotal,
                discount: discountForReceipt,
                total: total,
                paymentMethod: _selectedPaymentMethod,
                cashReceived: cashGiven,
                change: change,
              ),
            ),
          );
        } else {
          setState(() => _isProcessing = false);
          // Show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to create order'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Consumer<OrderProvider>(
          builder: (context, orderProvider, _) {
            final subtotal = orderProvider.cartItems.fold<double>(
              0.0,
              (sum, item) => sum + (item.unitPrice * item.quantity),
            );
            final total = subtotal - orderProvider.discount;
            final itemCount = orderProvider.cartItems.fold<int>(
              0,
              (sum, item) => sum + item.quantity,
            );

            return Column(
              children: [
                // Animated Header
                FadeTransition(
                  opacity: _headerAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.3),
                      end: Offset.zero,
                    ).animate(_headerAnimation),
                    child: _buildHeader(itemCount),
                  ),
                ),

                // Content
                Expanded(
                  child: FadeTransition(
                    opacity: _contentAnimation,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Info Section
                          _buildSectionTitle(
                            icon: Icons.person_rounded,
                            title: 'Customer Information',
                            iconColor: Colors.blue,
                          ),
                          const SizedBox(height: 12),
                          _buildCustomerNameField(),
                          const SizedBox(height: 24),

                          // Order Summary Section
                          _buildSectionTitle(
                            icon: Icons.receipt_long_rounded,
                            title: 'Order Summary',
                            iconColor: const Color(0xFF324137),
                          ),
                          const SizedBox(height: 12),
                          _buildOrderSummaryCard(orderProvider, subtotal),
                          const SizedBox(height: 24),

                          // Discount Section
                          _buildSectionTitle(
                            icon: Icons.local_offer_rounded,
                            title: 'Discount',
                            iconColor: Colors.purple,
                          ),
                          const SizedBox(height: 12),
                          _buildDiscountField(subtotal),
                          const SizedBox(height: 24),

                          // Payment Method Section
                          _buildSectionTitle(
                            icon: Icons.payment_rounded,
                            title: 'Payment Method',
                            iconColor: Colors.green,
                          ),
                          const SizedBox(height: 12),
                          _buildPaymentMethodSection(),
                          const SizedBox(height: 24),

                          // Payment Details Section
                          if (_selectedPaymentMethod == 'cash')
                            _buildCashPaymentDetails(total),
                          if (_selectedPaymentMethod == 'card')
                            _buildCardPaymentDetails(),

                          // Total Section
                          _buildTotalSection(total),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),

                // Payment Button
                FadeTransition(
                  opacity: _contentAnimation,
                  child: _buildPaymentButton(total),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(int itemCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF324137), Color(0xFF4a5d4f)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF324137).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _AnimatedIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Checkout',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete your purchase',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFC8E260),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shopping_bag_rounded,
                  size: 16,
                  color: Color(0xFF324137),
                ),
                const SizedBox(width: 6),
                Text(
                  '$itemCount items',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324137),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF324137),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomerNameField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isCustomerNameFocused
            ? [
                BoxShadow(
                  color: const Color(0xFFC8E260).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: _customerNameController,
        focusNode: _customerNameFocusNode,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF324137),
        ),
        decoration: InputDecoration(
          hintText: 'Enter customer name',
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isCustomerNameFocused
                  ? const Color(0xFFC8E260).withOpacity(0.2)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.person_rounded,
              color: _isCustomerNameFocused
                  ? const Color(0xFF324137)
                  : Colors.grey.shade500,
              size: 20,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFC8E260), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard(OrderProvider orderProvider, double subtotal) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Items list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orderProvider.cartItems.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Colors.grey.shade100,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final item = orderProvider.cartItems[index];
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8E260).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'x${item.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324137),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF324137),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rs.${item.unitPrice.toStringAsFixed(2)} each',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Rs.${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF324137),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Summary totals
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Rs.${subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF324137),
                      ),
                    ),
                  ],
                ),
                if (orderProvider.discount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_offer_rounded,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Discount',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '- Rs.${orderProvider.discount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountField(double subtotal) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.percent_rounded,
                  color: Colors.purple.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Custom Discount Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF324137),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: _isDiscountFocused
                  ? [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: TextField(
              controller: _discountController,
              focusNode: _discountFocusNode,
              keyboardType: TextInputType.number,
              onChanged: (_) => _applyDiscount(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF324137),
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w400,
                ),
                prefixText: 'Rs. ',
                prefixStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.purple.shade400,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter the discount amount to apply to this order',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Row(
      children: [
        Expanded(
          child: _PaymentMethodCard(
            icon: Icons.payments_rounded,
            label: 'Cash',
            isSelected: _selectedPaymentMethod == 'cash',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedPaymentMethod = 'cash');
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PaymentMethodCard(
            icon: Icons.credit_card_rounded,
            label: 'Card',
            isSelected: _selectedPaymentMethod == 'card',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedPaymentMethod = 'card');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCashPaymentDetails(double total) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.attach_money_rounded,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Cash Received',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF324137),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isCashFocused
                      ? [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: TextField(
                  controller: _cashGivenController,
                  focusNode: _cashFocusNode,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324137),
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixText: 'Rs. ',
                    prefixStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.green.shade400,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Change calculation
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _cashGivenController,
                builder: (context, value, _) {
                  final cashGiven = double.tryParse(value.text.trim()) ?? 0.0;
                  final change = cashGiven - total;
                  final insufficient = change < 0;

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, animValue, child) {
                      return Transform.scale(
                        scale: 0.95 + (0.05 * animValue),
                        child: Opacity(opacity: animValue, child: child),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: insufficient
                              ? [Colors.red.shade50, Colors.red.shade100]
                              : [Colors.green.shade50, Colors.green.shade100],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: insufficient
                              ? Colors.red.shade200
                              : Colors.green.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                insufficient
                                    ? Icons.warning_amber_rounded
                                    : Icons.check_circle_rounded,
                                color: insufficient
                                    ? Colors.red.shade600
                                    : Colors.green.shade600,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                insufficient ? 'Insufficient' : 'Change',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: insufficient
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            insufficient
                                ? 'Rs.${(total - cashGiven).toStringAsFixed(2)} more'
                                : 'Rs.${change.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: insufficient
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCardPaymentDetails() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.credit_card_rounded,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Card Reference Number',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF324137),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isCardFocused
                      ? [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: TextField(
                  controller: _cardReferenceController,
                  focusNode: _cardFocusNode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF324137),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter reference number',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.blue.shade400,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(18),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTotalSection(double total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF324137), Color(0xFF4a5d4f)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF324137).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total to Pay',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    _selectedPaymentMethod == 'cash'
                        ? Icons.payments_rounded
                        : Icons.credit_card_rounded,
                    color: const Color(0xFFC8E260),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedPaymentMethod == 'cash' ? 'Cash' : 'Card',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFC8E260),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFC8E260),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Rs.${total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF324137),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton(double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: _AnimatedButton(
        onTap: _isProcessing ? () {} : _processPayment,
        isProcessing: _isProcessing,
        gradient: LinearGradient(
          colors: _isProcessing
              ? [Colors.grey.shade400, Colors.grey.shade500]
              : [const Color(0xFF35AE4A), const Color(0xFF2D9940)],
        ),
        child: _isProcessing
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Processing...',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedPaymentMethod == 'cash'
                        ? Icons.payments_rounded
                        : Icons.credit_card_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _selectedPaymentMethod == 'cash'
                        ? 'Complete Cash Payment'
                        : 'Complete Card Payment',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Helper Widgets

class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AnimatedIconButton({required this.icon, required this.onTap});

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PaymentMethodCard> createState() => _PaymentMethodCardState();
}

class _PaymentMethodCardState extends State<_PaymentMethodCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF324137), Color(0xFF4a5d4f)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFF324137)
                  : Colors.grey.shade300,
              width: widget.isSelected ? 2 : 1.5,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF324137).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  size: 28,
                  color: widget.isSelected
                      ? Colors.white
                      : const Color(0xFF324137),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected
                      ? Colors.white
                      : const Color(0xFF324137),
                ),
              ),
              const SizedBox(height: 6),
              if (widget.isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E260),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Selected',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF324137),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final Gradient gradient;
  final bool isProcessing;

  const _AnimatedButton({
    required this.onTap,
    required this.child,
    required this.gradient,
    this.isProcessing = false,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isProcessing
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.isProcessing
          ? null
          : (_) {
              setState(() => _isPressed = false);
              HapticFeedback.mediumImpact();
              widget.onTap();
            },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: widget.isProcessing
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF35AE4A).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
