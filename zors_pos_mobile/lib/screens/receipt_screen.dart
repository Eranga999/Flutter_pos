import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:math' as math;

class ReceiptScreen extends StatefulWidget {
  final String orderId;
  final List<dynamic> items;
  final double subtotal;
  final double discount;
  final double total;
  final String paymentMethod;
  final double? cashReceived;
  final double? change;

  const ReceiptScreen({
    super.key,
    required this.orderId,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    this.cashReceived,
    this.change,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _headerController;
  late AnimationController _successController;
  late AnimationController _contentController;
  late AnimationController _confettiController;

  late Animation<double> _headerAnimation;
  late Animation<double> _successScaleAnimation;
  late Animation<double> _successBounceAnimation;
  late Animation<double> _contentAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    // Haptic feedback for success
    HapticFeedback.heavyImpact();
  }

  void _initAnimations() {
    // Header slide animation
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );

    // Success icon animation with bounce
    _successController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _successScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _successBounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Content fade animation
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _contentAnimation = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );

    // Confetti animation
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Start animations in sequence
    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _successController.forward();
      _confettiController.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      _contentController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _successController.dispose();
    _contentController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handleDone() {
    HapticFeedback.mediumImpact();
    context.read<OrderProvider>().clearCart();
    Navigator.of(context).pop();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final timeStr = DateFormat('HH:mm:ss').format(now);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Animated Header
                FadeTransition(
                  opacity: _headerAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -1),
                      end: Offset.zero,
                    ).animate(_headerAnimation),
                    child: _buildHeader(),
                  ),
                ),

                // Receipt Content
                Expanded(
                  child: FadeTransition(
                    opacity: _contentAnimation,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Success Animation
                          _buildSuccessSection(),
                          const SizedBox(height: 24),

                          // Receipt Card
                          _buildReceiptCard(dateStr, timeStr),
                        ],
                      ),
                    ),
                  ),
                ),

                // Action Buttons
                FadeTransition(
                  opacity: _contentAnimation,
                  child: _buildActionButtons(),
                ),
              ],
            ),

            // Confetti overlay - IgnorePointer so it doesn't block touch events
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      progress: _confettiController.value,
                    ),
                    size: MediaQuery.of(context).size,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Receipt',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Transaction Complete',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _AnimatedIconButton(icon: Icons.close_rounded, onTap: _handleDone),
        ],
      ),
    );
  }

  Widget _buildSuccessSection() {
    return AnimatedBuilder(
      animation: _successController,
      builder: (context, child) {
        return Transform.scale(
          scale: _successScaleAnimation.value,
          child: Column(
            children: [
              // Pulsing success circle
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF35AE4A).withOpacity(0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF35AE4A,
                      ).withOpacity(0.2 * _successBounceAnimation.value),
                      blurRadius: 30 * _successBounceAnimation.value,
                      spreadRadius: 10 * _successBounceAnimation.value,
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF35AE4A), Color(0xFF2D9A40)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF324137),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Thank you for your purchase',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReceiptCard(String dateStr, String timeStr) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Logo/Name
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF324137), Color(0xFF4a5d4f)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ZORS POS SYSTEM',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Color(0xFF324137),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildAnimatedDashedLine(),
          const SizedBox(height: 20),

          // Transaction Info Section
          _buildSectionTitle('Transaction Details', Icons.info_outline_rounded),
          const SizedBox(height: 12),
          _buildInfoRow('Date', dateStr, Icons.calendar_today_rounded),
          _buildInfoRow('Time', timeStr, Icons.access_time_rounded),
          _buildInfoRow(
            'Order ID',
            widget.orderId.length > 16
                ? '...${widget.orderId.substring(widget.orderId.length - 16)}'
                : widget.orderId,
            Icons.tag_rounded,
          ),
          _buildInfoRow(
            'Payment',
            widget.paymentMethod.toUpperCase(),
            widget.paymentMethod.toLowerCase() == 'cash'
                ? Icons.payments_rounded
                : Icons.credit_card_rounded,
          ),

          const SizedBox(height: 20),
          _buildAnimatedDashedLine(),
          const SizedBox(height: 20),

          // Items Section
          _buildSectionTitle('Items Purchased', Icons.shopping_bag_rounded),
          const SizedBox(height: 12),
          ...widget.items.asMap().entries.map(
            (entry) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + (entry.key * 100)),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(20 * (1 - value), 0),
                    child: _buildItemRow(
                      entry.value.productName,
                      entry.value.quantity,
                      entry.value.unitPrice,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),
          _buildAnimatedDashedLine(),
          const SizedBox(height: 20),

          // Totals Section
          _buildTotalRow('Subtotal', widget.subtotal, false),
          if (widget.discount > 0) ...[
            const SizedBox(height: 10),
            _buildTotalRow(
              'Discount',
              -widget.discount,
              false,
              isDiscount: true,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF324137).withOpacity(0.08),
                  const Color(0xFFC8E260).withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324137),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Rs. ${widget.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324137),
                  ),
                ),
              ],
            ),
          ),

          // Cash payment details
          if (widget.paymentMethod.toLowerCase() == 'cash' &&
              widget.cashReceived != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF35AE4A).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF35AE4A).withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cash Received',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Rs. ${widget.cashReceived!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF324137),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF35AE4A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.currency_exchange_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Change Due',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Rs. ${(widget.change ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          _buildAnimatedDashedLine(),
          const SizedBox(height: 20),

          // Footer
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 14,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Powered by Kodernet',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'www.kodernet.com',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF324137).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF324137)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF324137),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Print Button
          _ActionButton(
            label: 'Print Receipt',
            icon: Icons.print_rounded,
            isPrimary: true,
            onTap: () => _printReceipt(context),
          ),
          const SizedBox(height: 12),
          // Done Button
          _AnimatedDoneButton(onTap: _handleDone),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF324137),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(String name, int quantity, double price) {
    final itemTotal = quantity * price;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFC8E260).withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${quantity}x',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF324137),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF324137),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rs. ${price.toStringAsFixed(2)} each',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Text(
            'Rs. ${itemTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF324137),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount,
    bool isBold, {
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 17 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isDiscount
                  ? const Color(0xFF35AE4A)
                  : Colors.grey.shade700,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}Rs. ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isBold ? 17 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isDiscount
                  ? const Color(0xFF35AE4A)
                  : const Color(0xFF324137),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDashedLine() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: child,
          ),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 6.0;
          const dashSpace = 4.0;
          final dashCount = (constraints.maxWidth / (dashWidth + dashSpace))
              .floor();
          return Row(
            children: List.generate(dashCount, (index) {
              return Container(
                width: dashWidth,
                height: 1.5,
                margin: const EdgeInsets.only(right: dashSpace),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  void _printReceipt(BuildContext context) async {
    HapticFeedback.mediumImpact();
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy').format(now);
      final timeStr = DateFormat('HH:mm:ss').format(now);

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 10),
                pw.Text(
                  ' KODERNET POS SYSTEM',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Thank you for your purchase!',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(dateStr, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Time:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(timeStr, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Order ID:',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      widget.orderId.length > 15
                          ? '...${widget.orderId.substring(widget.orderId.length - 15)}'
                          : widget.orderId,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Payment:',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      widget.paymentMethod.toUpperCase(),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Divider(),
                pw.SizedBox(height: 5),
                pw.Text(
                  'ITEMS',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                ...widget.items.map((item) {
                  final itemTotal = item.quantity * item.unitPrice;
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.productName,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${item.quantity}x Rs.${item.unitPrice.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(
                            'Rs.${itemTotal.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                    ],
                  );
                }),
                pw.SizedBox(height: 5),
                pw.Divider(),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Subtotal:',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Rs.${widget.subtotal.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                if (widget.discount > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Discount:',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        '- Rs.${widget.discount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                pw.SizedBox(height: 3),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Rs.${widget.total.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (widget.paymentMethod.toLowerCase() == 'cash' &&
                    widget.cashReceived != null) ...[
                  pw.SizedBox(height: 5),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Cash Received:',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'Rs.${widget.cashReceived!.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Change:',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'Rs.${(widget.change ?? 0).toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'Powered by ZORS POS',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'www.zorscode.com',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
            );
          },
        ),
      );

      // Print the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Receipt sent to printer!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF35AE4A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Print error: $e')),
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
    }
  }
}

// Animated icon button for header
class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AnimatedIconButton({required this.icon, required this.onTap});

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// Action button with press animation
class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: widget.isPrimary
                ? const LinearGradient(
                    colors: [Color(0xFF324137), Color(0xFF4a5d4f)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isPrimary ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: widget.isPrimary
                ? null
                : Border.all(color: const Color(0xFF324137), width: 2),
            boxShadow: widget.isPrimary
                ? [
                    BoxShadow(
                      color: const Color(0xFF324137).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: widget.isPrimary
                    ? Colors.white
                    : const Color(0xFF324137),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.isPrimary
                      ? Colors.white
                      : const Color(0xFF324137),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Animated done button with gradient
class _AnimatedDoneButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AnimatedDoneButton({required this.onTap});

  @override
  State<_AnimatedDoneButton> createState() => _AnimatedDoneButtonState();
}

class _AnimatedDoneButtonState extends State<_AnimatedDoneButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF35AE4A), Color(0xFF2D9A40)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF35AE4A).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'Done - New Sale',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Confetti painter for celebration effect
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> _particles;

  _ConfettiPainter({required this.progress})
    : _particles = List.generate(30, (index) => _ConfettiParticle(index));

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress >= 1) return;

    for (var particle in _particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity((1 - progress) * 0.8)
        ..style = PaintingStyle.fill;

      final x =
          particle.startX * size.width + particle.velocityX * progress * 100;
      final y =
          particle.startY * size.height * 0.3 +
          progress * size.height * 0.6 +
          math.sin(progress * math.pi * 2 + particle.phase) * 20;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * particle.rotation);

      if (particle.isCircle) {
        canvas.drawCircle(Offset.zero, particle.size, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size * 2,
            height: particle.size,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ConfettiParticle {
  final double startX;
  final double startY;
  final double velocityX;
  final double size;
  final double rotation;
  final double phase;
  final Color color;
  final bool isCircle;

  _ConfettiParticle(int index)
    : startX = math.Random(index).nextDouble(),
      startY = math.Random(index * 2).nextDouble(),
      velocityX = (math.Random(index * 3).nextDouble() - 0.5) * 2,
      size = math.Random(index * 4).nextDouble() * 4 + 2,
      rotation = math.Random(index * 5).nextDouble() * math.pi * 4,
      phase = math.Random(index * 6).nextDouble() * math.pi * 2,
      color = [
        const Color(0xFF35AE4A),
        const Color(0xFFC8E260),
        const Color(0xFF324137),
        const Color(0xFF667eea),
        const Color(0xFFf5576c),
      ][index % 5],
      isCircle = index % 2 == 0;
}
