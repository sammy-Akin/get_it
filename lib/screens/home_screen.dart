import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme.dart';
import '../../models/product_model.dart';
import '../../models/shop_model.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/shop_card.dart';
import '../../screens/map/map_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';
  int _currentNavIndex = 0;

  // Location state
  String _locationLabel = 'Detecting location...';
  LatLng? _userLatLng;
  bool _locationLoading = true;

  final _mapService = MapService();

  final List<Map<String, dynamic>> _categories = [
    {'label': 'All', 'icon': Icons.grid_view_rounded},
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
    _initLocation().then((_) => _loadNearbyShopIds());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      // First check if user has a saved location in Firestore
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final doc = await _firestore.collection('getit_users').doc(uid).get();
          final data = doc.data();
          if (data != null &&
              data['deliveryLat'] != null &&
              data['deliveryLng'] != null) {
            if (mounted) {
              setState(() {
                _userLatLng = LatLng(
                  (data['deliveryLat'] as num).toDouble(),
                  (data['deliveryLng'] as num).toDouble(),
                );
                _locationLabel = data['deliveryAddress'] ?? 'My Location';
                _locationLoading = false;
              });
            }
            return;
          }
        } catch (_) {}
      }

      // Fall back to GPS — don't reverse geocode on web to avoid errors
      try {
        final loc = await _mapService.getCurrentLocation();
        if (mounted) {
          setState(() {
            _userLatLng = loc;
            _locationLabel = 'Set your location';
            _locationLoading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _locationLabel = 'Set your location';
            _locationLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationLabel = 'Set your location';
          _locationLoading = false;
        });
      }
    }
  }

  String _shortenAddress(String address) {
    // Show only first 2 parts of address for header
    final parts = address.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return address;
  }

  String get _firstName {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? '';
    return name.isNotEmpty ? name.split(' ').first : 'there';
  }

  // Cache nearby shop IDs for product filtering
  List<String> _nearbyShopIds = [];

  Future<void> _loadNearbyShopIds() async {
    final shops = await _getNearbyShops();
    if (mounted) {
      setState(() => _nearbyShopIds = shops.map((s) => s.id).toList());
    }
  }

  Query<Map<String, dynamic>> get _productsQuery {
    Query<Map<String, dynamic>> query = _firestore
        .collection('getit_products')
        .where('isAvailable', isEqualTo: true);
    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }
    return query;
  }

  void _onNavTap(int index) {
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        break;
      case 1:
        context.push('/search');
        break;
      case 2:
        context.push('/cart');
        break;
      case 3:
        context.push('/orders');
        break;
      case 4:
        context.push('/profile');
        break;
    }
  }

  void _openLocationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _LocationSheet(
        currentLabel: _locationLabel,
        mapService: _mapService,
        onLocationSelected: (address, latLng) async {
          setState(() {
            _locationLabel = _shortenAddress(address);
            _userLatLng = latLng;
            _nearbyShopIds = []; // reset while reloading
          });
          _loadNearbyShopIds();
          // Save to Firestore
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            await _firestore.collection('getit_users').doc(uid).update({
              'deliveryAddress': address,
              'deliveryLat': latLng.latitude,
              'deliveryLng': latLng.longitude,
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildCategories()),
            if (_searchQuery.isEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader('Featured Products', null),
              ),
              SliverToBoxAdapter(child: _buildFeaturedProducts()),
            ],
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                _searchQuery.isNotEmpty
                    ? 'Search Results'
                    : _selectedCategory == 'All'
                    ? 'All Products'
                    : _selectedCategory,
                null,
              ),
            ),
            SliverToBoxAdapter(child: _buildProductsGrid()),
            if (_searchQuery.isEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader('Stores Near You', null),
              ),
              SliverToBoxAdapter(child: _buildNearbyShops()),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clickable location row
                GestureDetector(
                  onTap: _openLocationSheet,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppTheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: _locationLoading
                            ? const SizedBox(
                                width: 100,
                                height: 12,
                                child: LinearProgressIndicator(
                                  color: AppTheme.primary,
                                  backgroundColor: AppTheme.surfaceLight,
                                ),
                              )
                            : Text(
                                _locationLabel,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontFamily: 'Poppins',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hello, $_firstName 👋',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppTheme.textPrimary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppTheme.primary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.divider, width: 1)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentNavIndex,
            onTap: _onNavTap,
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppTheme.primary,
            unselectedItemColor: AppTheme.textSecondary,
            selectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontFamily: 'Poppins',
            ),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.search_outlined),
                activeIcon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_cart_outlined),
                    if (cart.totalItems > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${cart.totalItems}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                activeIcon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_cart_rounded),
                    if (cart.totalItems > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${cart.totalItems}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Cart',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long_rounded),
                label: 'Orders',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontFamily: 'Poppins',
        ),
        decoration: InputDecoration(
          hintText: 'Search products or stores...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.textSecondary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat['label'];
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat['label']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    cat['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat['label'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? seeAllRoute) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          if (seeAllRoute != null)
            GestureDetector(
              onTap: () => context.push(seeAllRoute),
              child: const Text(
                'See all',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedProducts() {
    // Show shimmer while loading shop IDs
    if (_locationLoading || (_userLatLng != null && _nearbyShopIds.isEmpty)) {
      return _buildHorizontalShimmer(height: 160);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('getit_products')
          .where('isAvailable', isEqualTo: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildHorizontalShimmer(height: 160);
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No products yet');
        }

        var products = snapshot.data!.docs
            .map(
              (doc) => ProductModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .toList();

        // Filter by nearby shops
        if (_nearbyShopIds.isNotEmpty) {
          products = products
              .where((p) => _nearbyShopIds.contains(p.shopId))
              .toList();
        }

        if (products.isEmpty) {
          return _buildEmptyState('No products near you yet');
        }

        // Limit to 6 for featured
        final featured = products.take(6).toList();

        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: featured.length,
            itemBuilder: (context, index) => SizedBox(
              width: 110,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ProductCard(
                  product: featured[index],
                  onTap: () => _showQuickAddPopup(featured[index]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsGrid() {
    // Show shimmer while loading shop IDs
    if (_locationLoading || (_userLatLng != null && _nearbyShopIds.isEmpty)) {
      return _buildGridShimmer();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _productsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildGridShimmer();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No products in this category yet');
        }

        var products = snapshot.data!.docs
            .map(
              (doc) => ProductModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .toList();

        // Filter by nearby shops
        if (_nearbyShopIds.isNotEmpty) {
          products = products
              .where((p) => _nearbyShopIds.contains(p.shopId))
              .toList();
        }

        // Search filter
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          products = products
              .where(
                (p) =>
                    p.name.toLowerCase().contains(q) ||
                    p.category.toLowerCase().contains(q) ||
                    p.shopName.toLowerCase().contains(q),
              )
              .toList();
        }

        if (products.isEmpty) {
          return _searchQuery.isNotEmpty
              ? _buildEmptyState('No results for "$_searchQuery"')
              : _buildEmptyState('No products near $_locationLabel yet');
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.65,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => ProductCard(
            product: products[index],
            onTap: () => _showQuickAddPopup(products[index]),
          ),
        );
      },
    );
  }

  Widget _buildNearbyShops() {
    // If location not yet detected, show shimmer
    if (_locationLoading) {
      return _buildHorizontalShimmer(height: 180);
    }

    return FutureBuilder<List<ShopModel>>(
      future: _getNearbyShops(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildHorizontalShimmer(height: 180);
        }

        final shops = snapshot.data ?? [];

        if (shops.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.store_outlined,
                    color: AppTheme.textSecondary,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No stores within 10 min walk',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No vendors near $_locationLabel yet. We\'re growing!',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _openLocationSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        'Change Location',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${shops.length} store${shops.length == 1 ? '' : 's'} near $_locationLabel',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: shops.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ShopCard(shop: shops[index]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<ShopModel>> _getNearbyShops() async {
    final snap = await _firestore
        .collection('getit_vendors')
        .where('isOpen', isEqualTo: true)
        .get();

    final allShops = snap.docs
        .map((doc) => ShopModel.fromMap(doc.data(), doc.id))
        .toList();

    if (allShops.isEmpty) return [];

    final shopsWithCoords = allShops
        .where((s) => s.latitude != 0 && s.longitude != 0)
        .toList();
    final shopsWithoutCoords = allShops
        .where((s) => s.latitude == 0 && s.longitude == 0)
        .toList();

    List<ShopModel> result = [];

    if (_userLatLng != null && shopsWithCoords.isNotEmpty) {
      final nearbyByCoords = shopsWithCoords.where((shop) {
        final distance = Geolocator.distanceBetween(
          _userLatLng!.latitude,
          _userLatLng!.longitude,
          shop.latitude,
          shop.longitude,
        );
        return distance <= 800; // ~10 min walk (80m/min)
      }).toList();

      nearbyByCoords.sort((a, b) {
        final da = Geolocator.distanceBetween(
          _userLatLng!.latitude,
          _userLatLng!.longitude,
          a.latitude,
          a.longitude,
        );
        final db = Geolocator.distanceBetween(
          _userLatLng!.latitude,
          _userLatLng!.longitude,
          b.latitude,
          b.longitude,
        );
        return da.compareTo(db);
      });
      result.addAll(nearbyByCoords);
    }

    // Text-based matching for shops without coordinates
    if (_locationLabel.isNotEmpty &&
        _locationLabel != 'Set your location' &&
        _locationLabel != 'Detecting location...') {
      final locationKeywords = _locationLabel
          .toLowerCase()
          .replaceAll(',', ' ')
          .split(' ')
          .where((w) => w.length > 3)
          .toList();

      final textMatched = shopsWithoutCoords.where((shop) {
        final shopLoc = shop.address.toLowerCase();
        final shopName = shop.name.toLowerCase();
        return locationKeywords.any(
          (keyword) => shopLoc.contains(keyword) || shopName.contains(keyword),
        );
      }).toList();

      final existingIds = result.map((s) => s.id).toSet();
      result.addAll(textMatched.where((s) => !existingIds.contains(s.id)));
    }

    // If no results and no user location, show all shops
    if (result.isEmpty && _userLatLng == null) return allShops;

    return result;
  }

  void _showQuickAddPopup(ProductModel product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _QuickAddSheet(product: product),
    );
  }

  Widget _buildHorizontalShimmer({required double height}) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          width: 150,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildGridShimmer() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.65,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.inbox_outlined,
              color: AppTheme.textSecondary,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Location Sheet ───────────────────────────────────────────────────────────

class _LocationSheet extends StatefulWidget {
  final String currentLabel;
  final MapService mapService;
  final Function(String address, LatLng latLng) onLocationSelected;

  const _LocationSheet({
    required this.currentLabel,
    required this.mapService,
    required this.onLocationSelected,
  });

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final _controller = TextEditingController();
  bool _isSearching = false;
  String? _error;
  Timer? _debounce;
  List<Map<String, String>> _acSuggestions = [];

  static const String _apiKey = 'AIzaSyBKBWfOo6QXex6Qfifks5CxGmIHYffAQjg';

  final List<String> _popularAreas = [
    'Gowon Estate, Lagos',
    'Ikeja, Lagos',
    'Lekki Phase 1, Lagos',
    'Victoria Island, Lagos',
    'Yaba, Lagos',
    'Surulere, Lagos',
    'Ikorodu, Lagos',
    'Ajah, Lagos',
    'Festac Town, Lagos',
    'Magodo, Lagos',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final text = _controller.text;
      if (text.length > 2) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 350), () {
          _fetchSuggestions(text);
        });
      } else {
        if (mounted) setState(() => _acSuggestions = []);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String input) async {
    try {
      final encoded = Uri.encodeComponent('$input Nigeria');
      final url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=$encoded&key=$_apiKey&components=country:ng&language=en';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          setState(() {
            _acSuggestions = predictions
                .take(5)
                .map(
                  (p) => {
                    'description': p['description'] as String,
                    'place_id': p['place_id'] as String,
                  },
                )
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _selectSuggestion(Map<String, String> s) async {
    final description = s['description']!;
    final placeId = s['place_id']!;
    setState(() {
      _controller.text = description;
      _acSuggestions = [];
      _isSearching = true;
      _error = null;
    });

    try {
      final url =
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId&fields=geometry&key=$_apiKey';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK') {
          final loc = data['result']['geometry']['location'];
          final latLng = LatLng(
            (loc['lat'] as num).toDouble(),
            (loc['lng'] as num).toDouble(),
          );
          if (mounted) setState(() => _isSearching = false);
          widget.onLocationSelected(description, latLng);
          if (mounted) Navigator.pop(context);
          return;
        }
      }
    } catch (_) {}

    // Fallback geocode
    final latLng = await widget.mapService.geocodeAddress(description);
    if (!mounted) return;
    setState(() => _isSearching = false);
    if (latLng != null) {
      widget.onLocationSelected(description, latLng);
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _error = 'Location not found. Try being more specific.');
    }
  }

  Future<void> _searchAndConfirm(String address) async {
    if (address.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _error = null;
      _acSuggestions = [];
    });

    final latLng = await widget.mapService.geocodeAddress(address.trim());
    if (!mounted) return;
    setState(() => _isSearching = false);

    if (latLng == null) {
      setState(() => _error = 'Location not found. Try being more specific.');
      return;
    }
    widget.onLocationSelected(address.trim(), latLng);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isSearching = true;
      _error = null;
      _acSuggestions = [];
    });

    try {
      final loc = await widget.mapService.getCurrentLocation();
      String address = 'Current Location';
      try {
        final resolved = await widget.mapService.reverseGeocode(loc);
        if (resolved != null) address = resolved;
      } catch (_) {}

      if (!mounted) return;
      setState(() => _isSearching = false);
      widget.onLocationSelected(address, loc);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _error = 'Could not detect your location. Try typing it instead.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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

          const Text(
            'Deliver to',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your estate or area to find nearby stores',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),

          const SizedBox(height: 16),

          // Search field
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontFamily: 'Poppins',
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 412 Road, Gowon Estate',
                hintStyle: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontFamily: 'Poppins',
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.textSecondary,
                ),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        ),
                      )
                    : _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _acSuggestions = []);
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: _searchAndConfirm,
              textInputAction: TextInputAction.search,
            ),
          ),

          // Autocomplete suggestions — inline like Chowdeck
          if (_acSuggestions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: _acSuggestions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final isLast = i == _acSuggestions.length - 1;
                  return Column(
                    children: [
                      InkWell(
                        onTap: () => _selectSuggestion(s),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: AppTheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  s['description']!,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontFamily: 'Poppins',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          color: AppTheme.divider,
                          indent: 46,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppTheme.error,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppTheme.error,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Use current location
          GestureDetector(
            onTap: _useCurrentLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Use my current location',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          'Automatically detect where you are',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Only show popular areas when not searching
          if (_acSuggestions.isEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Popular areas',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _popularAreas.map((area) {
                return GestureDetector(
                  onTap: () => _searchAndConfirm(area),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: AppTheme.textSecondary,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          area.split(',')[0],
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
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

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Quick Add Sheet ──────────────────────────────────────────────────────────

class _QuickAddSheet extends StatefulWidget {
  final ProductModel product;
  const _QuickAddSheet({required this.product});

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final currentQty = cart.getQuantity(widget.product.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 90,
                  height: 90,
                  child: widget.product.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: AppTheme.surfaceLight),
                        )
                      : Container(
                          color: AppTheme.surfaceLight,
                          child: const Icon(
                            Icons.image_outlined,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.product.shopName,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₦${widget.product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.product.stockQty} in stock',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                      icon: const Icon(Icons.remove_rounded),
                      color: _qty > 1
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                    Text(
                      '$_qty',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    IconButton(
                      onPressed: _qty < widget.product.stockQty
                          ? () => setState(() => _qty++)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                      color: _qty < widget.product.stockQty
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.product.stockQty == 0
                      ? null
                      : () {
                          for (int i = 0; i < _qty; i++)
                            cart.addItem(widget.product);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${widget.product.name} added to cart',
                                style: const TextStyle(fontFamily: 'Poppins'),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                  child: Text(
                    currentQty > 0
                        ? 'Update Cart • ₦${(widget.product.price * _qty).toStringAsFixed(0)}'
                        : 'Add to Cart • ₦${(widget.product.price * _qty).toStringAsFixed(0)}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
