import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location_package;
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final location_package.Location _locationController = location_package.Location();
  GoogleMapController? _mapController;
  LatLng? _currentP;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = false;
  MapType _currentMapType = MapType.normal;
  bool _trafficEnabled = true;
  final bool _buildingsEnabled = true;

  // Search and selected locations
  final TextEditingController _searchController = TextEditingController();
  List<Prediction> predictions = [];
  final List<LatLng> _selectedLocations = [];
  int currentRouteIndex = 0;
  bool _isSearchExpanded = false; // Track search bar expansion state

  // Real-time navigation variables
  bool _isNavigating = false;
  LatLng? _currentDestination;
  List<LatLng> _currentRoutePoints = [];
  List<LatLng> _remainingDestinations = [];
  bool _hasArrived = false;
  StreamSubscription<location_package.LocationData>? _locationSubscription;
  Timer? _rerouteTimer;

  String get _googleApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  Future<void> loadEnv() async {
    await dotenv.load(fileName: ".env");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentP == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text("Getting your location..."),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _currentP = null);
                      getCurrentLocation();
                    },
                    child: const Text("Retry Location"),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentP!,
                    zoom: 10,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapType: _currentMapType,
                  trafficEnabled: _trafficEnabled,
                  buildingsEnabled: _buildingsEnabled,
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (controller) => _mapController = controller,
                  zoomControlsEnabled: false, // Disable built-in zoom controls
                  compassEnabled: false, // Disable built-in compass
                ),
                // Search Bar
                Positioned(
                  top: 20,
                  left: 10,
                  right: _isSearchExpanded ? 70 : 290,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: _isSearchExpanded ? null : 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(
                            _isSearchExpanded ? Icons.close : Icons.search,
                            color: const Color.fromARGB(255, 255, 126, 126),
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() {
                              _isSearchExpanded = !_isSearchExpanded;
                              if (!_isSearchExpanded) {
                                _searchController.clear();
                                FocusScope.of(context).unfocus();
                              }
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        if (_isSearchExpanded) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: GooglePlaceAutoCompleteTextField(
                              textEditingController: _searchController,
                              googleAPIKey: _googleApiKey,
                              inputDecoration: const InputDecoration(
                                hintText: 'Search for a place...',
                                hintStyle: TextStyle(color: Color.fromARGB(255, 255, 126, 126), fontSize: 16, fontWeight: FontWeight.w500, fontFamily: 'Roboto'),
                                
                                border: InputBorder.none,
                                
                              ),
                              debounceTime: 800,
                              countries: const ["lk"], // Sri Lanka
                              isLatLngRequired: true,
                              getPlaceDetailWithLatLng: (Prediction prediction) {
                                _addLocationFromPrediction(prediction);
                              },
                              itemClick: (Prediction prediction) {
                                _searchController.text = prediction.description ?? '';
                                _searchController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: prediction.description?.length ?? 0),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Selected Locations List
                if (_selectedLocations.isNotEmpty)
                  Positioned(
                    top: 120,
                    left: 10,
                    right: 80,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 100),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _selectedLocations.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            title: Text('Location ${index + 1}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => _removeLocation(index),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                // Map Controls (Top Right)
                Positioned(
                  top: 20,
                  right: 10,
                  child: Column(
                    children: [
                      _buildMapControlButton(
                        icon: Icons.map,
                        onPressed: _showMapTypeDialog,
                        tooltip: 'Map Type',
                      ),
                      const SizedBox(height: 8),
                      _buildMapControlButton(
                        icon: _trafficEnabled ? Icons.traffic : Icons.traffic_outlined,
                        onPressed: _toggleTraffic,
                        tooltip: 'Traffic',
                      ),
                      const SizedBox(height: 8),
                      _buildMapControlButton(
                        icon: Icons.my_location,
                        onPressed: _goToCurrentLocation,
                        tooltip: 'My Location',
                      ),
                    ],
                  ),
                ),
                // Zoom Controls (Bottom Right)
                Positioned(
                  bottom: 100,
                  right: 10,
                  child: Column(
                    children: [
                      _buildZoomControlButton(
                        icon: Icons.add,
                        onPressed: _zoomIn,
                        tooltip: 'Zoom In',
                      ),
                      const SizedBox(height: 8),
                      _buildZoomControlButton(
                        icon: Icons.remove,
                        onPressed: _zoomOut,
                        tooltip: 'Zoom Out',
                      ),
                    ],
                  ),
                ),
                // Compass (Bottom Right, above zoom controls)
                Positioned(
                  bottom: 100,
                  left: 10,
                  child: _buildCompassButton(),
                ),
                // Get Directions / Park Button
                Positioned(
                  bottom: 27,
                  left: 20,
                  right: _hasArrived ? 120 : 80,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : (_hasArrived ? _parkAndContinue : _getDirections),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color.fromARGB(255, 255, 126, 126),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _hasArrived ? Icons.local_parking : (_isNavigating ? Icons.stop : Icons.directions),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _hasArrived ? 'Park & Continue' : (_isNavigating ? 'Stop Navigation' : 'Get Directions'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Stop Navigation Button (when navigating)
                if (_isNavigating && !_hasArrived)
                  Positioned(
                    bottom: 27,
                    right: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _stopNavigation,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          backgroundColor: Colors.white,
                          foregroundColor: const Color.fromARGB(255, 255, 126, 126),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.stop, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Stop',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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

  Future<void> getCurrentLocation() async {
    bool serviceEnabled;
    location_package.PermissionStatus permissionGranted;

    serviceEnabled = await _locationController.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationController.requestService();
      if (!serviceEnabled) {
        // User denied enabling location services
        _showLocationError("Location services are required for navigation. Please enable location services.");
        return;
      }
    }

    permissionGranted = await _locationController.hasPermission();
    if (permissionGranted == location_package.PermissionStatus.denied) {
      permissionGranted = await _locationController.requestPermission();
      if (permissionGranted != location_package.PermissionStatus.granted) {
        _showLocationError("Location permission is required for navigation. Please grant location permission.");
        return;
      }
    }

    // Configure location settings for navigation
    await _locationController.changeSettings(
      accuracy: location_package.LocationAccuracy.high,
      interval: 2000, // Update every 2 seconds
      distanceFilter: 5.0, // Update when moved 5 meters
    );

    _locationSubscription = _locationController.onLocationChanged.listen((location_package.LocationData currentLocation) {
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        LatLng newPosition = LatLng(currentLocation.latitude!, currentLocation.longitude!);
        setState(() {
          _currentP = newPosition;
          _addCurrentLocationMarker();
        });

        // Handle navigation logic if currently navigating
        if (_isNavigating && _currentDestination != null) {
          _handleNavigationUpdate(newPosition);
        }
      }
    });
  }

  void _showLocationError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              setState(() => _currentP = null);
              getCurrentLocation();
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _addCurrentLocationMarker() {
    if (_currentP != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('_currentLocation'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          position: _currentP!,
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: const Color.fromARGB(255, 255, 126, 126), size: 24),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showMapTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Map Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMapTypeOption(MapType.normal, 'Normal'),
            _buildMapTypeOption(MapType.satellite, 'Satellite'),
            _buildMapTypeOption(MapType.terrain, 'Terrain'),
            _buildMapTypeOption(MapType.hybrid, 'Hybrid'),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTypeOption(MapType mapType, String label) {
    return ListTile(
      title: Text(label),
      leading: Radio<MapType>(
        value: mapType,
        groupValue: _currentMapType,
        onChanged: (value) {
          setState(() => _currentMapType = value!);
          Navigator.of(context).pop();
        },
      ),
      onTap: () {
        setState(() => _currentMapType = mapType);
        Navigator.of(context).pop();
      },
    );
  }

  void _toggleTraffic() {
    setState(() => _trafficEnabled = !_trafficEnabled);
  }

  void _goToCurrentLocation() {
    if (_currentP != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentP!, zoom: 15),
        ),
      );
    }
  }

  void _zoomIn() {
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.zoomIn());
    }
  }

  void _zoomOut() {
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.zoomOut());
    }
  }

  Widget _buildZoomControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: const Color.fromARGB(255, 255, 126, 126), size: 28),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildCompassButton() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.explore, color: Color.fromARGB(255, 255, 126, 126), size: 28),
        onPressed: _resetBearing,
        tooltip: 'Reset Bearing (North)',
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _resetBearing() {
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentP ?? const LatLng(0, 0),
          zoom: 15,
          bearing: 0.0, // Reset to north
        ),
      ));
    }
  }

  void _addLocationFromPrediction(Prediction prediction) {
    if (prediction.lat != null && prediction.lng != null) {
      LatLng position = LatLng(double.parse(prediction.lat!), double.parse(prediction.lng!));
      setState(() {
        _selectedLocations.add(position);
        _addMarkerForLocation(position, _selectedLocations.length);
      });
      _searchController.clear();
      _mapController?.animateCamera(CameraUpdate.newLatLng(position));
    }
  }

  void _addMarkerForLocation(LatLng position, int index) {
    _markers.add(
      Marker(
        markerId: MarkerId('selected_$index'),
        position: position,
        infoWindow: InfoWindow(
          title: 'Destination $index',
          snippet: 'Tap to remove',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: () => _removeLocation(index - 1),
      ),
    );
  }

  void _removeLocation(int index) {
    if (index >= 0 && index < _selectedLocations.length) {
      LatLng location = _selectedLocations[index];

      // If currently navigating to this location, stop navigation
      if (_currentDestination == location) {
        _stopNavigation();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigation stopped - destination removed')),
        );
      }

      // Remove from remaining destinations if present
      _remainingDestinations.remove(location);

      setState(() {
        _selectedLocations.removeAt(index);
        _markers.removeWhere((marker) => marker.position == location);
        // Re-add markers with updated indices
        _markers.removeWhere((marker) => marker.markerId.value.startsWith('selected_'));
        for (int i = 0; i < _selectedLocations.length; i++) {
          _addMarkerForLocation(_selectedLocations[i], i + 1);
        }
      });

      _clearRoutes();
    }
  }

  void _clearRoutes() {
    setState(() {
      _polylines.clear();
      currentRouteIndex = 0;
    });
  }

  void _handleNavigationUpdate(LatLng currentPosition) {
    if (_currentDestination == null) return;

    // Check if arrived at destination (within 30m radius)
    double distanceToDestination = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      _currentDestination!.latitude,
      _currentDestination!.longitude,
    );

    if (distanceToDestination <= 30) {
      // Arrived at destination
      setState(() => _hasArrived = true);
      _showArrivalNotification();
      return;
    }

    // Check if user deviated from route (more than 50m from route)
    bool isOnRoute = _isUserOnRoute(currentPosition);
    if (!isOnRoute) {
      // User deviated from route, trigger rerouting
      _rerouteTimer ??= Timer(const Duration(seconds: 5), () {
        _rerouteToDestination(currentPosition);
        _rerouteTimer = null;
      });
    } else {
      // Cancel reroute timer if user is back on route
      _rerouteTimer?.cancel();
      _rerouteTimer = null;
    }
  }

  bool _isUserOnRoute(LatLng userPosition) {
    if (_currentRoutePoints.isEmpty) return true;

    // Check if user is within 50 meters of any point on the current route
    for (LatLng routePoint in _currentRoutePoints) {
      double distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        routePoint.latitude,
        routePoint.longitude,
      );
      if (distance <= 50) {
        return true;
      }
    }
    return false;
  }

  Future<void> _rerouteToDestination(LatLng currentPosition) async {
    if (_currentDestination == null) return;

    setState(() => _isLoading = true);

    List<LatLng> newRoutePoints = await _getRoutePoints(currentPosition, _currentDestination!);
    if (newRoutePoints.isNotEmpty) {
      setState(() {
        _currentRoutePoints = newRoutePoints;
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('current_route'),
            points: newRoutePoints,
            color: Colors.red,
            width: 6,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
      });

      // Fit camera to show the new route
      _fitCameraToRoute(newRoutePoints);
    }

    setState(() => _isLoading = false);
  }

  void _showArrivalNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have arrived at your destination!'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _parkAndContinue() {
    setState(() => _hasArrived = false);

    // Move to next destination
    if (_remainingDestinations.isNotEmpty) {
      _startNavigationToNextDestination();
    } else {
      // All destinations completed
      _stopNavigation();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All destinations completed!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _startNavigationToNextDestination() {
    if (_remainingDestinations.isEmpty) return;

    setState(() {
      _currentDestination = _remainingDestinations.removeAt(0);
      _hasArrived = false;
    });

    _navigateToDestination(_currentP!, _currentDestination!);
  }

  Future<void> _navigateToDestination(LatLng origin, LatLng destination) async {
    setState(() => _isLoading = true);

    List<LatLng> routePoints = await _getRoutePoints(origin, destination);
    if (routePoints.isNotEmpty) {
      setState(() {
        _currentRoutePoints = routePoints;
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('current_route'),
            points: routePoints,
            color: Colors.red,
            width: 6,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
      });

      _fitCameraToRoute(routePoints);
    }

    setState(() => _isLoading = false);
  }

  void _fitCameraToRoute(List<LatLng> routePoints) {
    if (_mapController == null || routePoints.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (LatLng point in routePoints) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    // Include current location
    if (_currentP != null) {
      minLat = min(minLat, _currentP!.latitude);
      maxLat = max(maxLat, _currentP!.latitude);
      minLng = min(minLng, _currentP!.longitude);
      maxLng = max(maxLng, _currentP!.longitude);
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _currentDestination = null;
      _currentRoutePoints.clear();
      _remainingDestinations.clear();
      _hasArrived = false;
      _polylines.clear();
    });

    _locationSubscription?.cancel();
    _rerouteTimer?.cancel();
    _rerouteTimer = null;

    // Restart normal location tracking
    getCurrentLocation();
  }

  Future<void> _getDirections() async {
    if (_currentP == null || _googleApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Maps API key not configured')),
      );
      return;
    }

    if (_selectedLocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one destination')),
      );
      return;
    }

    // Start navigation mode
    setState(() {
      _isNavigating = true;
      _hasArrived = false;
    });

    // Calculate distances and sort selected locations by proximity
    List<Map<String, dynamic>> sortedDestinations = [];
    for (int i = 0; i < _selectedLocations.length; i++) {
      double distance = Geolocator.distanceBetween(
        _currentP!.latitude,
        _currentP!.longitude,
        _selectedLocations[i].latitude,
        _selectedLocations[i].longitude,
      );
      sortedDestinations.add({
        'index': i,
        'position': _selectedLocations[i],
        'distance': distance,
      });
    }

    sortedDestinations.sort((a, b) => a['distance'].compareTo(b['distance']));

    // Set up navigation to first destination
    setState(() {
      _currentDestination = sortedDestinations[0]['position'];
      _remainingDestinations = sortedDestinations.sublist(1).map((dest) => dest['position'] as LatLng).toList();
    });

    // Navigate to first destination
    await _navigateToDestination(_currentP!, _currentDestination!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation started to destination ${sortedDestinations.length > 1 ? '(1 of ${sortedDestinations.length})' : ''}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<List<LatLng>> _getRoutePoints(LatLng origin, LatLng destination) async {
    String url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$_googleApiKey&mode=driving&alternatives=false';

    try {
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          var points = data['routes'][0]['overview_polyline']['points'];
          return _decodePolyline(points);
        }
      }
    } catch (e) {
      debugPrint('Error fetching directions: $e');
    }
    return [];
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void fitCameraToBounds() {
    if (_mapController == null || _polylines.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var polyline in _polylines) {
      for (var point in polyline.points) {
        minLat = minLat < point.latitude ? minLat : point.latitude;
        maxLat = maxLat > point.latitude ? maxLat : point.latitude;
        minLng = minLng < point.longitude ? minLng : point.longitude;
        maxLng = maxLng > point.longitude ? maxLng : point.longitude;
      }
    }

    // Include current location
    if (_currentP != null) {
      minLat = minLat < _currentP!.latitude ? minLat : _currentP!.latitude;
      maxLat = maxLat > _currentP!.latitude ? maxLat : _currentP!.latitude;
      minLng = minLng < _currentP!.longitude ? minLng : _currentP!.longitude;
      maxLng = maxLng > _currentP!.longitude ? maxLng : _currentP!.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50, // padding
      ),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _rerouteTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}