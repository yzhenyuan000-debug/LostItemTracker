import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class CampusMapPage extends StatefulWidget {
  const CampusMapPage({super.key});

  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}

class _CampusMapPageState extends State<CampusMapPage> {
  final MapController _mapController = MapController();

  static const LatLng _campusCenter = LatLng(3.2158, 101.7306);
  static const LatLng _libraryDeskLocation = LatLng(3.2172500, 101.7276667);
  static const LatLng _citcDeskLocation = LatLng(3.2139167, 101.7265000);

  final List<LatLng> _campusBoundary = const [
    LatLng(3.2149188, 101.7284679),
    LatLng(3.2150248, 101.7286868),
    LatLng(3.2151547, 101.7291401),
    LatLng(3.215156, 101.7294902),
    LatLng(3.2150489, 101.7298281),
    LatLng(3.21484, 101.7301674),
    LatLng(3.2146646, 101.7303136),
    LatLng(3.214283, 101.7306784),
    LatLng(3.2139295, 101.7312376),
    LatLng(3.2138706, 101.7314737),
    LatLng(3.2141824, 101.7317509),
    LatLng(3.2149014, 101.7326749),
    LatLng(3.2152576, 101.7331738),
    LatLng(3.2154517, 101.7335667),
    LatLng(3.2155816, 101.7342279),
    LatLng(3.2157155, 101.7347496),
    LatLng(3.2158253, 101.7359002),
    LatLng(3.2159244, 101.7360089),
    LatLng(3.2163943, 101.7362114),
    LatLng(3.2167466, 101.7363885),
    LatLng(3.2173075, 101.7363469),
    LatLng(3.2177896, 101.7362516),
    LatLng(3.2179603, 101.7361832),
    LatLng(3.2181257, 101.7360987),
    LatLng(3.2183165, 101.7360015),
    LatLng(3.2186251, 101.7358935),
    LatLng(3.2186653, 101.7336231),
    LatLng(3.2185836, 101.7324288),
    LatLng(3.2186787, 101.7312668),
    LatLng(3.2186834, 101.7306079),
    LatLng(3.2186077, 101.7300028),
    LatLng(3.2185749, 101.7293654),
    LatLng(3.2184886, 101.7288139),
    LatLng(3.2185033, 101.7276089),
    LatLng(3.2185606, 101.7273425),
    LatLng(3.2185214, 101.7271083),
    LatLng(3.2184394, 101.726799),
    LatLng(3.2184645, 101.7264146),
    LatLng(3.2170933, 101.7247624),
    LatLng(3.2168443, 101.7246873),
    LatLng(3.2144716, 101.7256556),
    LatLng(3.2130938, 101.7259734),
    LatLng(3.2133348, 101.7265997),
    LatLng(3.2135932, 101.7270315),
    LatLng(3.2143604, 101.7276914),
    LatLng(3.214659, 101.7280374),
    LatLng(3.2149188, 101.7284679),
  ];

  LatLng? _startPoint;
  LatLng? _endPoint;
  List<LatLng> _routePoints = [];
  double? _routeDistance;
  bool _isSelectingStart = false;
  bool _isSelectingEnd = false;
  bool _isCalculatingRoute = false;

  LatLng? _userLocation;
  String? _selectedMarker;
  String? _selectedDesk;

  void _recenterMap() {
    _mapController.move(_campusCenter, 16.5);
  }

