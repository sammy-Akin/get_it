import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../screens/map/map_service.dart';
import '../core/theme.dart';

class LocationSheet extends StatefulWidget {
  final String currentLabel;
  final MapService mapService;
  final Function(String address, LatLng latLng) onLocationSelected;
  final String title;
  final String subtitle;

  const LocationSheet({
    super.key,
    required this.currentLabel,
    required this.mapService,
    required this.onLocationSelected,
    this.title = 'Deliver to',
    this.subtitle = 'Enter your estate or area to find nearby stores',
  });

  @override
  State<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<LocationSheet> {
  final _controller = TextEditingController();
  bool _isSearching = false;
  String? _error;
  Timer? _debounce;
  List<Map<String, String>> _acSuggestions = [];

  static const String _autocompleteUrl =
      'https://placesautocomplete-3vduh2j6xq-uc.a.run.app';
  static const String _placeDetailsUrl =
      'https://placedetails-3vduh2j6xq-uc.a.run.app';

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
      final url = '$_autocompleteUrl?input=$encoded';
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
    } catch (e) {
      debugPrint('Autocomplete error: $e');
    }
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
      final url = '$_placeDetailsUrl?place_id=$placeId';
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
    } catch (e) {
      debugPrint('Place details error: $e');
    }

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

          // Dynamic title and subtitle
          Text(
            widget.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: const TextStyle(
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

          // Autocomplete suggestions
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

          // Error
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

          // Popular areas
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
