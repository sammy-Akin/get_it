import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';

class VendorProductsScreen extends StatelessWidget {
  const VendorProductsScreen({super.key});

  static const List<String> _categoryOptions = [
    'Groceries',
    'Snacks',
    'Food',
    'Drinks',
    'Toiletries',
    'Household',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(
          'My Products',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _showProductSheet(context, uid, null),
              icon: const Icon(
                Icons.add_rounded,
                color: AppTheme.primary,
                size: 18,
              ),
              label: const Text(
                'Add',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('getit_products')
            .where('shopId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) return _buildEmpty(context, uid);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _ProductTile(
                data: data,
                docId: docs[index].id,
                vendorId: uid,
                onEdit: () => _showProductSheet(context, uid, docs[index]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductSheet(context, uid, null),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, String uid) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppTheme.textSecondary,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No products yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your first product to start selling',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 180,
            child: ElevatedButton(
              onPressed: () => _showProductSheet(context, uid, null),
              child: const Text('Add Product'),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductSheet(
    BuildContext context,
    String vendorId,
    DocumentSnapshot? existing,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ProductSheet(
        vendorId: vendorId,
        existing: existing,
        categoryOptions: _categoryOptions,
      ),
    );
  }
}

class _ProductSheet extends StatefulWidget {
  final String vendorId;
  final DocumentSnapshot? existing;
  final List<String> categoryOptions;

  const _ProductSheet({
    required this.vendorId,
    required this.existing,
    required this.categoryOptions,
  });

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedCategory = '';
  bool _isAvailable = true;
  bool _isLoading = false;

  XFile? _pickedImage;
  String _existingImageUrl = '';

  @override
  void initState() {
    super.initState();
    final data = widget.existing?.data() as Map<String, dynamic>?;
    if (data != null) {
      _nameCtrl.text = data['name'] ?? '';
      _priceCtrl.text = '${data['price'] ?? ''}';
      _descCtrl.text = data['description'] ?? '';
      _selectedCategory = data['category'] ?? '';
      _isAvailable = data['isAvailable'] ?? true;
      _existingImageUrl = data['imageUrl'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Product Image',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ImageOptionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Take Photo',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImageOptionButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<String> _uploadImage(String vendorId) async {
    if (_pickedImage == null) return _existingImageUrl;

    final ref = FirebaseStorage.instance
        .ref()
        .child('product_images')
        .child(vendorId)
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

    if (kIsWeb) {
      final bytes = await _pickedImage!.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      await ref.putFile(File(_pickedImage!.path));
    }

    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in name and price')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final imageUrl = await _uploadImage(widget.vendorId);

      final shopDoc = await FirebaseFirestore.instance
          .collection('getit_users')
          .doc(widget.vendorId)
          .get();
      final shopName =
          shopDoc.data()?['shopName'] ??
          shopDoc.data()?['fullName'] ??
          'My Shop';

      final productData = {
        'name': _nameCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
        'category': _selectedCategory,
        'description': _descCtrl.text.trim(),
        'shopId': widget.vendorId,
        'shopName': shopName,
        'isAvailable': _isAvailable,
        'imageUrl': imageUrl,
        'stockQty': 99,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.existing == null) {
        productData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('getit_products')
            .add(productData);
      } else {
        await FirebaseFirestore.instance
            .collection('getit_products')
            .doc(widget.existing!.id)
            .update(productData);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    await FirebaseFirestore.instance
        .collection('getit_products')
        .doc(widget.existing!.id)
        .delete();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              widget.existing == null ? 'Add Product' : 'Edit Product',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 20),

            // Image picker
            Center(
              child: GestureDetector(
                onTap: _showImagePicker,
                child: Container(
                  width: 180,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          _pickedImage != null || _existingImageUrl.isNotEmpty
                          ? AppTheme.primary.withOpacity(0.4)
                          : AppTheme.cardBorder,
                      width: 1.5,
                    ),
                  ),
                  child: _buildImagePreview(),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Name
            _field(_nameCtrl, 'Product name', Icons.label_outline),
            const SizedBox(height: 12),

            // Price
            _field(
              _priceCtrl,
              'Price (₦)',
              Icons.payments_outlined,
              isNumber: true,
            ),
            const SizedBox(height: 12),

            // Category
            const Text(
              'Category',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildCategoryChips(),
            const SizedBox(height: 12),

            // Description
            _field(
              _descCtrl,
              'Description (optional)',
              Icons.notes_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Available toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available for sale',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontFamily: 'Poppins',
                      fontSize: 14,
                    ),
                  ),
                  Switch(
                    value: _isAvailable,
                    onChanged: (v) => setState(() => _isAvailable = v),
                    activeColor: AppTheme.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Save button
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.existing == null ? 'Add Product' : 'Save Changes',
                    ),
            ),

            if (widget.existing != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _delete,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.error),
                  foregroundColor: AppTheme.error,
                ),
                child: const Text('Delete Product'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_pickedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: SizedBox.expand(
          child: kIsWeb
              ? Image.network(_pickedImage!.path, fit: BoxFit.cover)
              : Image.file(File(_pickedImage!.path), fit: BoxFit.cover),
        ),
      );
    }

    if (_existingImageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _existingImageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tap to change',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_a_photo_rounded,
            color: AppTheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Add product image',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Camera or gallery',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.categoryOptions.map((cat) {
        final isSelected = _selectedCategory == cat;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withOpacity(0.12)
                  : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              cat,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontFamily: 'Poppins',
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 18),
      ),
    );
  }
}

class _ImageOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageOptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String vendorId;
  final VoidCallback onEdit;

  const _ProductTile({
    required this.data,
    required this.docId,
    required this.vendorId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = data['isAvailable'] ?? true;
    final imageUrl = data['imageUrl'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imageFallback(),
                  )
                : _imageFallback(),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? '',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '₦${(data['price'] as num).toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if ((data['category'] ?? '').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          data['category'],
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          Column(
            children: [
              Switch(
                value: isAvailable,
                onChanged: (v) async {
                  await FirebaseFirestore.instance
                      .collection('getit_products')
                      .doc(docId)
                      .update({'isAvailable': v});
                },
                activeColor: AppTheme.primary,
              ),
              GestureDetector(
                onTap: onEdit,
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      width: 52,
      height: 52,
      color: AppTheme.surfaceLight,
      child: const Icon(
        Icons.fastfood_rounded,
        color: AppTheme.textSecondary,
        size: 26,
      ),
    );
  }
}
