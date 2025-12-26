import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/reports_provider.dart';
import '../utils/export_helper.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _headerController;
  late AnimationController _contentController;
  late Animation<double> _headerAnimation;
  late Animation<double> _contentAnimation;

  // State
  bool _isExporting = false;
  int _selectedChartType = 0; // 0 = line, 1 = bar

  @override
  void initState() {
    super.initState();
    _initAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().fetchReports(null);
    });
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
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();

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
                child: _buildModernHeader(provider),
              ),
            ),
            // Body
            Expanded(
              child: provider.loading
                  ? _buildLoadingState()
                  : FadeTransition(
                      opacity: _contentAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(_contentAnimation),
                        child: RefreshIndicator(
                          onRefresh: () async {
                            HapticFeedback.mediumImpact();
                            await context.read<ReportsProvider>().fetchReports(
                              provider.dateFilter,
                            );
                          },
                          color: const Color(0xFF324137),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date Filter Pills
                                _buildDateFilterPills(provider),
                                const SizedBox(height: 20),

                                // Business performance cards
                                _buildPerformanceCards(provider),
                                const SizedBox(height: 20),

                                // Sales Performance Chart
                                _buildSalesPerformanceChart(provider),
                                const SizedBox(height: 20),

                                // Top Selling Products
                                _buildTopProductsSection(provider),
                                const SizedBox(height: 20),

                                // Summary Stats
                                _buildSummaryStatsSection(provider),
                                const SizedBox(height: 20),

                                // Business Insights
                                _buildBusinessInsightsSection(provider),

                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(ReportsProvider provider) {
    return Container(
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
                    'Business Reports',
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
              // GestureDetector(
              //   onTap: _isExporting ? null : () => _exportCsv(provider),
              //   child: AnimatedContainer(
              //     duration: const Duration(milliseconds: 200),
              //     padding: const EdgeInsets.all(10),
              //     decoration: BoxDecoration(
              //       color: _isExporting
              //           ? Colors.white.withOpacity(0.05)
              //           : Colors.white.withOpacity(0.12),
              //       borderRadius: BorderRadius.circular(12),
              //     ),
              //     child: _isExporting
              //         ? const SizedBox(
              //             width: 22,
              //             height: 22,
              //             child: CircularProgressIndicator(
              //               color: Colors.white,
              //               strokeWidth: 2,
              //             ),
              //           )
              //         : const Icon(
              //             Icons.download_rounded,
              //             color: Colors.white,
              //             size: 22,
              //           ),
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFFC8E260),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Comprehensive insights into your business performance',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    color: Color(0xFF324137),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading Reports...',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterPills(ReportsProvider provider) {
    final filters = [
      {'value': '7', 'label': '7 Days'},
      {'value': '30', 'label': '30 Days'},
      {'value': '90', 'label': '90 Days'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = provider.dateFilter == filter['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.read<ReportsProvider>().fetchReports(filter['value']);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF324137) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF324137)
                        : Colors.grey.shade300,
                  ),
                  boxShadow: isSelected
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
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      filter['label']!,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPerformanceCards(ReportsProvider provider) {
    final stats = provider.summaryStats;
    final activeProducts = stats['activeProducts'] ?? 0;
    final totalCustomers = stats['totalCustomers'] ?? 0;

    final cards = [
      _PerformanceCardData(
        title: 'Total Revenue',
        value: 'Rs.${provider.totalRevenue.toStringAsFixed(2)}',
        subtitle: 'Today: Rs.${provider.todayRevenue.toStringAsFixed(2)}',
        icon: Icons.trending_up_rounded,
        gradient: [const Color(0xFF35AE4A), const Color(0xFF2E7D32)],
      ),
      _PerformanceCardData(
        title: 'Total Orders',
        value: provider.totalOrders.toString(),
        subtitle: 'Avg: Rs.${provider.avgOrderValue.toStringAsFixed(2)}',
        icon: Icons.receipt_long_rounded,
        gradient: [const Color(0xFF667eea), const Color(0xFF764ba2)],
      ),
      _PerformanceCardData(
        title: 'Products',
        value: activeProducts.toString(),
        subtitle: 'Active in store',
        icon: Icons.inventory_2_rounded,
        gradient: [const Color(0xFF11998e), const Color(0xFF38ef7d)],
      ),
      _PerformanceCardData(
        title: 'Customers',
        value: totalCustomers.toString(),
        subtitle: 'Total registered',
        icon: Icons.people_rounded,
        gradient: [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
      ),
      _PerformanceCardData(
        title: 'Net Profit',
        value: 'Rs.${provider.totalProfit.toStringAsFixed(2)}',
        subtitle: 'Margin: ${provider.profitMargin.toStringAsFixed(1)}%',
        icon: Icons.account_balance_wallet_rounded,
        gradient: [const Color(0xFFf093fb), const Color(0xFFf5576c)],
      ),
    ];

    return Column(
      children: [
        // First row - 2 cards
        Row(
          children: [
            Expanded(child: _buildAnimatedCard(cards[0], 0)),
            const SizedBox(width: 12),
            Expanded(child: _buildAnimatedCard(cards[1], 1)),
          ],
        ),
        const SizedBox(height: 12),
        // Second row - 2 cards
        Row(
          children: [
            Expanded(child: _buildAnimatedCard(cards[2], 2)),
            const SizedBox(width: 12),
            Expanded(child: _buildAnimatedCard(cards[3], 3)),
          ],
        ),
        const SizedBox(height: 12),
        // Third row - 1 full width card
        _buildAnimatedCard(cards[4], 4, fullWidth: true),
      ],
    );
  }

  Widget _buildAnimatedCard(
    _PerformanceCardData card,
    int index, {
    bool fullWidth = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: card.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: card.gradient[0].withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                card.icon,
                color: Colors.white,
                size: fullWidth ? 28 : 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesPerformanceChart(ReportsProvider provider) {
    if (provider.dailyRevenue.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFC8E260).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.show_chart_rounded,
                size: 48,
                color: Color(0xFF324137),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No sales data available',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sales will appear here once recorded',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final spots = <FlSpot>[];
    double maxRevenue = 0;

    for (var i = 0; i < provider.dailyRevenue.length; i++) {
      final revenue = (provider.dailyRevenue[i]['revenue'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), revenue));
      if (revenue > maxRevenue) maxRevenue = revenue;
    }

    // Ensure maxRevenue is not zero to avoid division by zero
    if (maxRevenue == 0) maxRevenue = 100;

    // Calculate proper interval for Y axis
    final yInterval = maxRevenue / 4;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF324137).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: Color(0xFF324137),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sales Performance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324137),
                  ),
                ),
              ),
              // Chart type toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildChartTypeButton(Icons.show_chart_rounded, 0),
                    _buildChartTypeButton(Icons.bar_chart_rounded, 1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: _selectedChartType == 0
                ? _buildLineChart(spots, maxRevenue, yInterval, provider)
                : _buildBarChart(spots, maxRevenue, yInterval, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTypeButton(IconData icon, int type) {
    final isSelected = _selectedChartType == type;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedChartType = type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF324137) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildLineChart(
    List<FlSpot> spots,
    double maxRevenue,
    double yInterval,
    ReportsProvider provider,
  ) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= provider.dailyRevenue.length) {
                  return const SizedBox();
                }
                final dateStr = provider.dailyRevenue[index]['date'] as String;
                final parts = dateStr.split('-');
                if (parts.length == 3) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${parts[2]}/${parts[1]}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if (value < 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value >= 1000
                        ? '${(value / 1000).toStringAsFixed(1)}k'
                        : value.toInt().toString(),
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: 0,
        maxY: maxRevenue * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: const LinearGradient(
              colors: [Color(0xFF324137), Color(0xFF35AE4A)],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: Colors.white,
                  strokeWidth: 3,
                  strokeColor: const Color(0xFF35AE4A),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFC8E260).withOpacity(0.3),
                  const Color(0xFFC8E260).withOpacity(0.05),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => const Color(0xFF324137),
            tooltipRoundedRadius: 12,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  'Rs.${spot.y.toStringAsFixed(0)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }

  Widget _buildBarChart(
    List<FlSpot> spots,
    double maxRevenue,
    double yInterval,
    ReportsProvider provider,
  ) {
    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= provider.dailyRevenue.length) {
                  return const SizedBox();
                }
                final dateStr = provider.dailyRevenue[index]['date'] as String;
                final parts = dateStr.split('-');
                if (parts.length == 3) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${parts[2]}/${parts[1]}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if (value < 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value >= 1000
                        ? '${(value / 1000).toStringAsFixed(1)}k'
                        : value.toInt().toString(),
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        maxY: maxRevenue * 1.2,
        barGroups: spots.map((spot) {
          return BarChartGroupData(
            x: spot.x.toInt(),
            barRods: [
              BarChartRodData(
                toY: spot.y,
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xFF324137), Color(0xFF35AE4A)],
                ),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => const Color(0xFF324137),
            tooltipRoundedRadius: 12,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                'Rs.${rod.toY.toStringAsFixed(0)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(ReportsProvider provider) async {
    HapticFeedback.lightImpact();
    setState(() => _isExporting = true);

    final buffer = StringBuffer();
    buffer.writeln('Business Reports');
    buffer.writeln('Period,Last ${provider.dateFilter} Days');
    buffer.writeln('');

    buffer.writeln('Totals');
    buffer.writeln(
      'Total Revenue,Rs.${provider.totalRevenue.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Today Revenue,Rs.${provider.todayRevenue.toStringAsFixed(2)}',
    );
    buffer.writeln('Total Orders,${provider.totalOrders}');
    buffer.writeln(
      'Avg Order Value,Rs.${provider.avgOrderValue.toStringAsFixed(2)}',
    );
    buffer.writeln('Net Profit,Rs.${provider.totalProfit.toStringAsFixed(2)}');
    buffer.writeln('Margin,${provider.profitMargin.toStringAsFixed(1)}%');
    buffer.writeln('');

    buffer.writeln('Summary');
    buffer.writeln(
      'Completed Orders,${provider.summaryStats['completedOrders'] ?? 0}',
    );
    buffer.writeln(
      'Active Products,${provider.summaryStats['activeProducts'] ?? 0}',
    );
    buffer.writeln('Customers,${provider.summaryStats['totalCustomers'] ?? 0}');
    buffer.writeln(
      'Customer Satisfaction,${provider.customerSatisfaction.toStringAsFixed(1)}/5',
    );
    buffer.writeln(
      'Growth Rate,${provider.growthRate > 0 ? '+' : ''}${provider.growthRate.toStringAsFixed(1)}%',
    );
    buffer.writeln('');

    buffer.writeln('Top Products');
    buffer.writeln('Name,Units Sold,Unit Price,Revenue');
    for (final p in provider.topProducts) {
      buffer.writeln(
        "${p['name']},${p['quantity']},${p['price']},${p['revenue']}",
      );
    }

    final ok = await exportCsv('business_reports.csv', buffer.toString());

    setState(() => _isExporting = false);

    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Report exported successfully!',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF35AE4A),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              // const Expanded(
              //   child: Text(
              //     'Export not supported on this platform',
              //     style: TextStyle(fontWeight: FontWeight.w500),
              //   ),
              // ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Widget _buildTopProductsSection(ReportsProvider provider) {
    // Limit to top 5 products
    final topFive = provider.topProducts.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFC8E260).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFF324137),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Top Selling Products',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324137),
                  ),
                ),
              ),
              if (topFive.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC8E260), Color(0xFFa8c244)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Top ${topFive.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF324137),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (topFive.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No products sold in this period',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            )
          else
            ...topFive.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + (index * 100)),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(20 * (1 - value), 0),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: index < topFive.length - 1 ? 12 : 0,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: index == 0
                        ? const Color(0xFFC8E260).withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: index == 0
                          ? const Color(0xFFC8E260).withOpacity(0.3)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: index == 0
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFC8E260),
                                    Color(0xFFa8c244),
                                  ],
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.grey.shade200,
                                    Colors.grey.shade300,
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: index == 0
                              ? const Icon(
                                  Icons.emoji_events_rounded,
                                  color: Color(0xFF324137),
                                  size: 22,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
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
                              product['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF324137),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.shopping_bag_rounded,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${product['quantity']} units sold',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs. ${product['price']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF324137),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rs. ${product['revenue'].toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSummaryStatsSection(ReportsProvider provider) {
    final stats = provider.summaryStats;

    final summaryItems = [
      _SummaryItem(
        icon: Icons.check_circle_rounded,
        value: stats['completedOrders']?.toString() ?? '0',
        label: 'Completed\nOrders',
        color: const Color(0xFF35AE4A),
      ),
      _SummaryItem(
        icon: Icons.inventory_2_rounded,
        value: stats['activeProducts']?.toString() ?? '0',
        label: 'Active\nProducts',
        color: const Color(0xFF667eea),
      ),
      _SummaryItem(
        icon: Icons.people_rounded,
        value: stats['totalCustomers']?.toString() ?? '0',
        label: 'Total\nCustomers',
        color: const Color(0xFF4facfe),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF324137).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.summarize_rounded,
                  color: Color(0xFF324137),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF324137),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: summaryItems.map((item) {
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  margin: EdgeInsets.only(
                    right: item != summaryItems.last ? 10 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: item.color.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(item.icon, color: item.color, size: 28),
                      const SizedBox(height: 10),
                      Text(
                        item.value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: item.color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessInsightsSection(ReportsProvider provider) {
    final insights = [
      _InsightData(
        label: 'Profit Margin',
        value: '${provider.profitMargin.toStringAsFixed(1)}%',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF35AE4A),
      ),
      _InsightData(
        label: 'Customer Satisfaction',
        value: '${provider.customerSatisfaction.toStringAsFixed(1)}/5',
        icon: Icons.sentiment_satisfied_rounded,
        color: const Color(0xFF4facfe),
      ),
      _InsightData(
        label: 'Growth Rate',
        value:
            '${provider.growthRate > 0 ? '+' : ''}${provider.growthRate.toStringAsFixed(1)}%',
        icon: provider.growthRate >= 0
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded,
        color: provider.growthRate >= 0
            ? const Color(0xFFC8E260)
            : const Color(0xFFf5576c),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF324137), Color(0xFF1A2B1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF324137).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: Color(0xFFC8E260),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Business Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...insights.asMap().entries.map((entry) {
            final index = entry.key;
            final insight = entry.value;
            return Container(
              margin: EdgeInsets.only(
                bottom: index < insights.length - 1 ? 12 : 0,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: insight.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(insight.icon, color: insight.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      insight.label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: insight.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      insight.value,
                      style: TextStyle(
                        color: insight.color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Data classes for widgets
class _PerformanceCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;

  _PerformanceCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });
}

class _SummaryItem {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}

class _InsightData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _InsightData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
