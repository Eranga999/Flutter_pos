import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reports_provider.dart';
import '../utils/export_helper.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().fetchReports(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header matching POS screen
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF324137), Colors.black],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 4),
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
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Business Reports',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _exportCsv(provider),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.download,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: provider.loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Description
                          Text(
                            'Comprehensive insights into your business performance',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Date Filter
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButton<String>(
                              value: provider.dateFilter,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                  value: '7',
                                  child: Text('Last 7 Days'),
                                ),
                                DropdownMenuItem(
                                  value: '30',
                                  child: Text('Last 30 Days'),
                                ),
                                DropdownMenuItem(
                                  value: '90',
                                  child: Text('Last 90 Days'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  context.read<ReportsProvider>().fetchReports(
                                    value,
                                  );
                                }
                              },
                            ),
                          ),
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
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCards(ReportsProvider provider) {
    final stats = provider.summaryStats;
    final activeProducts = stats['activeProducts'] ?? 0;
    final totalCustomers = stats['totalCustomers'] ?? 0;

    Widget card({
      required String title,
      required String value,
      required String subtitle,
      Color? accent,
    }) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 0.8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: accent ?? const Color(0xFF324137),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        card(
          title: 'Total Revenue',
          value: 'Rs.${provider.totalRevenue.toStringAsFixed(2)}',
          subtitle: 'Today: Rs.${provider.todayRevenue.toStringAsFixed(2)}',
          accent: Colors.green,
        ),
        card(
          title: 'Total Orders',
          value: provider.totalOrders.toString(),
          subtitle: 'Avg: Rs.${provider.avgOrderValue.toStringAsFixed(2)}',
          accent: Colors.black,
        ),
        card(
          title: 'Products',
          value: activeProducts.toString(),
          subtitle: '0 low stock',
          accent: Colors.black,
        ),
        card(
          title: 'Customers',
          value: totalCustomers.toString(),
          subtitle: 'Return rate: 0%',
          accent: Colors.black,
        ),
        card(
          title: 'Net Profit',
          value: 'Rs.${provider.totalProfit.toStringAsFixed(2)}',
          subtitle: 'Margin: ${provider.profitMargin.toStringAsFixed(1)}%',
          accent: Colors.red,
        ),
      ],
    );
  }

  Widget _buildSalesPerformanceChart(ReportsProvider provider) {
    if (provider.dailyRevenue.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No sales data available',
            style: TextStyle(color: Colors.grey[600]),
          ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Performance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF324137),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
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
                        if (index < 0 ||
                            index >= provider.dailyRevenue.length) {
                          return const SizedBox();
                        }
                        final dateStr =
                            provider.dailyRevenue[index]['date'] as String;
                        // Parse date (format: YYYY-MM-DD) and display as DD/MM
                        final parts = dateStr.split('-');
                        if (parts.length == 3) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${parts[2]}/${parts[1]}',
                              style: TextStyle(
                                color: Colors.grey[700],
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
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                    left: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: 0,
                maxY: maxRevenue * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF324137),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFF324137),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF324137).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(ReportsProvider provider) async {
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
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported as business_reports.csv')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export not supported on this platform')),
      );
    }
  }

  Widget _buildTopProductsSection(ReportsProvider provider) {
    // Limit to top 5 products
    final topFive = provider.topProducts.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Selling Products',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF324137),
                ),
              ),
              if (topFive.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E260),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Top ${topFive.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF324137),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (topFive.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No products sold in this period',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else
            ...topFive.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8E260),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 16,
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
                            product['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${product['quantity']} units sold',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
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
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Rs. ${product['revenue'].toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSummaryStatsSection(ReportsProvider provider) {
    final stats = provider.summaryStats;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            offset: Offset(0, 4),
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
              fontWeight: FontWeight.w600,
              color: Color(0xFF324137),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStat(
                'Completed\nOrders',
                stats['completedOrders']?.toString() ?? '0',
              ),
              _buildSummaryStat(
                'Active\nProducts',
                stats['activeProducts']?.toString() ?? '0',
              ),
              _buildSummaryStat(
                'Total\nCustomers',
                stats['totalCustomers']?.toString() ?? '0',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF324137),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildBusinessInsightsSection(ReportsProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF324137), Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Insights',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInsightRow(
                  'Profit Margin',
                  '${provider.profitMargin.toStringAsFixed(1)}%',
                  Colors.greenAccent,
                ),
                const SizedBox(height: 8),
                _buildInsightRow(
                  'Customer Satisfaction',
                  '${provider.customerSatisfaction.toStringAsFixed(1)}/5',
                  Colors.blueAccent,
                ),
                const SizedBox(height: 8),
                _buildInsightRow(
                  'Growth Rate',
                  '${provider.growthRate > 0 ? '+' : ''}${provider.growthRate.toStringAsFixed(1)}%',
                  provider.growthRate >= 0
                      ? Colors.orangeAccent
                      : Colors.redAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
