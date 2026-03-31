// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

class BrowserGeoPoint {
  final double latitude;
  final double longitude;

  const BrowserGeoPoint({required this.latitude, required this.longitude});
}

Future<BrowserGeoPoint?> getCurrentBrowserPosition({
  Duration timeout = const Duration(seconds: 12),
}) async {
  final geolocation = html.window.navigator.geolocation;

  try {
    final position = await geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: timeout,
      maximumAge: Duration.zero,
    );
    final coords = position.coords;
    final lat = coords?.latitude;
    final lng = coords?.longitude;
    if (lat == null || lng == null) return null;
    return BrowserGeoPoint(latitude: lat.toDouble(), longitude: lng.toDouble());
  } catch (_) {
    return null;
  }
}
