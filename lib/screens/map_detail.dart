import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../main.dart';

class PantallaDetalleMapa extends StatefulWidget {
  final String tituloRuta;
  final String coordenadasRuta;
  final String imagenMapa;

  const PantallaDetalleMapa({
    super.key,
    required this.tituloRuta,
    required this.coordenadasRuta,
    required this.imagenMapa,
  });

  @override
  State<PantallaDetalleMapa> createState() => _EstadoPantallaDetalleMapa();
}

// 👇 Compat: si en otro lado siguen usando MapDetailScreen, no se rompe
class MapDetailScreen extends PantallaDetalleMapa {
  const MapDetailScreen({
    super.key,
    required String routeTitle,
    required String routeCoordinates,
    required String mapImagePath,
  }) : super(
          tituloRuta: routeTitle,
          coordenadasRuta: routeCoordinates,
          imagenMapa: mapImagePath,
        );
}

class _EstadoPantallaDetalleMapa extends State<PantallaDetalleMapa> {
  late LatLng _posicion;
  GoogleMapController? _controladorMapa;
  bool _tienePermisoUbicacion = false;

  @override
  void initState() {
    super.initState();
    _parsearCoordenadas();
    _asegurarPermisoUbicacion();
  }

  void _parsearCoordenadas() {
    try {
      final coords = widget.coordenadasRuta.replaceAll('Coordenadas:', '').trim().split(',');
      final lat = double.parse(coords[0].trim());
      final lng = double.parse(coords[1].trim());
      _posicion = LatLng(lat, lng);
    } catch (_) {
      _posicion = const LatLng(22.7709, -102.5832); // fallback Zacatecas
    }
  }

  Future<void> _asegurarPermisoUbicacion() async {
    await Geolocator.isLocationServiceEnabled(); // no forzamos
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    final ok = (perm == LocationPermission.always || perm == LocationPermission.whileInUse);
    if (mounted) setState(() => _tienePermisoUbicacion = ok);
  }

  @override
  Widget build(BuildContext context) {
    final camaraInicial = CameraPosition(target: _posicion, zoom: 15);
    final marcador = Marker(
      markerId: const MarkerId('espacio'),
      position: _posicion,
      infoWindow: InfoWindow(title: widget.tituloRuta),
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
          widget.tituloRuta,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: camaraInicial,
            markers: {marcador},
            onMapCreated: (c) => _controladorMapa = c,
            myLocationEnabled: _tienePermisoUbicacion,
            myLocationButtonEnabled: _tienePermisoUbicacion,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
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
                  Text(widget.tituloRuta,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(widget.coordenadasRuta, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
