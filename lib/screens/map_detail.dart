import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../main.dart';

class MapDetailScreen extends StatefulWidget {
  final String routeTitle;
  final String routeCoordinates;
  final String mapImagePath;

  const MapDetailScreen({
    super.key,
    required this.routeTitle,
    required this.routeCoordinates,
    required this.mapImagePath,
  });

  @override
  State<MapDetailScreen> createState() => _MapDetailScreenState();
}

class _MapDetailScreenState extends State<MapDetailScreen> {
  late LatLng _position;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _parseCoordinates();
  }

  void _parseCoordinates() {
    try {
      final coords = widget.routeCoordinates
          .replaceAll('Coordenadas:', '')
          .trim()
          .split(',');
      final lat = double.parse(coords[0]);
      final lng = double.parse(coords[1]);
      _position = LatLng(lat, lng);
    } catch (e) {
      _position = const LatLng(22.7709, -102.5832); // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final CameraPosition initialCamera = CameraPosition(
      target: _position,
      zoom: 15,
    );

    final marker = Marker(
      markerId: const MarkerId('espacio'),
      position: _position,
      infoWindow: InfoWindow(title: widget.routeTitle),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.routeTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          // 🗺️ Fondo: mapa de Google en lugar de imagen
          GoogleMap(
            initialCameraPosition: initialCamera,
            markers: {marker},
            onMapCreated: (controller) => _mapController = controller,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),

          // 📍 Panel inferior con detalles
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(0.9),
                border: Border(top: BorderSide(color: Colors.grey[800]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.routeTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.routeCoordinates,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
