import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MapService {
  static const LatLng _defaultLocation = LatLng(6.5244, 3.3792); // Lagos

  // Firebase Cloud Function URLs
  static const String _baseUrl =
      'https://us-central1-getit-db879.cloudfunctions.net';

  Future<LatLng> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _defaultLocation;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return _defaultLocation;
      }
      if (permission == LocationPermission.deniedForever)
        return _defaultLocation;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return _defaultLocation;
    }
  }

  Future<LatLng?> geocodeAddress(String address) async {
    try {
      final query = Uri.encodeComponent('$address, Nigeria');
      final url = '$_baseUrl/geocode?address=$query';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          return LatLng(loc['lat'], loc['lng']);
        }
      }
      return null;
    } catch (e) {
      print('GEOCODE ERROR: $e');
      return null;
    }
  }

  Future<String?> reverseGeocode(LatLng position) async {
    try {
      if (kIsWeb) {
        return await _reverseGeocodeWeb(position);
      } else {
        return await _reverseGeocodeMobile(position);
      }
    } catch (_) {
      return null;
    }
  }

  Future<String?> _reverseGeocodeWeb(LatLng position) async {
    final url =
        '$_baseUrl/reverseGeocode?latlng=${position.latitude},${position.longitude}';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        return data['results'][0]['formatted_address'];
      }
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
      return '${p.street}, ${p.subLocality}, ${p.locality}';
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
