import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/core/theme.dart';
import 'package:get_it/models/shop_model.dart';
import 'package:get_it/screens/map/map_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

class MapPreviewWidget extends StatefulWidget {
  const MapPreviewWidget({super.key});

  @override
  State<MapPreviewWidget> createState() => _MapPreviewWidgetState();
}

class _MapPreviewWidgetState extends State<MapPreviewWidget> {
  final _mapService = MapService();
  final Completer<GoogleMapController> _mapController = Completer();

  LatLng _userLocation = const LatLng(6.5244, 3.3792);
  Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _locationDenied = false;
  int _shopCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Request location permission explicitly
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationDenied = true);
      await _loadShopMarkers();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      setState(() => _locationDenied = true);
      await _loadShopMarkers();
      return;
    }

    // Permission granted — get real location
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(
          () => _userLocation = LatLng(position.latitude, position.longitude),
        );
      }
    } catch (_) {}

    await _loadShopMarkers();
  }

  Future<void> _loadShopMarkers() async {
    final snap = await FirebaseFirestore.instance
        .collection('getit_vendors')
        .where('isOpen', isEqualTo: true)
        .get();

    final shops = snap.docs
        .map((doc) => ShopModel.fromMap(doc.data(), doc.id))
        .where((s) => s.latitude != 0 && s.longitude != 0)
        .toList();

    // Sort by distance from user
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
          infoWindow: InfoWindow(title: shop.name),
        ),
      ),
    };

    if (mounted) {
      setState(() {
        _markers = markers;
        _shopCount = shops.length;
        _isLoading = false;
      });

      // Animate map to user location
      if (_mapController.isCompleted) {
        final controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(_userLocation, 13));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/map'),
      child: Container(
        height: 180,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Map or loading state
              _isLoading
                  ? Container(
                      color: AppTheme.surface,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppTheme.primary),
                            SizedBox(height: 12),
                            Text(
                              'Getting your location...',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontFamily: 'Poppins',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _userLocation,
                        zoom: 13,
                      ),
                      onMapCreated: (controller) async {
                        if (!_mapController.isCompleted) {
                          _mapController.complete(controller);
                          controller.setMapStyle(_mapStyle);
                          await Future.delayed(
                            const Duration(milliseconds: 300),
                          );
                          controller.animateCamera(
                            CameraUpdate.newLatLngZoom(_userLocation, 14),
                          );
                        }
                      },
                      markers: _markers,
                      zoomControlsEnabled: false,
                      scrollGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      myLocationEnabled: !_locationDenied,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      liteModeEnabled: false,
                    ),

              // Location denied banner
              if (_locationDenied && !_isLoading)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.location_off_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Enable location for better results',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom overlay
              if (!_isLoading)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _shopCount > 0
                              ? '$_shopCount shops near you'
                              : 'No shops with location yet',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'View Map',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const String _mapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1a1a2e"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#a0a0a0"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a1a2e"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2a2a3e"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0f0f1e"}]},
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]}
]
''';
}
