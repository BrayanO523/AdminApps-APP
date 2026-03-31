class BrowserGeoPoint {
  final double latitude;
  final double longitude;

  const BrowserGeoPoint({required this.latitude, required this.longitude});
}

Future<BrowserGeoPoint?> getCurrentBrowserPosition({
  Duration timeout = const Duration(seconds: 12),
}) async {
  return null;
}
