import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class SelectedLocation {
  const SelectedLocation({required this.name, required this.point});

  final String name;
  final LatLng point;
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final searchController = TextEditingController();
  final mapController = MapController();

  final Map<String, List<SelectedLocation>> cache = {};

  List<SelectedLocation> results = [];
  SelectedLocation? selectedLocation;

  bool searching = false;
  String? message;
  DateTime? lastRequest;

  @override
  void dispose() {
    searchController.dispose();
    mapController.dispose();
    super.dispose();
  }

  Future<void> searchPlaces() async {
    if (searching) return;

    final query = searchController.text.trim();

    if (query.length < 3) {
      setState(() {
        message = 'Enter at least three characters.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    final cacheKey = query.toLowerCase();

    if (cache.containsKey(cacheKey)) {
      showResults(cache[cacheKey]!);
      return;
    }

    final previous = lastRequest;

    if (previous != null &&
        DateTime.now().difference(previous).inMilliseconds < 1100) {
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

    lastRequest = DateTime.now();

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'countrycodes': 'lk',
        'limit': '5',
        'accept-language': 'en',
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

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;

      final places = data.map((item) {
        final place = Map<String, dynamic>.from(item as Map);

        return SelectedLocation(
          name: place['display_name'] as String,
          point: LatLng(
            double.parse(place['lat'] as String),
            double.parse(place['lon'] as String),
          ),
        );
      }).toList();

      if (!mounted) return;

      cache[cacheKey] = places;
      showResults(places);
    } catch (error) {
      debugPrint('Place search failed: $error');

      if (!mounted) return;

      setState(() {
        message = 'Search failed. Check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          searching = false;
        });
      }
    }
  }

  void showResults(List<SelectedLocation> places) {
    setState(() {
      results = places;
      selectedLocation = null;
      message = places.isEmpty
          ? 'No places found. Try another name or nearby town.'
          : 'Choose the correct result below.';
    });
  }

  void selectPlace(SelectedLocation place) {
    setState(() {
      selectedLocation = place;
      results = [];
      message = null;
    });

    mapController.move(place.point, 16);
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedLocation;

    return Scaffold(
      appBar: AppBar(title: const Text('Find pickup')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => searchPlaces(),
                    decoration: const InputDecoration(
                      labelText: 'Search a place in Sri Lanka',
                      hintText: 'Colombo Fort Railway Station',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: searching ? null : searchPlaces,
                      child: Text(searching ? 'Searching...' : 'Search'),
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(message!),
                  ],
                ],
              ),
            ),

            if (results.isNotEmpty)
              SizedBox(
                height: 160,
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final place = results[index];

                    return ListTile(
                      leading: const Icon(Icons.place, color: Colors.teal),
                      title: Text(
                        place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => selectPlace(place),
                    );
                  },
                ),
              ),

            Expanded(
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: const LatLng(6.9271, 79.8612),
                  initialZoom: 12,
                  minZoom: 3,
                  maxZoom: 19,
                  onTap: (_, point) {
                    setState(() {
                      results = [];
                      message = null;
                      selectedLocation = SelectedLocation(
                        name:
                            '${point.latitude.toStringAsFixed(6)}, '
                            '${point.longitude.toStringAsFixed(6)}',
                        point: point,
                      );
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.sevi2001.triplanka',
                  ),
                  if (selected != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: selected.point,
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.teal,
                            size: 44,
                          ),
                        ),
                      ],
                    ),
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: ColoredBox(
                      color: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.all(5),
                        child: Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    selected?.name ?? 'Search and choose a pickup.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selected == null || searching
                          ? null
                          : () {
                              Navigator.of(
                                context,
                              ).pop<SelectedLocation>(selected);
                            },
                      child: const Text('Use this pickup'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
