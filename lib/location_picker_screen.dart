import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class SelectedLocation {
  const SelectedLocation({
    required this.name,
    required this.point,
    this.placeName = '',
    this.area = '',
    this.isMapPoint = false,
  });
  // Full address retained for existing booking screens.
  final String name;
  final LatLng point;
  final String placeName;
  final String area;
  final bool isMapPoint;
  String get title {
    if (placeName.trim().isNotEmpty) return placeName.trim();
    return name.split(',').first.trim();
  }
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.title = 'Find pickup',
    this.confirmLabel = 'Use this pickup',
  });
  final String title;
  final String confirmLabel;
  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const blue = Color(0xFF2563EB);
  static const navy = Color(0xFF14213D);
  static const muted = Color(0xFF738097);
  static const background = Color(0xFFF5F7FB);
  static const borderColor = Color(0xFFE5EAF2);
  // Shared between picker instances in this app session.
  static final Map<String, List<SelectedLocation>> cache = {};
  static DateTime? lastRequest;
  static bool requestInFlight = false;
  final searchController = TextEditingController();
  final mapController = MapController();
  List<SelectedLocation> results = [];
  SelectedLocation? selectedLocation;
  bool searching = false;
  bool locating = false;
  bool get busy => searching || locating;
  bool mapReady = false;
  String? message;
  @override
  void dispose() {
    searchController.dispose();
    mapController.dispose();
    super.dispose();
  }

  bool validPoint(LatLng point) {
    return point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  String textValue(dynamic value) {
    return value is String ? value.trim() : '';
  }

  String firstValue(Map<dynamic, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = textValue(data[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  SelectedLocation? parsePlace(Map<dynamic, dynamic> item) {
    final fullAddress = textValue(item['display_name']);
    final latitude = double.tryParse(item['lat'].toString());
    final longitude = double.tryParse(item['lon'].toString());
    if (fullAddress.isEmpty || latitude == null || longitude == null) {
      return null;
    }
    final point = LatLng(latitude, longitude);
    if (!validPoint(point)) return null;
    final addressValue = item['address'];
    final address = addressValue is Map
        ? addressValue
        : const <dynamic, dynamic>{};
    final namesValue = item['namedetails'];
    final names = namesValue is Map ? namesValue : const <dynamic, dynamic>{};
    var placeName = firstValue(names, ['name:en', 'name']);
    if (placeName.isEmpty) {
      placeName = textValue(item['name']);
    }
    if (placeName.isEmpty) {
      placeName = fullAddress.split(',').first.trim();
    }
    final locality = firstValue(address, [
      'city',
      'town',
      'village',
      'municipality',
      'hamlet',
    ]);
    final district = firstValue(address, [
      'state_district',
      'county',
      'district',
    ]);
    final province = firstValue(address, ['state', 'region']);
    final areaParts = <String>[];
    final seen = <String>{};
    for (final value in [locality, district, province]) {
      if (value.isNotEmpty && seen.add(value.toLowerCase())) {
        areaParts.add(value);
      }
    }
    // Address fields vary between places; preserve a readable fallback.
    if (areaParts.isEmpty) {
      final parts = fullAddress
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
      areaParts.addAll(parts.skip(1));
    }
    return SelectedLocation(
      name: fullAddress,
      point: point,
      placeName: placeName,
      area: areaParts.join(' • '),
    );
  }

  Future<void> useCurrentLocation() async {
    if (busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      locating = true;
      message = null;
    });
    try {
      if (!kIsWeb) {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (!mounted) return;
        if (!enabled) {
          throw StateError('Turn on device location services and try again.');
        }
        var permission = await Geolocator.checkPermission();
        if (!mounted) return;
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (!mounted) return;
        }
        if (permission == LocationPermission.deniedForever) {
          throw StateError(
            'Location access is blocked. Enable location permission '
            'for TripLanka in your device settings.',
          );
        }
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          throw StateError(
            'Location permission was not granted. '
            'You can still search for a place or tap the map.',
          );
        }
      }
      // On web, this call triggers the browser permission prompt directly.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      if (!validPoint(point)) {
        throw StateError('The device returned an invalid location.');
      }
      final accuracy = position.accuracy;
      final accuracyText = accuracy.isFinite && accuracy >= 0
          ? 'Reported accuracy: about ${accuracy.ceil()} metres. '
          : '';
      setState(() {
        results = [];
        searchController.clear();
        selectedLocation = SelectedLocation(
          name:
              '${point.latitude.toStringAsFixed(6)}, '
              '${point.longitude.toStringAsFixed(6)}',
          point: point,
          placeName: 'Current device location',
          area: '${accuracyText}Check the marker before confirming.',
          isMapPoint: true,
        );
        message =
            'Current location selected. '
            'You can adjust it by tapping the map.';
      });
      if (mapReady) mapController.move(point, 16);
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        message =
            'Getting your location took too long. '
            'Try again, search for a place, or tap the map.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        message = error is StateError
            ? error.message.toString()
            : kIsWeb
            ? 'Could not get your location. Allow location access '
                  'in your browser and check device location settings. '
                  'You can also search or tap the map.'
            : 'Could not get your location. Check device permissions '
                  'and location services, then try again.';
      });
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> searchPlaces() async {
    if (busy) return;
    final query = searchController.text.trim();
    if (query.length < 3) {
      setState(() {
        message = 'Enter at least three characters.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    final cacheKey = query.toLowerCase();
    final cached = cache[cacheKey];
    if (cached != null) {
      showResults(cached);
      return;
    }
    final previous = lastRequest;
    if (requestInFlight ||
        (previous != null &&
            DateTime.now().difference(previous).inMilliseconds < 1100)) {
      setState(() {
        message = 'Please wait a moment before searching again.';
      });
      return;
    }
    setState(() {
      searching = true;
      message = null;
      results = [];
      selectedLocation = null;
    });
    requestInFlight = true;
    lastRequest = DateTime.now();
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'countrycodes': 'lk',
        'limit': '5',
        'accept-language': 'en',
        'addressdetails': '1',
        'namedetails': '1',
      });
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (!kIsWeb)
                'User-Agent':
                    'TripLankaPrototype/1.0 '
                    '(https://github.com/sevi2001/triplanka)',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Search returned ${response.statusCode}');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        throw const FormatException('Invalid search response');
      }
      final places = <SelectedLocation>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final place = parsePlace(item);
        if (place != null) places.add(place);
      }
      final saved = List<SelectedLocation>.unmodifiable(places);
      cache[cacheKey] = saved;
      if (!mounted) return;
      showResults(saved);
    } catch (error) {
      debugPrint('Place search failed: $error');
      if (!mounted) return;
      setState(() {
        message = 'Search failed. Check your connection and try again.';
      });
    } finally {
      requestInFlight = false;
      if (mounted) {
        setState(() => searching = false);
      }
    }
  }

  void showResults(List<SelectedLocation> places) {
    setState(() {
      results = places;
      selectedLocation = null;
      message = places.isEmpty
          ? 'No places found. Include the town or district and try again.'
          : 'Check the town and province before selecting a result.';
    });
  }

  void selectPlace(SelectedLocation place) {
    if (busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      selectedLocation = place;
      message = null;
    });
    if (mapReady) {
      mapController.move(place.point, 16);
    }
  }

  void selectMapPoint(LatLng point) {
    if (busy || !validPoint(point)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      results = [];
      message = null;
      selectedLocation = SelectedLocation(
        name:
            '${point.latitude.toStringAsFixed(6)}, '
            '${point.longitude.toStringAsFixed(6)}',
        point: point,
        placeName: 'Selected map point',
        area: 'Exact coordinates — no address lookup',
        isMapPoint: true,
      );
    });
  }

  void clearSearch() {
    if (busy) return;
    searchController.clear();
    setState(() {
      results = [];
      selectedLocation = null;
      message = null;
    });
  }

  Widget resultCard(SelectedLocation place) {
    final selected = identical(place, selectedLocation);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFFEEF4FF) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? blue : borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : () => selectPlace(place),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5EEFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: blue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.title,
                        style: const TextStyle(
                          color: navy,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        place.area.isEmpty ? place.name : place.area,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle : Icons.chevron_right,
                  color: selected ? blue : muted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget locationMap() {
    final selected = selectedLocation;
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EFF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: const LatLng(6.9271, 79.8612),
          initialZoom: 12,
          minZoom: 3,
          maxZoom: 19,
          onMapReady: () {
            mapReady = true;
            final location = selectedLocation;
            if (location != null) {
              mapController.move(location.point, 16);
            }
          },
          onTap: (_, point) => selectMapPoint(point),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.sevi2001.triplanka',
          ),
          if (selected != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: selected.point,
                  width: 52,
                  height: 52,
                  child: Tooltip(
                    message: selected.title,
                    child: const Icon(Icons.location_on, color: blue, size: 48),
                  ),
                ),
              ],
            ),
          const Align(
            alignment: Alignment.bottomRight,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(6),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(color: navy, fontSize: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget selectionCard(SelectedLocation selected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF159A75)),
              SizedBox(width: 8),
              Text(
                'Selected location',
                style: TextStyle(color: navy, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            selected.title,
            style: const TextStyle(
              color: navy,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (selected.area.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              selected.area,
              style: const TextStyle(color: blue, fontSize: 13, height: 1.5),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Coordinates: '
            '${selected.point.latitude.toStringAsFixed(6)}, '
            '${selected.point.longitude.toStringAsFixed(6)}',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          if (!selected.isMapPoint)
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: ValueKey(selected.name),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text(
                  'View full address',
                  style: TextStyle(
                    color: navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      selected.name,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          const Text(
            'Check this location and the map marker before confirming.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedLocation;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        backgroundColor: background,
        foregroundColor: navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      const Text(
                        'Find your location',
                        style: TextStyle(
                          color: navy,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Include the town in your search. '
                        'For example: Galle Fort, Galle.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: searchController,
                        enabled: !busy,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => searchPlaces(),
                        onChanged: (_) {
                          setState(() {
                            results = [];
                            selectedLocation = null;
                            message = null;
                          });
                        },
                        style: const TextStyle(color: navy),
                        decoration: InputDecoration(
                          labelText: 'Place and town',
                          hintText: 'Galle Fort, Galle',
                          prefixIcon: const Icon(Icons.search, color: blue),
                          suffixIcon: IconButton(
                            tooltip: 'Clear search and selection',
                            onPressed: busy ? null : clearSearch,
                            icon: const Icon(Icons.close, color: muted),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: blue,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: busy ? null : searchPlaces,
                        style: FilledButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: searching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(searching ? 'Searching...' : 'Search'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: busy ? null : useCurrentLocation,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                          locating
                              ? 'Finding your location...'
                              : 'Use my current location',
                        ),
                      ),
                      if (message != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            message!,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      if (results.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Search results',
                          style: TextStyle(
                            color: navy,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final place in results) resultCard(place),
                      ],
                      if (selected != null) ...[
                        const SizedBox(height: 16),
                        selectionCard(selected),
                      ],
                      const SizedBox(height: 18),
                      const Text(
                        'Map preview',
                        style: TextStyle(
                          color: navy,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      locationMap(),
                      const SizedBox(height: 10),
                      const Text(
                        'You can also tap the map to choose an exact point. '
                        'A map tap saves coordinates instead of an address.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: selected == null || busy
                          ? null
                          : () {
                              Navigator.of(
                                context,
                              ).pop<SelectedLocation>(selected);
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.check),
                      label: Text(
                        widget.confirmLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
