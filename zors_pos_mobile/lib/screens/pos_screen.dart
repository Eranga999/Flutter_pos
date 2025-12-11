import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/order_provider.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import 'cart_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    productProvider.fetchProducts();
    productProvider.fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildCategoryChips(),
            Expanded(
              child: Consumer<ProductProvider>(
                builder: (context, productProvider, _) {
                  if (productProvider.isLoading &&
                      productProvider.products.isEmpty) {
                    return const LoadingWidget(message: 'Loading products...');
                  }

                  if (productProvider.error != null &&
                      productProvider.products.isEmpty) {
                    return CustomErrorWidget(
                      message: productProvider.error!,
                      onRetry: _loadData,
                    );
                  }

                  final products = _filteredProducts(productProvider);

                  if (products.isEmpty) {
                    return const Center(child: Text('No products found'));
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: GridView.builder(
                      itemCount: products.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return _buildProductCard(product, orderProvider);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildCartButton(orderProvider),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  List<dynamic> _filteredProducts(ProductProvider provider) {
    final searchText = _searchController.text.trim().toLowerCase();

    final byCategory = _selectedCategory == 'All'
        ? provider.products
        : provider.products
              .where(
                (p) =>
                    p.category.toLowerCase() == _selectedCategory.toLowerCase(),
              )
              .toList();

    if (searchText.isEmpty) return byCategory;

    return byCategory
        .where((p) => p.name.toLowerCase().contains(searchText))
        .toList();
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF324137), Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: const Center(
        child: Text(
          'POS System',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF324137), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        final categories = ['All', ...provider.categories.map((c) => c.name)];
        return SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = _selectedCategory == category;
              return ChoiceChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedCategory = category);
                },
                selectedColor: const Color(0xFF324137),
                backgroundColor: Colors.grey.shade200,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductCard(dynamic product, OrderProvider orderProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _stockBadge(product.stock),
                const Icon(Icons.more_vert, size: 20, color: Colors.black54),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.image != null && product.image!.isNotEmpty
                      ? Image.network(
                          product.image!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                color: const Color(0xFF324137),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultImagePlaceholder();
                          },
                        )
                      : _buildDefaultImagePlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF324137),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              product.description ?? product.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'Rs. ${product.sellingPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF324137),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: () {
                  orderProvider.addToCart(
                    product.id,
                    product.name,
                    1,
                    product.sellingPrice,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} added to cart'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF35AE4A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Add to Cart',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockBadge(int? stock) {
    final value = stock ?? 0;
    final color = value > 0 ? const Color(0xFF35AE4A) : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        'Stock $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDefaultImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 6),
            Text(
              'No Image',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartButton(OrderProvider orderProvider) {
    final count = orderProvider.cartItems.length;
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CartScreen()));
      },
      backgroundColor: const Color(0xFF324137),
      icon: const Icon(Icons.shopping_cart_outlined),
      label: Text(count > 0 ? '$count item(s)' : 'Cart'),
    );
  }
}
