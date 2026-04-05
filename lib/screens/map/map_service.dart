import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MapService {
  static const LatLng _defaultLocation = LatLng(6.5244, 3.3792); // Lagos

  static const String _geocodeUrl = 'https://geocode-3vduh2j6xq-uc.a.run.app';
  static const String _reverseGeocodeUrl =
      'https://reversegeocode-3vduh2j6xq-uc.a.run.app';

  Future<LatLng> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services disabled');
        return _defaultLocation;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return _defaultLocation;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied');
        return _defaultLocation;
      }

      final position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Location timeout'),
          );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('getCurrentLocation error: $e');
      return _defaultLocation;
    }
  }

  Future<LatLng?> geocodeAddress(String address) async {
    try {
      final query = Uri.encodeComponent('$address, Nigeria');
      final url = '$_geocodeUrl?address=$query';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          return LatLng(
            (loc['lat'] as num).toDouble(),
            (loc['lng'] as num).toDouble(),
          );
        }
        debugPrint('Geocode bad status: ${data['status']}');
      } else {
        debugPrint('Geocode HTTP ${response.statusCode}: ${response.body}');
      }
      return null;
    } catch (e) {
      debugPrint('geocodeAddress error: $e');
      return null;
    }
  }

  Future<String?> reverseGeocode(LatLng position) async {
    // Always try Cloud Function first — works on web, Android and iOS
    try {
      final result = await _reverseGeocodeCloud(position);
      if (result != null) return result;
    } catch (e) {
      debugPrint('Cloud reverse geocode failed: $e');
    }

    // Mobile-only fallback
    if (!kIsWeb) {
      try {
        return await _reverseGeocodeMobile(position);
      } catch (e) {
        debugPrint('Mobile reverse geocode failed: $e');
      }
    }

    return null;
  }

  Future<String?> _reverseGeocodeCloud(LatLng position) async {
    final url =
        '$_reverseGeocodeUrl?latlng=${position.latitude},${position.longitude}';
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        return data['results'][0]['formatted_address'] as String;
      }
      debugPrint('Reverse geocode bad status: ${data['status']}');
    } else {
      debugPrint(
        'Reverse geocode HTTP ${response.statusCode}: ${response.body}',
      );
    }
    return null;
  }

  Future<String?> _reverseGeocodeMobile(LatLng position) async {
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isNotEmpty) {
      final p = placemarks.first;
      final parts = [
        p.street,
        p.subLocality,
        p.locality,
      ].where((s) => s != null && s.isNotEmpty).toList();
      return parts.join(', ');
    }
    return null;
  }

  double distanceInKm(LatLng from, LatLng to) {
    final meters = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    return meters / 1000;
  }

  String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)}m away';
    return '${km.toStringAsFixed(1)}km away';
  }
}
