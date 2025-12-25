import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/category.dart';
import '../providers/product_provider.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _costCtrl = TextEditingController(text: '0');
  final _sellCtrl = TextEditingController(text: '0');
  final _discountCtrl = TextEditingController(text: '0');
  final _stockCtrl = TextEditingController(text: '0');
  final _minStockCtrl = TextEditingController(text: '5');
  final _sizeCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _selectedCategory;
  String? _selectedSupplier;
  bool _dryFood = false;
  String? _imageBase64;
  String? _imageFileName;
  List<int>? _imageBytes;

  final _picker = ImagePicker();
  List<String> _suppliers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<ProductProvider>(context, listen: false);
        provider.fetchCategories();
        // Fetch suppliers if needed
        _loadSuppliers();
      }
    });
  }

  void _loadSuppliers() {
    // TODO: Fetch suppliers from API if available
    // For now, using hardcoded list or fetch from provider
    _suppliers = ['Supplier A', 'Supplier B', 'Supplier C'];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _costCtrl.dispose();
    _sellCtrl.dispose();
    _discountCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    _sizeCtrl.dispose();
    _barcodeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final res = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 5, // Extremely aggressive compression
      maxWidth: 300, // Very small dimensions
      maxHeight: 300,
    );
    if (res != null) {
      final bytes = await res.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageBase64 = base64Encode(bytes);
        _imageFileName = res.name;
      });
      print(
        'Image selected: ${bytes.length} bytes (base64: ${_imageBase64!.length} chars)',
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    final provider = Provider.of<ProductProvider>(context, listen: false);

    // Store image locally (in-app) if selected
    String? imageData;
    if (_imageBase64 != null) {
      final base64Size = _imageBase64!.length;
      print('Base64 image size: $base64Size characters');

      // If image is too large (> 500KB base64), skip it to avoid payload errors
      if (base64Size > 500000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image too large. Creating product without image...'),
            duration: Duration(seconds: 2),
          ),
        );
        imageData = null; // Skip image
      } else {
        imageData = _imageBase64;
        print('Image stored: $base64Size chars');
      }
    }

    final product = Product(
      id: '', // server will assign _id
      name: _nameCtrl.text.trim(),
      category: _selectedCategory!,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      costPrice: double.tryParse(_costCtrl.text) ?? 0,
      sellingPrice: double.tryParse(_sellCtrl.text) ?? 0,
      stock: int.tryParse(_stockCtrl.text) ?? 0,
      minStock: int.tryParse(_minStockCtrl.text) ?? 5,
      barcode: _barcodeCtrl.text.trim().isEmpty
          ? null
          : _barcodeCtrl.text.trim(),
      image: imageData, // Store base64 image (or null if too large)
      supplier: _selectedSupplier,
      discount: double.tryParse(_discountCtrl.text) ?? 0,
      size: _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
      dryfood: _dryFood,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final ok = await provider.createProduct(product);
    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product created')));
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Failed to create product')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Product'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: const Text(
              'Fill in the product details below',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.9),
                Colors.black.withOpacity(0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image uploader
                Text(
                  'Product Image',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickImage,
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8E260).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFC8E260),
                        width: 1.6,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _imageBase64 != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              base64Decode(_imageBase64!),
                              fit: BoxFit.cover,
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.image,
                                  size: 40,
                                  color: Colors.black54,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap to upload image',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                _LabeledField(
                  label: 'Product Name *',
                  controller: _nameCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  hintText: 'Enter product name',
                ),
                const SizedBox(height: 12),

                // Category Dropdown
                Consumer<ProductProvider>(
                  builder: (context, provider, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Category *'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        hint: const Text('Select a category'),
                        items: provider.categories
                            .map(
                              (cat) => DropdownMenuItem<String>(
                                value: cat.name,
                                child: Text(cat.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedCategory = value),
                        validator: (v) =>
                            v == null ? 'Please select a category' : null,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Supplier Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Supplier'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedSupplier,
                      hint: const Text('Select supplier (optional)'),
                      items: _suppliers
                          .map(
                            (supplier) => DropdownMenuItem<String>(
                              value: supplier,
                              child: Text(supplier),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedSupplier = value),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _LabeledField(
                  label: 'Cost Price *',
                  controller: _costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => (double.tryParse(v ?? '') == null)
                      ? 'Enter a valid number'
                      : null,
                  hintText: '0.00',
                ),
                const SizedBox(height: 12),

                _LabeledField(
                  label: 'Selling Price *',
                  controller: _sellCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => (double.tryParse(v ?? '') == null)
                      ? 'Enter a valid number'
                      : null,
                  hintText: '0.00',
                ),
                const SizedBox(height: 12),

                _LabeledField(
                  label: 'Discount (%)',
                  controller: _discountCtrl,
                  keyboardType: TextInputType.number,
                  hintText: '0',
                ),
                const SizedBox(height: 12),

                _LabeledField(
                  label: 'Stock Quantity *',
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  validator: (v) => (int.tryParse(v ?? '') == null)
                      ? 'Enter a valid integer'
                      : null,
                  hintText: '0',
                ),
                const SizedBox(height: 12),

                _LabeledField(
                  label: 'Minimum Stock',
                  controller: _minStockCtrl,
                  keyboardType: TextInputType.number,
                  hintText: '5',
                ),
                const SizedBox(height: 12),

                _LabeledField(
                  label: 'Size',
                  controller: _sizeCtrl,
                  hintText: 'Eg: Small, Medium, Large',
                ),
                const SizedBox(height: 12),

                _LabeledField(
                  label: 'Barcode',
                  controller: _barcodeCtrl,
                  hintText: 'Auto-generate if empty',
                ),
                const SizedBox(height: 12),

                _LabeledField(
                  label: 'Description',
                  controller: _descCtrl,
                  maxLines: 3,
                  hintText: 'Write product description...',
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Switch(
                      value: _dryFood,
                      onChanged: (v) => setState(() => _dryFood = v),
                    ),
                    const SizedBox(width: 8),
                    const Text('This is a dry food item'),
                  ],
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Add Product'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? hintText;
  final String? Function(String?)? validator;
  final int maxLines;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.hintText,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
