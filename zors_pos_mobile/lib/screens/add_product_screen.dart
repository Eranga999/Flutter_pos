import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/product.dart';
import '../models/category.dart';
import '../providers/product_provider.dart';
import '../services/api_service.dart';

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
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes; // for web preview/upload

  final _picker = ImagePicker();
  List<Map<String, String>> _suppliers = [];

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
    ApiService.getSuppliers()
        .then((result) {
          if (result['success'] == true) {
            final data = result['data'];
            if (data is List) {
              setState(() {
                _suppliers = data
                    .map<Map<String, String>>((s) {
                      final map = s as Map<String, dynamic>;
                      final id = (map['_id'] ?? '').toString();
                      final name = (map['name'] ?? '').toString();
                      if (id.isEmpty || name.isEmpty)
                        return {'id': '', 'name': ''};
                      return {'id': id, 'name': name};
                    })
                    .where((s) => s['id']!.isNotEmpty && s['name']!.isNotEmpty)
                    .toList();
              });
            }
          } else {
            final msg = (result['message'] ?? 'Failed to load suppliers')
                .toString();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          }
        })
        .catchError((e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load suppliers: $e')),
          );
        });
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
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (res != null) {
      if (kIsWeb) {
        final bytes = await res.readAsBytes();
        setState(() {
          _pickedImage = res;
          _pickedImageBytes = bytes;
        });
      } else {
        setState(() {
          _pickedImage = res;
        });
      }
    }
  }

  MediaType _detectMediaType(String path) {
    final ext = path.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg'))
      return MediaType('image', 'jpeg');
    if (ext.endsWith('.png')) return MediaType('image', 'png');
    if (ext.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }
    // Use multipart/form-data to include image file
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/products');
      final req = http.MultipartRequest('POST', uri);

      // Add Authorization header if available
      final token = await ApiService.getToken();
      if (token != null) {
        req.headers['Authorization'] = 'Bearer $token';
      }

      // Required fields
      req.fields['name'] = _nameCtrl.text.trim();
      req.fields['costPrice'] = (_costCtrl.text.trim().isEmpty)
          ? '0'
          : _costCtrl.text.trim();
      req.fields['sellingPrice'] = (_sellCtrl.text.trim().isEmpty)
          ? '0'
          : _sellCtrl.text.trim();
      req.fields['category'] = _selectedCategory!; // backend expects name
      req.fields['stock'] = (_stockCtrl.text.trim().isEmpty)
          ? '0'
          : _stockCtrl.text.trim();
      req.fields['dryfood'] = _dryFood ? 'true' : 'false';

      // Optional fields
      if (_discountCtrl.text.trim().isNotEmpty) {
        req.fields['discount'] = _discountCtrl.text.trim();
      }
      if (_sizeCtrl.text.trim().isNotEmpty) {
        req.fields['size'] = _sizeCtrl.text.trim();
      }
      if (_descCtrl.text.trim().isNotEmpty) {
        req.fields['description'] = _descCtrl.text.trim();
      }
      if (_selectedSupplier != null && _selectedSupplier!.isNotEmpty) {
        req.fields['supplier'] =
            _selectedSupplier!; // backend expects supplier id
      }
      if (_barcodeCtrl.text.trim().isNotEmpty) {
        req.fields['barcode'] = _barcodeCtrl.text.trim();
      }
      if (_minStockCtrl.text.trim().isNotEmpty) {
        req.fields['minStock'] = _minStockCtrl.text.trim();
      }

      // Image file
      if (_pickedImage != null) {
        final filename = _pickedImage!.name;
        final mediaType = _detectMediaType(filename);
        if (kIsWeb) {
          final bytes = _pickedImageBytes ?? await _pickedImage!.readAsBytes();
          req.files.add(
            http.MultipartFile.fromBytes(
              'image',
              bytes,
              filename: filename,
              contentType: mediaType,
            ),
          );
        } else {
          final file = File(_pickedImage!.path);
          req.files.add(
            await http.MultipartFile.fromPath(
              'image',
              file.path,
              filename: filename,
              contentType: mediaType,
            ),
          );
        }
      }

      final res = await req.send();
      final body = await res.stream.bytesToString();

      if (res.statusCode == 201 || res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Product created')));
          // Optionally refresh provider products
          try {
            await Provider.of<ProductProvider>(
              context,
              listen: false,
            ).refreshProducts();
          } catch (_) {}
          Navigator.of(context).pop(true);
        }
      } else {
        String msg = 'Failed to create product (${res.statusCode})';
        try {
          final json = body.isNotEmpty ? jsonDecode(body) : null;
          if (json is Map && json['error'] is String) {
            msg = json['error'];
          } else if (json is Map && json['message'] is String) {
            msg = json['message'];
          }
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                    child: _pickedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: kIsWeb
                                ? (_pickedImageBytes != null
                                      ? Image.memory(
                                          _pickedImageBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.black54,
                                          ),
                                        ))
                                : Image.file(
                                    File(_pickedImage!.path),
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
                              value: supplier['id'],
                              child: Text(supplier['name'] ?? ''),
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
