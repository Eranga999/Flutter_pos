import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/product.dart';
import '../models/category.dart';
import '../providers/product_provider.dart';
import '../services/api_service.dart';
import '../utils/local_image_store.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product; // null for add, non-null for edit
  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with TickerProviderStateMixin {
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
  Uint8List? _pickedImageBytes;
  String? _existingImageBase64;
  String? _originalBarcode;
  bool _isSubmitting = false;

  final _picker = ImagePicker();
  List<Map<String, String>> _suppliers = [];

  // Animation controllers
  late AnimationController _headerController;
  late AnimationController _contentController;
  late Animation<double> _headerAnimation;
  late Animation<double> _contentAnimation;

  // Focus nodes
  final _nameFocus = FocusNode();
  final _costFocus = FocusNode();
  final _sellFocus = FocusNode();
  final _stockFocus = FocusNode();

  bool get isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();
    _initAnimations();

    // Pre-fill if editing
    if (isEditMode) {
      final p = widget.product!;
      _nameCtrl.text = p.name;
      _costCtrl.text = p.costPrice.toString();
      _sellCtrl.text = p.sellingPrice.toString();
      _discountCtrl.text = (p.discount ?? 0).toString();
      _stockCtrl.text = p.stock.toString();
      _minStockCtrl.text = p.minStock.toString();
      _sizeCtrl.text = p.size ?? '';
      _barcodeCtrl.text = p.barcode ?? '';
      _descCtrl.text = p.description ?? '';
      _selectedCategory = (p.category.isNotEmpty) ? p.category : null;
      _selectedSupplier = (p.supplier != null && p.supplier!.isNotEmpty)
          ? p.supplier
          : null;
      _dryFood = p.dryfood ?? false;
      _existingImageBase64 = p.image;
      _originalBarcode = p.barcode;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<ProductProvider>(context, listen: false);
        provider.fetchCategories();
        _loadSuppliers();
      }
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
    _nameFocus.dispose();
    _costFocus.dispose();
    _sellFocus.dispose();
    _stockFocus.dispose();
    _headerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();

    // Show image source picker
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF324137).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.image_rounded,
                    color: Color(0xFF324137),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Choose Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324137),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ImageSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ImageSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final res = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (res != null) {
      HapticFeedback.mediumImpact();
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
    HapticFeedback.lightImpact();

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (_selectedCategory == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Please select a category'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    // Use multipart/form-data to include image file
    try {
      final uri = isEditMode
          ? Uri.parse('${ApiService.baseUrl}/products/${widget.product!.id}')
          : Uri.parse('${ApiService.baseUrl}/products');
      final req = http.MultipartRequest(isEditMode ? 'PUT' : 'POST', uri);

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
      req.fields['minStock'] = (_minStockCtrl.text.trim().isEmpty)
          ? '5'
          : _minStockCtrl.text.trim();
      req.fields['dryfood'] = _dryFood ? 'true' : 'false';

      // Optional fields
      if (_discountCtrl.text.trim().isNotEmpty) {
        req.fields['discount'] = _discountCtrl.text.trim();
      } else {
        req.fields['discount'] = '0';
      }
      if (_sizeCtrl.text.trim().isNotEmpty) {
        req.fields['size'] = _sizeCtrl.text.trim();
      }
      if (_descCtrl.text.trim().isNotEmpty) {
        req.fields['description'] = _descCtrl.text.trim();
      }
      if (_selectedSupplier != null && _selectedSupplier!.isNotEmpty) {
        req.fields['supplier'] = _selectedSupplier!;
      }

      // Handle barcode: only send on update if changed
      final currentBarcode = _barcodeCtrl.text.trim();
      if (isEditMode) {
        final original = (_originalBarcode ?? '').trim();
        if (currentBarcode.isNotEmpty && currentBarcode != original) {
          req.fields['barcode'] = currentBarcode;
        }
        // If unchanged or empty, omit to prevent duplicate check firing
      } else {
        if (currentBarcode.isNotEmpty) {
          req.fields['barcode'] = currentBarcode;
        }
      }

      if (_minStockCtrl.text.trim().isNotEmpty) {
        req.fields['minStock'] = _minStockCtrl.text.trim();
      }

      // Image file
      // Skipped backend upload per requirement: store locally after success.
      // No files are attached to the request; image will be saved on-device.

      final res = await req.send();
      final body = await res.stream.bytesToString();

      print('✅ Response status: ${res.statusCode}');
      print('✅ Response body: $body');

      if (res.statusCode == 201 || res.statusCode == 200) {
        // Parse response to check if image was saved
        try {
          final responseData = jsonDecode(body);
          if (responseData is Map) {
            final savedImage = responseData['image'];
            if (_pickedImage != null) {
              if (savedImage == null || savedImage.toString().isEmpty) {
                print(
                  '⚠️ WARNING: Image was uploaded but not saved in database!',
                );
                print('⚠️ Backend may not be processing the image correctly');
              } else {
                print('✅ Image saved successfully: $savedImage');
              }
            }
          }
        } catch (e) {
          print('Could not parse response: $e');
        }

        // Always save image locally (not backend)
        try {
          if (_pickedImage != null) {
            final parsed = jsonDecode(body);
            String productId = '';
            if (parsed is Map) {
              final data = parsed['data'];
              if (parsed['_id'] is String) {
                productId = parsed['_id'] as String;
              } else if (data is Map && data['_id'] is String) {
                productId = data['_id'] as String;
              } else if (parsed['product'] is Map &&
                  (parsed['product'] as Map)['_id'] is String) {
                productId = (parsed['product'] as Map)['_id'] as String;
              }
            }

            // Fallback to edit mode product id when not present in response
            if (productId.isEmpty && isEditMode) {
              productId = widget.product!.id;
            }

            if (productId.isNotEmpty) {
              final bytes = kIsWeb
                  ? (_pickedImageBytes ?? await _pickedImage!.readAsBytes())
                  : await File(_pickedImage!.path).readAsBytes();
              var ext = 'png';
              final lower = _pickedImage!.name.toLowerCase();
              if (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
                ext = 'jpg';
              else if (lower.endsWith('.png'))
                ext = 'png';
              else if (lower.endsWith('.webp'))
                ext = 'webp';

              print(
                '💾 Saving image for product: $productId (ext: $ext, size: ${bytes.length} bytes)',
              );
              await LocalImageStore.saveProductImage(
                productId,
                bytes,
                extension: ext,
              );
              print('✅ Saved product image locally for productId=$productId');

              // Verify it was saved
              final verify = await LocalImageStore.getProductImage(productId);
              if (verify != null) {
                print(
                  '✅ Verified: Image retrieved from cache (${verify.length} bytes)',
                );
              } else {
                print('⚠️ WARNING: Could not retrieve saved image!');
              }
            } else {
              print('⚠️ Could not determine productId to cache image');
            }
          }
        } catch (e) {
          print('⚠️ Failed to save image locally: $e');
        }

        print('✅ Product ${isEditMode ? 'updated' : 'created'} successfully');
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    isEditMode
                        ? 'Product updated successfully!'
                        : 'Product created successfully!',
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF35AE4A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
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
        setState(() => _isSubmitting = false);
        String msg =
            'Failed to ${isEditMode ? 'update' : 'create'} product (${res.statusCode})';
        try {
          final json = body.isNotEmpty ? jsonDecode(body) : null;
          if (json is Map && json['error'] is String) {
            msg = json['error'];
          } else if (json is Map && json['message'] is String) {
            msg = json['message'];
          } else if (json is Map) {
            msg += '\nDetails: ${json.toString()}';
          }
        } catch (e) {
          msg +=
              '\nResponse: ${body.length > 200 ? body.substring(0, 200) : body}';
        }
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(msg)),
                ],
              ),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            FadeTransition(
              opacity: _headerAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.3),
                  end: Offset.zero,
                ).animate(_headerAnimation),
                child: Container(
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
                              Navigator.pop(context, false);
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
                                'Add Product',
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
                          const SizedBox(width: 44),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isEditMode
                                  ? Icons.edit_rounded
                                  : Icons.add_box_rounded,
                              color: const Color(0xFFC8E260),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isEditMode
                                    ? 'Update product information'
                                    : 'Fill in the product details below',
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
                ),
              ),
            ),

            // Content
            Expanded(
              child: FadeTransition(
                opacity: _contentAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(_contentAnimation),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image Section
                          _buildSectionCard(
                            title: 'Product Image',
                            icon: Icons.image_rounded,
                            child: _buildImagePicker(),
                          ),

                          const SizedBox(height: 16),

                          // Basic Info Section
                          _buildSectionCard(
                            title: 'Basic Information',
                            icon: Icons.info_outline_rounded,
                            child: Column(
                              children: [
                                _ModernTextField(
                                  label: 'Product Name',
                                  hint: 'Enter product name',
                                  controller: _nameCtrl,
                                  icon: Icons.inventory_2_rounded,
                                  isRequired: true,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Product name is required'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _buildCategoryDropdown(),
                                const SizedBox(height: 16),
                                _buildSupplierDropdown(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Pricing Section
                          _buildSectionCard(
                            title: 'Pricing',
                            icon: Icons.attach_money_rounded,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ModernTextField(
                                        label: 'Cost Price',
                                        hint: '0.00',
                                        controller: _costCtrl,
                                        icon: Icons.money_off_rounded,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        isRequired: true,
                                        validator: (v) =>
                                            (double.tryParse(v ?? '') == null)
                                            ? 'Invalid'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _ModernTextField(
                                        label: 'Selling Price',
                                        hint: '0.00',
                                        controller: _sellCtrl,
                                        icon: Icons.paid_rounded,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        isRequired: true,
                                        validator: (v) =>
                                            (double.tryParse(v ?? '') == null)
                                            ? 'Invalid'
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _ModernTextField(
                                  label: 'Discount',
                                  hint: '0',
                                  controller: _discountCtrl,
                                  icon: Icons.discount_rounded,
                                  keyboardType: TextInputType.number,
                                  suffix: const Text('%'),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Inventory Section
                          _buildSectionCard(
                            title: 'Inventory',
                            icon: Icons.warehouse_rounded,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ModernTextField(
                                        label: 'Stock Quantity',
                                        hint: '0',
                                        controller: _stockCtrl,
                                        icon: Icons.numbers_rounded,
                                        keyboardType: TextInputType.number,
                                        isRequired: true,
                                        validator: (v) =>
                                            (int.tryParse(v ?? '') == null)
                                            ? 'Invalid'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _ModernTextField(
                                        label: 'Min Stock',
                                        hint: '5',
                                        controller: _minStockCtrl,
                                        icon: Icons.warning_amber_rounded,
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _ModernTextField(
                                  label: 'Barcode',
                                  hint: 'Auto-generate if empty',
                                  controller: _barcodeCtrl,
                                  icon: Icons.qr_code_2_rounded,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Additional Info Section
                          _buildSectionCard(
                            title: 'Additional Info',
                            icon: Icons.more_horiz_rounded,
                            child: Column(
                              children: [
                                _ModernTextField(
                                  label: 'Size',
                                  hint: 'e.g., Small, Medium, Large',
                                  controller: _sizeCtrl,
                                  icon: Icons.straighten_rounded,
                                ),
                                const SizedBox(height: 16),
                                _ModernTextField(
                                  label: 'Description',
                                  hint: 'Write product description...',
                                  controller: _descCtrl,
                                  icon: Icons.description_rounded,
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 16),
                                _buildDryFoodToggle(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Action Buttons
                          _buildActionButtons(),

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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF324137).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF324137), size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324137),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    final hasImage =
        _pickedImage != null ||
        (_existingImageBase64 != null && _existingImageBase64!.isNotEmpty);

    return GestureDetector(
      onTap: _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 160,
        decoration: BoxDecoration(
          color: hasImage
              ? Colors.transparent
              : const Color(0xFFC8E260).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage
                ? const Color(0xFF35AE4A)
                : const Color(0xFFC8E260).withOpacity(0.5),
            width: 2,
            style: hasImage ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: _pickedImage != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: kIsWeb
                          ? (_pickedImageBytes != null
                                ? Image.memory(
                                    _pickedImageBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : _buildImagePlaceholder())
                          : Image.file(
                              File(_pickedImage!.path),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF35AE4A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Change',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : (_existingImageBase64 != null && _existingImageBase64!.isNotEmpty)
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: _existingImageBase64!.contains('/')
                          ? Image.network(
                              '${ApiService.baseUrl}/products/images/${_existingImageBase64!}',
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                            : null,
                                        color: const Color(0xFF324137),
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildImagePlaceholder(),
                            )
                          : Image.memory(
                              base64Decode(
                                _existingImageBase64!.contains(',')
                                    ? _existingImageBase64!.split(',').last
                                    : _existingImageBase64!,
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildImagePlaceholder(),
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Change',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFC8E260).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_photo_alternate_rounded,
              size: 32,
              color: Color(0xFF324137),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap to upload image',
            style: TextStyle(
              color: Color(0xFF324137),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Supports JPG, PNG, WebP',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        final names = provider.categories
            .map((c) => c.name)
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.category_rounded,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Text(' *', style: TextStyle(color: Colors.red)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonFormField<String>(
                value:
                    (_selectedCategory != null &&
                        names.contains(_selectedCategory))
                    ? _selectedCategory
                    : null,
                hint: Text(
                  'Select a category',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                borderRadius: BorderRadius.circular(14),
                items: names
                    .map(
                      (name) => DropdownMenuItem<String>(
                        value: name,
                        child: Text(name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = value);
                },
                validator: (v) => v == null ? 'Please select a category' : null,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSupplierDropdown() {
    final ids = _suppliers
        .map((s) => (s['id'] ?? ''))
        .where((id) => id.isNotEmpty)
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_shipping_rounded,
              size: 16,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              'Supplier',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              ' (optional)',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonFormField<String>(
            value:
                (_selectedSupplier != null && ids.contains(_selectedSupplier))
                ? _selectedSupplier
                : null,
            hint: Text(
              'Select supplier',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            borderRadius: BorderRadius.circular(14),
            items: _suppliers
                .map(
                  (supplier) => DropdownMenuItem<String>(
                    value: supplier['id'],
                    child: Text(supplier['name'] ?? ''),
                  ),
                )
                .toList(),
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _selectedSupplier = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDryFoodToggle() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _dryFood = !_dryFood);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _dryFood
              ? const Color(0xFFC8E260).withOpacity(0.15)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _dryFood ? const Color(0xFFC8E260) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _dryFood
                    ? const Color(0xFF324137)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _dryFood ? Icons.check_rounded : Icons.grain_rounded,
                size: 18,
                color: _dryFood ? Colors.white : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dry Food Item',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF324137),
                    ),
                  ),
                  Text(
                    'Toggle if this is a dry food product',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                color: _dryFood
                    ? const Color(0xFF35AE4A)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _dryFood
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _isSubmitting
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop(false);
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _isSubmitting ? null : _submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isSubmitting
                      ? [Colors.grey.shade400, Colors.grey.shade500]
                      : [const Color(0xFF35AE4A), const Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _isSubmitting
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF35AE4A).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Center(
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isEditMode ? Icons.save_rounded : Icons.add_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isEditMode ? 'Update Product' : 'Add Product',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Image Source Option Widget
class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF324137).withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF324137).withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: const Color(0xFF324137)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF324137),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modern Text Field Widget
class _ModernTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool isRequired;
  final String? Function(String?)? validator;
  final int maxLines;
  final Widget? suffix;

  const _ModernTextField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.isRequired = false,
    this.validator,
    this.maxLines = 1,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            if (isRequired)
              const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 15, color: Color(0xFF324137)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade50,
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: suffix,
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF324137),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
