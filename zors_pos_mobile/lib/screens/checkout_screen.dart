import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../services/api_service.dart';
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

  @override
  void dispose() {
    _notesController.dispose();
    _cashGivenController.dispose();
    _cardReferenceController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
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
      final orderProvider = context.read<OrderProvider>();
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
      final orderProvider = context.read<OrderProvider>();
      final subtotal = orderProvider.cartItems.fold<double>(
        0.0,
        (sum, item) => sum + (item.unitPrice * item.quantity),
      );
      final total = subtotal - orderProvider.discount;

      // Prepare order data for backend
      final discountPercentage = subtotal > 0
          ? (orderProvider.discount / subtotal) * 100
          : 0.0;

      final orderData = {
        'cart': orderProvider.cartItems
            .map(
              (item) => {
                'productId': item.productId,
                'productName': item.productName,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                if (_selectedPaymentMethod == 'card')
                  'cardReferenceNumber': _cardReferenceController.text.trim(),
              },
            )
            .toList(),
        'orderType': 'takeaway',
        'totalAmount': total,
        'discountPercentage': discountPercentage,
        'paymentDetails': {
          'method': _selectedPaymentMethod,
          'notes': _notesController.text,
          if (_selectedPaymentMethod == 'cash')
            'cashReceived':
                double.tryParse(_cashGivenController.text.trim()) ?? 0.0,
        },
      };

      // Call backend API to create order
      final result = await ApiService.createOrder(orderData);

      if (mounted) {
        setState(() => _isProcessing = false);

        if (result['success'] == true) {
          // Update stock after successful order
          final stockDeductions = <String, int>{};
          for (var item in orderProvider.cartItems) {
            stockDeductions[item.productId] = item.quantity;
          }
          context.read<ProductProvider>().applyStockDeduction(stockDeductions);

          // Navigate to receipt screen
          final cashGiven = _selectedPaymentMethod == 'cash'
              ? double.tryParse(_cashGivenController.text.trim()) ?? 0.0
              : null;
          final change = cashGiven != null ? cashGiven - total : null;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ReceiptScreen(
                orderId: result['data']?['order']?['_id'] ?? 'N/A',
                items: orderProvider.cartItems,
                subtotal: subtotal,
                discount: orderProvider.discount,
                total: total,
                paymentMethod: _selectedPaymentMethod,
                cashReceived: cashGiven,
                change: change,
              ),
            ),
          );
        } else {
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
                        // Order Summary Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[200]!,
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                              ),
                            ],
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
                              const Divider(height: 16),
                              ...orderProvider.cartItems.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
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
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              'x${item.quantity}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'Rs. ${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal:'),
                                  Text(
                                    'Rs. ${subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Discount:'),
                                  Text(
                                    '- Rs. ${orderProvider.discount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF35AE4A),
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
                                    'Total:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${(subtotal - orderProvider.discount).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF324137),
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
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey[200]!,
                                width: 0.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cash Received',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF324137),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _cashGivenController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Enter amount received (e.g., 5000)',
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
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (context) {
                                    final orderProvider = context
                                        .read<OrderProvider>();
                                    final subtotal = orderProvider.cartItems
                                        .fold<double>(
                                          0.0,
                                          (sum, item) =>
                                              sum +
                                              (item.unitPrice * item.quantity),
                                        );
                                    final discount = orderProvider.discount;
                                    final total = subtotal - discount;
                                    final cashGiven =
                                        double.tryParse(
                                          _cashGivenController.text.trim(),
                                        ) ??
                                        0.0;
                                    final change = cashGiven - total;
                                    final insufficient =
                                        cashGiven > 0 && cashGiven < total;
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: insufficient
                                            ? const Color(0xFFFFF5F5)
                                            : const Color(0xFFF4FFF0),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: insufficient
                                              ? Colors.redAccent
                                              : const Color(0xFFC8E260),
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            insufficient
                                                ? 'Insufficient Cash'
                                                : 'Change to Return',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: insufficient
                                                  ? Colors.redAccent
                                                  : const Color(0xFF324137),
                                            ),
                                          ),
                                          Text(
                                            insufficient
                                                ? 'Rs. ${(total - cashGiven).toStringAsFixed(2)} needed'
                                                : 'Rs. ${change >= 0 ? change.toStringAsFixed(2) : '0.00'}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: insufficient
                                                  ? Colors.redAccent
                                                  : const Color(0xFF324137),
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
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey[200]!,
                                width: 0.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Card Reference Number',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF324137),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Enter the transaction reference or authorization code',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _cardReferenceController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: 'e.g., TXN123456789',
                                    prefixIcon: const Icon(Icons.credit_card),
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
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F8FF),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF324137),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        color: Color(0xFF324137),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          (_cardReferenceController.text ?? '')
                                                  .isNotEmpty
                                              ? 'Reference: ${_cardReferenceController.text}'
                                              : 'Reference number is required',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ],
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
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF324137),
                                ),
                              ),
                              Text(
                                'Rs. ${(subtotal - orderProvider.discount).toStringAsFixed(2)}',
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
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text('Processing Payment...'),
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
}