  void _onMapTap(LatLng point) {
    setState(() {
      if (_isSelectingStart) {
        _startPoint = point;
        _isSelectingStart = false;
        _routePoints.clear();
        _routeDistance = null;
      } else if (_isSelectingEnd) {
        _endPoint = point;
        _isSelectingEnd = false;
        _routePoints.clear();
        _routeDistance = null;
      }
    });
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied')),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _startPoint = _userLocation;
        _routePoints.clear();
        _routeDistance = null;
      });

      _mapController.move(_userLocation!, 17.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current location set as start point')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Future<void> _calculateRoute() async {
    if (_startPoint == null || _endPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and end points')),
      );
      return;
    }

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      final url = 'https://router.project-osrm.org/route/v1/foot/'
          '${_startPoint!.longitude},${_startPoint!.latitude};'
          '${_endPoint!.longitude},${_endPoint!.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List;
          final distance = route['distance'] as num;

          setState(() {
            _routePoints = geometry
                .map((coord) => LatLng(coord[1] as double, coord[0] as double))
                .toList();
            _routeDistance = distance.toDouble();
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Route calculated: ${_formatDistance(_routeDistance!)}')),
            );
          }
        } else {
          throw Exception('No route found');
        }
      } else {
        throw Exception('Failed to fetch route');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error calculating route: $e')),
        );
      }
    } finally {
      setState(() {
        _isCalculatingRoute = false;
      });
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  String _calculateWalkingTime(double meters) {
    const double walkingSpeedKmh = 5.0;
    double kilometers = meters / 1000;
    double hours = kilometers / walkingSpeedKmh;
    int minutes = (hours * 60).round();
    return '$minutes min';
  }

  void _onDeskSelected(String? desk) {
    if (desk == null) return;

    setState(() {
      _selectedDesk = desk;
    });

    LatLng targetLocation;
    String markerType;

    if (desk == 'Library Desk') {
      targetLocation = _libraryDeskLocation;
      markerType = 'library';
    } else {
      targetLocation = _citcDeskLocation;
      markerType = 'citc';
    }

    _mapController.move(targetLocation, 18.0);

    setState(() {
      _selectedMarker = markerType;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _recenterMap,
            tooltip: 'Recenter Map',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _campusCenter,
              initialZoom: 16.5,
              minZoom: 14.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (tapPosition, point) {
                if (_isSelectingStart || _isSelectingEnd) {
                  _onMapTap(point);
                } else {
                  setState(() {
                    _selectedMarker = null;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tarumt.lost_item_tracker',
                maxZoom: 19,
              ),
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _campusBoundary,
                    color: Colors.indigo.withOpacity(0.15),
                    borderColor: Colors.indigo.shade700,
                    borderStrokeWidth: 3.0,
                    isFilled: true,
                  ),
                ],
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue.shade700,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _libraryDeskLocation,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMarker = 'library';
                        });
                      },
                      child: Icon(
                        Icons.location_on,
                        size: 40,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  Marker(
                    point: _citcDeskLocation,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMarker = 'citc';
                        });
                      },
                      child: Icon(
                        Icons.location_on,
                        size: 40,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                  if (_startPoint != null)
                    Marker(
                      point: _startPoint!,
                      width: 50,
                      height: 50,
                      child: Icon(
                        Icons.place,
                        size: 50,
                        color: Colors.green.shade600,
                      ),
                    ),
                  if (_endPoint != null)
                    Marker(
                      point: _endPoint!,
                      width: 50,
                      height: 50,
                      child: Icon(
                        Icons.place,
                        size: 50,
                        color: Colors.red.shade600,
                      ),
                    ),
                ],
              ),
            ],
          ),

          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Route Planning',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isSelectingStart = true;
                                _isSelectingEnd = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tap on map to select start point'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Start', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSelectingStart
                                  ? Colors.green.shade100
                                  : (_startPoint != null ? Colors.green.shade50 : null),
                              foregroundColor: Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isSelectingEnd = true;
                                _isSelectingStart = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tap on map to select end point'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.flag, size: 18),
                            label: const Text('End', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSelectingEnd
                                  ? Colors.red.shade100
                                  : (_endPoint != null ? Colors.red.shade50 : null),
                              foregroundColor: Colors.red.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: (_startPoint != null && _endPoint != null && !_isCalculatingRoute)
                          ? _calculateRoute
                          : null,
                      icon: _isCalculatingRoute
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Icon(Icons.directions),
                      label: Text(_isCalculatingRoute ? 'Calculating...' : 'Calculate Route'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    if (_routeDistance != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.straighten, size: 18, color: Colors.indigo.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Distance: ${_formatDistance(_routeDistance!)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.indigo.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.access_time, size: 18, color: Colors.indigo.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Walking Time: ${_calculateWalkingTime(_routeDistance!)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.indigo.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 16,
            top: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Drop-off Desks',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _selectedDesk,
                      hint: const Text('Select Desk', style: TextStyle(fontSize: 13)),
                      isExpanded: false,
                      underline: Container(),
                      items: const [
                        DropdownMenuItem(
                          value: 'Library Desk',
                          child: Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Library Desk', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'CITC Desk',
                          child: Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('CITC Desk', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                      onChanged: _onDeskSelected,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_selectedMarker != null)
            Positioned(
              top: 16,
              right: 16,
              child: _buildInfoWindow(),
            ),

          Positioned(
            left: 16,
            top: MediaQuery.of(context).size.height / 2 - 18,
            child: FloatingActionButton(
              heroTag: 'get_location',
              onPressed: _getUserLocation,
              backgroundColor: Colors.indigo.shade700,
              child: const Icon(Icons.my_location, color: Colors.white),
              tooltip: 'Get Current Location',
            ),
          ),

          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height / 2 - 50,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                  child: Icon(Icons.add, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                  child: Icon(Icons.remove, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoWindow() {
    String title;
    String description;
    Color color;

    if (_selectedMarker == 'library') {
      title = 'Library Drop-off Desk';
      description = 'Lost & Found Collection Point';
      color = Colors.blue.shade700;
    } else {
      title = 'CITC Drop-off Desk';
      description = 'Lost & Found Collection Point';
      color = Colors.orange.shade700;
    }

    return Card(
      elevation: 6,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.location_on, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() {
                  _selectedMarker = null;
                });
              },
              color: Colors.grey.shade600,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}