import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../main.dart';

const String _googleMapsApiKey = 'AIzaSyDXqhqyG7fsp2fR2LDgV5YxyqtkcYUsmOI';

class PantallaDetalleMapa extends StatefulWidget {
  final String tituloRuta;
  final String coordenadasRuta;
  final String imagenMapa; // por si luego quieres usarla en otro modo

  const PantallaDetalleMapa({
    super.key,
    required this.tituloRuta,
    required this.coordenadasRuta,
    required this.imagenMapa,
  });

  @override
  State<PantallaDetalleMapa> createState() => EstadoPantallaDetalleMapa();
}

// Compatibilidad con el nombre antiguo
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

class EstadoPantallaDetalleMapa extends State<PantallaDetalleMapa> {
  late LatLng _destino; // Ubicación del espacio
  LatLng? _origen;      // Ubicación actual del corredor

  GoogleMapController? _controladorMapa;
  bool _tienePermisoUbicacion = false;
  bool _dibujandoRuta = false;

  /// Ruta dibujada (polilínea)
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _parsearCoordenadasDestino();
    _checarPermisoInicialUbicacion();
  }

  @override
  void dispose() {
    _controladorMapa?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers de UI
  // ---------------------------------------------------------------------------
  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Parsing del destino (coordenadas del espacio)
  // ---------------------------------------------------------------------------
  void _parsearCoordenadasDestino() {
    try {
      // Formato esperado: "Coordenadas: lat, lng"
      final cleaned =
          widget.coordenadasRuta.replaceAll('Coordenadas:', '').trim();
      final parts = cleaned.split(',');
      final lat = double.parse(parts[0].trim());
      final lng = double.parse(parts[1].trim());
      _destino = LatLng(lat, lng);
    } catch (_) {
      // Fallback (Zacatecas)
      _destino = const LatLng(22.7709, -102.5832);
    }
  }

  // ---------------------------------------------------------------------------
  // Permisos de ubicación
  // ---------------------------------------------------------------------------
  /// Checa permiso al entrar, solo para poder prender el punto azul (`myLocationEnabled`).
  Future<void> _checarPermisoInicialUbicacion() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    final ok = perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;

    if (!mounted) return;
    setState(() => _tienePermisoUbicacion = ok);
  }

  /// Verifica permiso de ubicación específicamente para la ruta (CU-12 4A).
  Future<bool> _confirmarPermisoParaRuta() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      // CU-12 4A: permiso denegado
      _snack(
        'Debes habilitar el permiso de ubicación para continuar.',
        error: true,
      );
      return false;
    }

    if (!mounted) return false;
    setState(() => _tienePermisoUbicacion = true);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Lógica principal de CU-12: mostrar ruta usando Google Directions API
  // ---------------------------------------------------------------------------
  Future<void> _solicitarYMostrarRuta() async {
    if (_dibujandoRuta) return;

    setState(() => _dibujandoRuta = true);

    try {
      // 4A: permiso de ubicación denegado
      final tienePermiso = await _confirmarPermisoParaRuta();
      if (!tienePermiso) return; // flujo termina

      // E1: falta de conectividad
      final conn = await Connectivity().checkConnectivity();
      if (conn == ConnectivityResult.none) {
        _snack(
          'No hay conexión a internet. No es posible mostrar la ruta.',
          error: true,
        );
        return; // CU-12 E1
      }

      // Paso 4: obtener ubicación actual del corredor
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _origen = LatLng(pos.latitude, pos.longitude);

      // Paso 5: ya tenemos _destino desde _parsearCoordenadasDestino()

      // Paso 6: solicitar a Directions API el trazado de la ruta (modo caminando)
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_origen!.latitude},${_origen!.longitude}'
        '&destination=${_destino.latitude},${_destino.longitude}'
        '&mode=walking'
        '&key=$_googleMapsApiKey',
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        // CU-12 E2: error en API de mapas
        _snack(
          'Ocurrió un error al consultar la ruta. El servicio de mapas no está disponible temporalmente.',
          error: true,
        );
        return;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'UNKNOWN';

      if (status != 'OK') {
        // REQUEST_DENIED, ZERO_RESULTS, etc. → manejar como E2
        _snack(
          'Ocurrió un error al consultar la ruta. El servicio de mapas no está disponible temporalmente.',
          error: true,
        );
        return;
      }

      final routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) {
        _snack(
          'No se encontró una ruta disponible para este trayecto.',
          error: true,
        );
        return;
      }

      final overview = routes[0]['overview_polyline'] as Map<String, dynamic>;
      final encoded = overview['points'] as String;

      final puntosRuta = _decodePolyline(encoded);

      final polyline = Polyline(
        polylineId: const PolylineId('ruta_corredor_espacio'),
        points: puntosRuta,
        width: 6,
        color: Colors.cyanAccent,
      );

      if (!mounted) return;
      setState(() {
        _polylines = {polyline};
      });

      // Paso 7: Ajustar cámara a la ruta completa
      await _enfocarRuta(puntosRuta);
    } catch (_) {
      // CU-12 E2: error inesperado en API/decodificación
      _snack(
        'Ocurrió un error al obtener la ruta. El servicio de mapas no está disponible temporalmente.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _dibujandoRuta = false);
      }
    }
  }

  /// Ajusta la cámara para mostrar toda la polilínea.
  Future<void> _enfocarRuta(List<LatLng> puntos) async {
    if (_controladorMapa == null || puntos.isEmpty) return;

    double minLat = puntos.first.latitude;
    double maxLat = puntos.first.latitude;
    double minLng = puntos.first.longitude;
    double maxLng = puntos.first.longitude;

    for (final p in puntos) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await _controladorMapa!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60),
    );
  }

  // ---------------------------------------------------------------------------
  // Decodificador de polilínea de Google (overview_polyline.points)
  // ---------------------------------------------------------------------------
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> puntos = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      final punto = LatLng(lat / 1e5, lng / 1e5);
      puntos.add(punto);
    }

    return puntos;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final camaraInicial = CameraPosition(target: _destino, zoom: 15);

    // Marcador del espacio (destino)
    final marcadorDestino = Marker(
      markerId: const MarkerId('espacio'),
      position: _destino,
      infoWindow: InfoWindow(title: widget.tituloRuta),
    );

    // Marcador opcional del origen (ubicación actual)
    final markers = <Marker>{marcadorDestino};
    if (_origen != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('origen'),
          position: _origen!,
          infoWindow: const InfoWindow(title: 'Tu ubicación'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          // --- Mapa principal ---
          GoogleMap(
            initialCameraPosition: camaraInicial,
            markers: markers,
            polylines: _polylines,
            onMapCreated: (c) => _controladorMapa = c,
            myLocationEnabled: _tienePermisoUbicacion,
            myLocationButtonEnabled: _tienePermisoUbicacion,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),

          // --- Panel inferior con info + botón de ruta ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(0.9),
                border: Border(
                  top: BorderSide(color: Colors.grey[800]!),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.tituloRuta,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.coordenadasRuta,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _dibujandoRuta ? null : _solicitarYMostrarRuta,
                        icon: _dibujandoRuta
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.route),
                        label: Text(
                          _dibujandoRuta
                              ? 'Calculando ruta...'
                              : 'Mostrar ruta desde mi ubicación',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
