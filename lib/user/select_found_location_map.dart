import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SelectFoundLocationMapPage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final double? initialRadius; // Kept for compatibility but not used

  const SelectFoundLocationMapPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialRadius,
  });

  @override
  State<SelectFoundLocationMapPage> createState() => _SelectFoundLocationMapPageState();
}

class _SelectFoundLocationMapPageState extends State<SelectFoundLocationMapPage> {
  final MapController _mapController = MapController();
  static const LatLng _campusCenter = LatLng(3.2158, 101.7306);

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

  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();

    // Initialize with existing values if provided
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _selectedLocation = point;
      _selectedAddress = null; // Reset address when location changes
    });

    // Move map to tapped location
    _mapController.move(point, 17.0);

    // Fetch address for the selected location
    _fetchAddress(point);

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location selected'),
        duration: Duration(seconds: 2),
      ),
    );
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
      final userLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = userLocation;
        _selectedAddress = null;
      });

      _mapController.move(userLocation, 17.0);
      _fetchAddress(userLocation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current location selected')),
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

  Future<void> _fetchAddress(LatLng location) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      // Using Nominatim reverse geocoding (free, no API key needed)
      final url = 'https://nominatim.openstreetmap.org/reverse?'
          'format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'LostItemTrackerApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _selectedAddress = data['display_name'] ?? 'Address not found';
            _isLoadingAddress = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedAddress = 'Address not available';
            _isLoadingAddress = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedAddress = 'Unable to fetch address';
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _recenterMap() {
    if (_selectedLocation != null) {
      _mapController.move(_selectedLocation!, 17.0);
    } else {
      _mapController.move(_campusCenter, 16.5);
    }
  }

  void _confirmLocation() {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location on the map first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Return the selected location data to the previous page
    // Note: radius is set to null since we don't use it for found items
    Navigator.pop(context, {
      'latitude': _selectedLocation!.latitude,
      'longitude': _selectedLocation!.longitude,
      'radius': null, // No radius for found items
      'address': _selectedAddress ?? 'Location selected',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Found Location'),
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
              initialCenter: widget.initialLatitude != null && widget.initialLongitude != null
                  ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
                  : _campusCenter,
              initialZoom: 16.5,
              minZoom: 14.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (tapPosition, point) => _onMapTap(point),
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
              // Marker for the selected location (no circle, just a pin)
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_on,
                        size: 50,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Instructions Card at the top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.indigo.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Tap on the map to select where you found the item',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedLocation != null) ...[
                      const Divider(height: 20),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.green.shade600, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (_isLoadingAddress)
                                  const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                  Text(
                                    _selectedAddress ?? 'Fetching address...',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Confirm Button at the bottom (no range slider needed)
          if (_selectedLocation != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.place, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Location Pinpointed',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The exact location where you found the item has been marked',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _confirmLocation,
                          icon: const Icon(Icons.check_circle, size: 20),
                          label: const Text(
                            'Confirm Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Floating Action Buttons
          Positioned(
            left: 16,
            top: MediaQuery.of(context).size.height / 2 - 18,
            child: FloatingActionButton(
              heroTag: 'get_location',
              onPressed: _getUserLocation,
              backgroundColor: Colors.indigo.shade700,
              tooltip: 'Use Current Location',
              child: const Icon(Icons.my_location, color: Colors.white),
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
                    _mapController.move(_mapController.camera.center, currentZoom + 1);
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
                    _mapController.move(_mapController.camera.center, currentZoom - 1);
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

  @override
  void dispose() {
    super.dispose();
  }
}