import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HomeMap extends StatelessWidget {
  const HomeMap({
    super.key,
    this.loadTiles = true,
  });

  final bool loadTiles;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 280,
        child: FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(6.9271, 79.8612),
            initialZoom: 12,
            minZoom: 3,
            maxZoom: 19,
          ),
          children: [
            if (loadTiles)
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sevi2001.triplanka',
              ),

            // A sample Colombo marker, not the user's location.
            const MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(6.9271, 79.8612),
                  width: 48,
                  height: 48,
                  child: Tooltip(
                    message: 'Colombo — sample map centre',
                    child: Icon(
                      Icons.location_on,
                      color: Colors.teal,
                      size: 44,
                    ),
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
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}