import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import 'map_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.initialAddress,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapService = MapService();
  final _addressController = TextEditingController();
  final Completer<GoogleMapController> _mapController = Completer();

  LatLng _selectedLocation = const LatLng(6.5244, 3.3792);
  String? _resolvedAddress;
  bool _isSearching = false;
  Set<Marker> _markers = {};

  // Autocomplete
  List<Map<String, String>> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounce;

  static const String _baseUrl =
      'https://us-central1-getit-db879.cloudfunctions.net';

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
      _updateMarker(_selectedLocation);
    }
    if (widget.initialAddress != null) {
      _addressController.text = widget.initialAddress!;
      _resolvedAddress = widget.initialAddress;
    }
    _initLocation();

    _addressController.addListener(() {
      final text = _addressController.text;
      if (text.length > 2) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 400), () {
          _fetchSuggestions(text);
        });
      } else {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
    });
  }

  Future<void> _initLocation() async {
    if (widget.initialLocation == null) {
      final loc = await _mapService.getCurrentLocation();
      if (mounted) setState(() => _selectedLocation = loc);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String input) async {
    try {
      final encoded = Uri.encodeComponent('$input Nigeria');
      final url = '$_baseUrl/placesAutocomplete?input=$encoded';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          setState(() {
            _suggestions = predictions
                .map(
                  (p) => {
                    'description': p['description'] as String,
                    'place_id': p['place_id'] as String,
                  },
                )
                .toList();
            _showSuggestions = _suggestions.isNotEmpty;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _selectSuggestion(Map<String, String> suggestion) async {
    final description = suggestion['description']!;
    final placeId = suggestion['place_id']!;

    setState(() {
      _addressController.text = description;
      _showSuggestions = false;
      _suggestions = [];
      _isSearching = true;
    });

    try {
      // Get coordinates from place_id
      final url = '$_baseUrl/placeDetails?place_id=$placeId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final loc = data['result']['geometry']['location'];
          final latLng = LatLng(loc['lat'], loc['lng']);
          _selectedLocation = latLng;
          _resolvedAddress = description;
          _updateMarker(latLng);

          final controller = await _mapController.future;
          controller.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isSearching = false);
  }

  void _updateMarker(LatLng position) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: 'Shop Location',
            snippet: _resolvedAddress,
          ),
        ),
      };
    });
  }

  Future<void> _searchAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;
    setState(() {
      _isSearching = true;
      _showSuggestions = false;
    });

    final location = await _mapService.geocodeAddress(address);
    if (location != null && mounted) {
      _selectedLocation = location;
      _resolvedAddress = address;
      _updateMarker(location);
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(location, 16));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address not found. Try a more specific address.'),
        ),
      );
    }
    if (mounted) setState(() => _isSearching = false);
  }

  Future<void> _onMapTap(LatLng position) async {
    _selectedLocation = position;
    setState(() => _showSuggestions = false);

    final address = await _mapService.reverseGeocode(position);
    if (address != null && mounted) {
      _addressController.text = address;
      _resolvedAddress = address;
    }
    _updateMarker(position);
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Set Shop Location',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
                controller.setMapStyle(_mapStyle);
              }
            },
            markers: _markers,
            onTap: _onMapTap,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Search bar + autocomplete
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _addressController,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontFamily: 'Poppins',
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your shop address or estate...',
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
                          : IconButton(
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                color: AppTheme.primary,
                              ),
                              onPressed: _searchAddress,
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: (_) => _searchAddress(),
                    textInputAction: TextInputAction.search,
                  ),
                ),

                // Autocomplete suggestions
                if (_showSuggestions && _suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      children: _suggestions.take(5).map((s) {
                        return InkWell(
                          onTap: () => _selectSuggestion(s),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: AppTheme.textSecondary,
                                  size: 16,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    s['description']!,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      fontFamily: 'Poppins',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),

          // Tip
          if (_markers.isEmpty)
            Positioned(
              top: 88,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Search your address or tap on the map',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ),

          // Confirm button
          if (_markers.isNotEmpty)
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  if (_resolvedAddress != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppTheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _resolvedAddress!,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'address':
                            _resolvedAddress ?? _addressController.text.trim(),
                        'latitude': _selectedLocation.latitude,
                        'longitude': _selectedLocation.longitude,
                      });
                    },
                    child: const Text('Confirm Location'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
