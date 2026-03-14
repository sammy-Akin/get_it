import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/product_model.dart';
import '../../models/shop_model.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/shop_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;

  String _query = '';
  bool _hasSearched = false;

  List<ProductModel> _productResults = [];
  List<ShopModel> _shopResults = [];
  bool _isLoading = false;

  // Quick categories for shortcut chips
  final List<Map<String, dynamic>> _categories = [
    {'label': 'Groceries', 'icon': Icons.shopping_basket_rounded},
    {'label': 'Snacks', 'icon': Icons.fastfood_rounded},
    {'label': 'Food', 'icon': Icons.restaurant_rounded},
    {'label': 'Drinks', 'icon': Icons.local_drink_rounded},
    {'label': 'Toiletries', 'icon': Icons.soap_rounded},
    {'label': 'Household', 'icon': Icons.home_rounded},
    {'label': 'Other', 'icon': Icons.category_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _query = '';
        _hasSearched = false;
        _productResults = [];
        _shopResults = [];
      });
      return;
    }

    setState(() {
      _query = query.trim().toLowerCase();
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // Search products
      final productSnap = await FirebaseFirestore.instance
          .collection('getit_products')
          .where('isAvailable', isEqualTo: true)
          .get();

      final products = productSnap.docs
          .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
          .where(
            (p) =>
                p.name.toLowerCase().contains(_query) ||
                p.category.toLowerCase().contains(_query) ||
                p.shopName.toLowerCase().contains(_query),
          )
          .toList();

      // Search shops
      final shopSnap = await FirebaseFirestore.instance
          .collection('getit_vendors')
          .where('isOpen', isEqualTo: true)
          .get();

      final shops = shopSnap.docs
          .map((doc) => ShopModel.fromMap(doc.data(), doc.id))
          .where(
            (s) =>
                s.name.toLowerCase().contains(_query) ||
                s.category.toLowerCase().contains(_query),
          )
          .toList();

      setState(() {
        _productResults = products;
        _shopResults = shops;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => context.go('/home'),
        ),
        titleSpacing: 0,
        title: _buildSearchBar(),
      ),
      body: _hasSearched ? _buildResults() : _buildDiscover(),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontFamily: 'Poppins',
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Search products or shops...',
            hintStyle: const TextStyle(
              color: AppTheme.textSecondary,
              fontFamily: 'Poppins',
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _search('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (value) {
            setState(() {}); // refresh suffix icon
            if (value.length >= 2) _search(value);
            if (value.isEmpty) _search('');
          },
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
        ),
      ),
    );
  }

  Widget _buildDiscover() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const Text(
          'Browse Categories',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 14),

        // Category chips grid
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.4,
          children: _categories.map((cat) {
            return GestureDetector(
              onTap: () {
                _searchController.text = cat['label'];
                _search(cat['label']);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      color: AppTheme.primary,
                      size: 26,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat['label'],
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        const Text(
          'Popular Searches',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 14),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              [
                'Rice',
                'Noodles',
                'Water',
                'Biscuits',
                'Bread',
                'Eggs',
                'Juice',
                'Soap',
              ].map((term) {
                return GestureDetector(
                  onTap: () {
                    _searchController.text = term;
                    _search(term);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          color: AppTheme.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          term,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    final totalResults = _productResults.length + _shopResults.length;

    if (totalResults == 0) {
      return _buildEmptyResults();
    }

    return Column(
      children: [
        // Tabs
        Container(
          color: AppTheme.background,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
            ),
            tabs: [
              Tab(text: 'Products (${_productResults.length})'),
              Tab(text: 'Shops (${_shopResults.length})'),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildProductResults(), _buildShopResults()],
          ),
        ),
      ],
    );
  }

  Widget _buildProductResults() {
    if (_productResults.isEmpty) {
      return _buildEmptyTab('No products found', Icons.inventory_2_outlined);
    }

    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: _productResults.length,
          itemBuilder: (context, index) {
            final product = _productResults[index];
            return ProductCard(
              product: product,
              onTap: () => _showQuickAdd(context, product, cart),
            );
          },
        );
      },
    );
  }

  Widget _buildShopResults() {
    if (_shopResults.isEmpty) {
      return _buildEmptyTab('No shops found', Icons.storefront_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _shopResults.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ShopCard(shop: _shopResults[index]),
        );
      },
    );
  }

  Widget _buildEmptyResults() {
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
              Icons.search_off_rounded,
              color: AppTheme.textSecondary,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No results for "$_query"',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try a different search term',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTab(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickAdd(
    BuildContext context,
    ProductModel product,
    CartProvider cart,
  ) {
    int qty = 1;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: product.imageUrl.isNotEmpty
                        ? Image.network(
                            product.imageUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildImageFallback(),
                          )
                        : _buildImageFallback(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          product.shopName,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          '₦${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _qtyButton(
                    Icons.remove_rounded,
                    () => setSheetState(() {
                      if (qty > 1) qty--;
                    }),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '$qty',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  _qtyButton(
                    Icons.add_rounded,
                    () => setSheetState(() => qty++),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  for (int i = 0; i < qty; i++) {
                    cart.addItem(product);
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} added to cart'),
                      backgroundColor: AppTheme.success,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(
                  'Add to Cart — ₦${(product.price * qty).toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 20),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      width: 64,
      height: 64,
      color: AppTheme.surfaceLight,
      child: const Icon(
        Icons.image_outlined,
        color: AppTheme.textSecondary,
        size: 28,
      ),
    );
  }
}
