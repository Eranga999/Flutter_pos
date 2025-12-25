import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;
import 'dart:convert' show base64Decode;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';
import 'add_product_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedCategoryFilter;
  String _stockFilter = 'all'; // 'all', 'low', 'inStock'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<ProductProvider>(context, listen: false);
        provider.fetchProducts();
        provider.fetchCategories();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _editProduct(BuildContext context, Product product) async {
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddProductScreen(product: product)),
    );
    if (updated == true && mounted) {
      Provider.of<ProductProvider>(context, listen: false).refreshProducts();
    }
  }

  void _deleteProduct(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<ProductProvider>(
                context,
                listen: false,
              );
              await provider.deleteProduct(product.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product deleted')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter Products'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stock Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                RadioListTile<String>(
                  title: const Text('All'),
                  value: 'all',
                  groupValue: _stockFilter,
                  onChanged: (val) => setDialogState(() => _stockFilter = val!),
                ),
                RadioListTile<String>(
                  title: const Text('Low Stock'),
                  value: 'low',
                  groupValue: _stockFilter,
                  onChanged: (val) => setDialogState(() => _stockFilter = val!),
                ),
                RadioListTile<String>(
                  title: const Text('In Stock'),
                  value: 'inStock',
                  groupValue: _stockFilter,
                  onChanged: (val) => setDialogState(() => _stockFilter = val!),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Category',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                DropdownButton<String?>(
                  value: _selectedCategoryFilter,
                  isExpanded: true,
                  hint: const Text('All Categories'),
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
                      setDialogState(() => _selectedCategoryFilter = val),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _stockFilter = 'all';
                _selectedCategoryFilter = null;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {}); // Apply filters
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Refresh Products'),
              onTap: () {
                Navigator.pop(ctx);
                Provider.of<ProductProvider>(
                  context,
                  listen: false,
                ).refreshProducts();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Products refreshed')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
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
    if (_stockFilter == 'low') {
      filtered = filtered.where((p) => p.stock <= p.minStock).toList();
    } else if (_stockFilter == 'inStock') {
      filtered = filtered.where((p) => p.stock > p.minStock).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);
    var products = _query.isEmpty
        ? provider.products
        : provider.searchProducts(_query);

    // Apply filters
    products = _applyFilters(products);

    final currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);
    final totalValue = products.fold<double>(
      0,
      (sum, p) => sum + (p.sellingPrice * p.stock),
    );
    final lowStockCount = products.where((p) => p.stock <= p.minStock).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF324137), Colors.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header card with admin + date and quick actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _HeaderCard(
                title: 'Manage your inventory',
                subtitle: 'ADMIN',
                dateText: DateFormat('EEEE, MMM d').format(DateTime.now()),
                onSettings: () => _showSettings(context),
                onMore: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('More options coming soon')),
                  );
                },
              ),
            ),
            // Stat boxes row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _StatBox(
                    icon: Icons.inventory_2_outlined,
                    label: 'Products',
                    value: products.length.toString(),
                  ),
                  const SizedBox(width: 8),
                  _StatBox(
                    icon: Icons.payments_outlined,
                    label: 'Value',
                    value: currency.format(totalValue),
                  ),
                  const SizedBox(width: 8),
                  _StatBox(
                    icon: Icons.warning_amber_rounded,
                    label: 'Low Stock',
                    value: lowStockCount.toString(),
                    accent: Colors.orange,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search products…',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.15),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Filter',
                      icon: Icon(
                        Icons.tune,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () => _showFilterDialog(context),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : products.isEmpty
                  ? const Center(child: Text('No products found'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, i) {
                        final p = products[i];
                        return _ProductCard(
                          product: p,
                          onEdit: () => _editProduct(context, p),
                          onDelete: () => _deleteProduct(context, p),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: products.length,
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddProductScreen()));
          if (created == true && mounted) {
            Provider.of<ProductProvider>(
              context,
              listen: false,
            ).refreshProducts();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = accent ?? Theme.of(context).colorScheme.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: c.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: c, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: c,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ProductCard({
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
    final low = product.stock <= product.minStock;
    final isNew = product.createdAt.isAfter(
      DateTime.now().subtract(const Duration(days: 7)),
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: low ? Colors.orange.withOpacity(0.4) : Colors.black12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _ProductImage(base64: product.image),
                if (isNew)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (product.category.isNotEmpty)
                          _Tag(text: product.category),
                        if ((product.supplier ?? '').isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _Tag(text: product.supplier!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          price,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (product.barcode != null &&
                            product.barcode!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.qr_code_2, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  product.barcode!,
                                  style: const TextStyle(
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        'Stock',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        product.stock.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: low ? Colors.orange : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? base64;
  const _ProductImage({this.base64});

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (base64 != null && base64!.isNotEmpty) {
      try {
        // Remove data URL prefix if present (e.g., "data:image/png;base64,")
        String cleanBase64 = base64!.trim();

        // Remove common data URL prefixes
        if (cleanBase64.startsWith('data:')) {
          final parts = cleanBase64.split(',');
          if (parts.length > 1) {
            cleanBase64 = parts[1];
          }
        }

        // Remove any whitespace or newlines
        cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');

        child = Image.memory(
          base64Decode(cleanBase64),
          fit: BoxFit.cover,
          width: 80,
          height: 80,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, color: Colors.grey, size: 40);
          },
        );
      } catch (e) {
        child = const Icon(Icons.broken_image, color: Colors.grey, size: 40);
      }
    } else {
      child = const Icon(
        Icons.inventory_2_outlined,
        color: Colors.grey,
        size: 40,
      );
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFC8E260).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: child),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String dateText;
  final VoidCallback? onSettings;
  final VoidCallback? onMore;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.dateText,
    this.onSettings,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: const Color(0xFFC8E260),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateText,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              _HeaderIcon(icon: Icons.settings, onTap: onSettings),
              const SizedBox(width: 8),
              _HeaderIcon(icon: Icons.more_horiz, onTap: onMore),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap ?? () {},
      ),
    );
  }
}

extension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
