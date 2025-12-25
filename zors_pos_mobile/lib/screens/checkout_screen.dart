import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../services/api_service.dart';
import '../models/discount.dart';
import 'receipt_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPaymentMethod = 'cash';
  bool _isProcessing = false;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _cashGivenController = TextEditingController();
  final TextEditingController _cardReferenceController =
      TextEditingController();
  final TextEditingController _customerNameController = TextEditingController(
    text: "CUSTOMER",
  );

  List<Discount> _availableDiscounts = [];
  Discount? _selectedDiscount;
  Discount? _globalDiscount;
  bool _isLoadingDiscounts = true;

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
  }

  Future<void> _loadDiscounts() async {
    try {
      final result = await ApiService.getDiscounts();
      if (result['success'] == true && result['data'] != null) {
        final discounts = (result['data'] as List)
            .map((json) => Discount.fromJson(json))
            .toList();

        setState(() {
          _availableDiscounts = discounts;
          // Find global discount
          try {
            _globalDiscount = discounts.firstWhere((d) => d.isGlobal);
          } catch (e) {
            _globalDiscount = null;
          }
          // Auto-apply global discount if it exists
          if (_globalDiscount != null) {
            _selectedDiscount = _globalDiscount;
            _applyDiscount();
          }
          _isLoadingDiscounts = false;
        });
      } else {
        setState(() => _isLoadingDiscounts = false);
      }
    } catch (e) {
      print('Error loading discounts: $e');
      setState(() => _isLoadingDiscounts = false);
    }
  }

  void _applyDiscount() {
    if (_selectedDiscount == null) {
      context.read<OrderProvider>().setDiscount(0.0);
      return;
    }

    final orderProvider = context.read<OrderProvider>();
    final subtotal = orderProvider.cartItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.unitPrice * item.quantity),
    );

    double discountAmount = 0.0;
    if (_selectedDiscount!.discountType == 'percentage') {
      discountAmount = subtotal * (_selectedDiscount!.discountValue / 100);
    } else {
      discountAmount = _selectedDiscount!.discountValue;
    }

    orderProvider.setDiscount(discountAmount);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _cashGivenController.dispose();
    _cardReferenceController.dispose();
    _customerNameController.dispose();
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
      // Backend expects: { product: { _id, shortId, name, costPrice, sellingPrice, discount, category, size, dryfood, image, stock, description, barcode, supplier }, quantity, subtotal, note }
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
        'kitchenNote': _notesController.text.isNotEmpty
            ? _notesController.text
            : null,
        'status': 'completed',
        'paymentDetails': paymentDetails,
        'tableCharge': 0,
        'deliveryCharge': 0,
        'discountPercentage': discountPercentage,
        'totalAmount': total,
        // Add appliedCoupon if a discount is selected (matching backend Coupon interface)
        if (_selectedDiscount != null)
          'appliedCoupon': {
            'code': _selectedDiscount!.codeOrName,
            'discount': _selectedDiscount!.discountValue,
            'type': _selectedDiscount!.discountType,
            'description':
                '${_selectedDiscount!.codeOrName} - ${_selectedDiscount!.discountValue}${_selectedDiscount!.discountType == 'percentage' ? '%' : ' Rs.'} off',
          },
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
      backgroundColor: const Color(0xFFF0F0F0),
      body: SafeArea(
        child: Consumer<OrderProvider>(
          builder: (context, orderProvider, _) {
            final subtotal = orderProvider.cartItems.fold<double>(
              0.0,
              (sum, item) => sum + (item.unitPrice * item.quantity),
            );
            final total = subtotal - orderProvider.discount;

            return Column(
              children: [
                // Header
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
                      const Expanded(
                        child: Text(
                          'Checkout',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC8E260),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${orderProvider.cartItems.length} items',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Name Section
                        const Text(
                          'Customer Name *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324137),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customerNameController,
                          decoration: InputDecoration(
                            hintText: 'Enter customer name',
                            prefixIcon: const Icon(Icons.person_outline),
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
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Discount Section
                        const Text(
                          'Apply Discount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324137),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingDiscounts)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_availableDiscounts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1.6,
                              ),
                            ),
                            child: const Text(
                              'No discounts available',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        else
                          Column(
                            children: [
                              // No discount option
                              _buildDiscountOption(
                                null,
                                'No Discount',
                                'Proceed without discount',
                              ),
                              const SizedBox(height: 10),
                              // Global discount (if exists)
                              if (_globalDiscount != null) ...[
                                _buildDiscountOption(
                                  _globalDiscount,
                                  '${_globalDiscount!.codeOrName} (Global)',
                                  '${_globalDiscount!.discountValue}% off',
                                ),
                                const SizedBox(height: 10),
                              ],
                              // Other discounts
                              ..._availableDiscounts
                                  .where((d) => !d.isGlobal)
                                  .map(
                                    (discount) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _buildDiscountOption(
                                        discount,
                                        discount.codeOrName,
                                        '${discount.discountValue}${discount.discountType == 'percentage' ? '%' : ' Rs.'} off',
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        const SizedBox(height: 20),

                        // Order Summary Section
                        Container(
                          padding: const EdgeInsets.all(16),
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
                              const Text(
                                'Order Summary',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324137),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...orderProvider.cartItems.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.productName} x${item.quantity}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      Text(
                                        'Rs. ${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal'),
                                  Text(
                                    'Rs. ${subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (orderProvider.discount > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Discount',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                    Text(
                                      '- Rs. ${orderProvider.discount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF35AE4A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Payment Method Section
                        const Text(
                          'Payment Method',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324137),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPaymentMethodOption('cash', 'Cash Payment'),
                        const SizedBox(height: 10),
                        _buildPaymentMethodOption('card', 'Debit/Credit Card'),
                        const SizedBox(height: 20),

                        // Cash Payment Details
                        if (_selectedPaymentMethod == 'cash') ...[
                          Container(
                            padding: const EdgeInsets.all(16),
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
                                const Text(
                                  'Cash Received',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF324137),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _cashGivenController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Enter amount received',
                                    prefixText: 'Rs. ',
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _cashGivenController,
                                  builder: (context, value, _) {
                                    final cashGiven =
                                        double.tryParse(value.text.trim()) ??
                                        0.0;
                                    final change = cashGiven - total;
                                    final insufficient = change < 0;
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: insufficient
                                            ? Colors.red[50]
                                            : Colors.green[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            insufficient
                                                ? 'Insufficient'
                                                : 'Change:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: insufficient
                                                  ? Colors.red
                                                  : const Color(0xFF324137),
                                            ),
                                          ),
                                          Text(
                                            insufficient
                                                ? 'Rs. ${(total - cashGiven).toStringAsFixed(2)} more needed'
                                                : 'Rs. ${change.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: insufficient
                                                  ? Colors.red
                                                  : const Color(0xFF35AE4A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Card Payment Details
                        if (_selectedPaymentMethod == 'card') ...[
                          Container(
                            padding: const EdgeInsets.all(16),
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
                                const Text(
                                  'Card Reference Number',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF324137),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _cardReferenceController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter reference number',
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Notes Section
                        const Text(
                          'Order Notes (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF324137),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Add special instructions...',
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
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Total Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4FFF0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFC8E260),
                              width: 1.6,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total to Pay',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324137),
                                ),
                              ),
                              Text(
                                'Rs. ${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF35AE4A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Payment Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isProcessing
                            ? Colors.grey
                            : const Color(0xFF35AE4A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isProcessing
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Processing...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _selectedPaymentMethod == 'cash'
                                  ? 'Complete Cash Payment'
                                  : 'Complete Card Payment',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
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

  Widget _buildPaymentMethodOption(String value, String label) {
    final isSelected = _selectedPaymentMethod == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFFC8E260) : Colors.grey[300]!,
            width: isSelected ? 2 : 1.6,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFC8E260).withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFC8E260)
                      : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected
                    ? const Color(0xFFC8E260)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: const Color(0xFF324137),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountOption(
    Discount? discount,
    String title,
    String subtitle,
  ) {
    final isSelected = _selectedDiscount?.id == discount?.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDiscount = discount;
        });
        _applyDiscount();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFFC8E260) : Colors.grey[300]!,
            width: isSelected ? 2 : 1.6,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFC8E260).withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFC8E260)
                      : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected
                    ? const Color(0xFFC8E260)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: const Color(0xFF324137),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (discount?.isGlobal == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC8E260).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'AUTO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324137),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
