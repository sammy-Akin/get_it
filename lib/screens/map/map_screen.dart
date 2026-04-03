import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/shop_model.dart';
import 'map_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapService = MapService();
  final Completer<GoogleMapController> _mapController = Completer();

  LatLng _userLocation = const LatLng(6.5244, 3.3792);
  List<ShopModel> _shops = [];
  Set<Marker> _markers = {};
  ShopModel? _selectedShop;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final location = await _mapService.getCurrentLocation();
    setState(() => _userLocation = location);
    await _loadShops();
  }

  Future<void> _loadShops() async {
    final snap = await FirebaseFirestore.instance
        .collection('getit_vendors')
        .where('isOpen', isEqualTo: true)
        .get();

    final shops = snap.docs
        .map((doc) => ShopModel.fromMap(doc.data(), doc.id))
        .where((s) => s.latitude != 0 && s.longitude != 0)
        .toList();

    shops.sort((a, b) {
      final da = _mapService.distanceInKm(
        _userLocation,
        LatLng(a.latitude, a.longitude),
      );
      final db = _mapService.distanceInKm(
        _userLocation,
        LatLng(b.latitude, b.longitude),
      );
      return da.compareTo(db);
    });

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('user'),
        position: _userLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You are here'),
      ),
      ...shops.map(
        (shop) => Marker(
          markerId: MarkerId(shop.id),
          position: LatLng(shop.latitude, shop.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: shop.name,
            snippet: shop.category.isNotEmpty ? shop.category : null,
          ),
          onTap: () => setState(() => _selectedShop = shop),
        ),
      ),
    };

    setState(() {
      _shops = shops;
      _markers = markers;
      _isLoading = false;
    });

    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(_userLocation, 14));
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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Nearby Stores',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.my_location_rounded,
              color: AppTheme.primary,
            ),
            onPressed: _goToUserLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userLocation,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController.complete(controller);
              controller.setMapStyle(_mapStyle);
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onTap: (_) => setState(() => _selectedShop = null),
          ),

          if (_isLoading)
            Container(
              color: AppTheme.background.withOpacity(0.8),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            ),

          if (!_isLoading)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    '${_shops.length} shops near you',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),

          if (_selectedShop != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: _buildShopCard(_selectedShop!),
            ),

          Positioned(bottom: 0, left: 0, right: 0, child: _buildShopsList()),
        ],
      ),
    );
  }

  Widget _buildShopCard(ShopModel shop) {
    final distance = _mapService.distanceInKm(
      _userLocation,
      LatLng(shop.latitude, shop.longitude),
    );
    return GestureDetector(
      onTap: () => context.push('/shop/${shop.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: shop.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(shop.imageUrl, fit: BoxFit.cover),
                    )
                  : const Icon(
                      Icons.storefront_rounded,
                      color: AppTheme.primary,
                      size: 26,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  if (shop.category.isNotEmpty)
                    Text(
                      shop.category,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _mapService.formatDistance(distance),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: shop.isOpen
                        ? AppTheme.success.withOpacity(0.15)
                        : AppTheme.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    shop.isOpen ? 'Open' : 'Closed',
                    style: TextStyle(
                      color: shop.isOpen ? AppTheme.success : AppTheme.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.textSecondary,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopsList() {
    if (_shops.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _shops.length,
        itemBuilder: (context, index) {
          final shop = _shops[index];
          final distance = _mapService.distanceInKm(
            _userLocation,
            LatLng(shop.latitude, shop.longitude),
          );
          final isSelected = _selectedShop?.id == shop.id;
          return GestureDetector(
            onTap: () async {
              setState(() => _selectedShop = shop);
              final controller = await _mapController.future;
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(shop.latitude, shop.longitude),
                  16,
                ),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.1)
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    shop.name,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _mapService.formatDistance(distance),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
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

  Future<void> _goToUserLocation() async {
    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(_userLocation, 14));
  }

  static const String _mapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1a1a2e"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#a0a0a0"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a1a2e"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2a2a3e"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3a3a5e"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0f0f1e"}]},
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]}
]
''';
}
