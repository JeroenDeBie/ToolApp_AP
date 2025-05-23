import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';


class MapWidget extends StatelessWidget{
  final List<Marker> markers;
  final void Function(LatLng)? onTap;

  const MapWidget({super.key, required this.markers, this.onTap});

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(51.509364, -0.128928), // Center the map over London
        initialZoom: 9.2,
        onTap: (tapPosition, latlng) {
          if (onTap != null) onTap!(latlng);
        }
      ),
      children: [
        TileLayer( // Bring your own tiles
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // For demonstration only
          userAgentPackageName: 'com.example.app', // Add your app identifier
          // And many more recommended properties!
        ),
        MarkerLayer(
        markers: markers
        ),
        RichAttributionWidget( // Include a stylish prebuilt attribution widget that meets all requirments
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')), // (external)
            ),
            // Also add images...
          ],
        ),
      ],
    );
  }
}
