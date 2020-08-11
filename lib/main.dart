import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as json;
import 'package:just_debounce_it/just_debounce_it.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

String formatAddress(String name, dynamic addressJson) {
  var output = '';
  if (addressJson['line1'] != name) {
    output += addressJson['line1'];
    output += '\n';
  }
  if (addressJson['line2'] != null) {
    output += addressJson['line2'];
    output += '\n';
  }
  var extraParts = [];
  if (addressJson['town'] != null) {
    extraParts.add(addressJson['town']);
  }
  if (addressJson['county'] != null) {
    extraParts.add(addressJson['county']);
  }
  if (extraParts.isNotEmpty) {
    output += extraParts.join(', ');
    output += '\n';
  }
  if (addressJson['postcode'] != null) {
    output += addressJson['postcode'];
  }
  return output;
}

class _MyAppState extends State<MyApp> {
  final Map<String, Marker> _markers = {};
  GoogleMapController _controller;
  Position myPosition;

  @override
  void initState() {
    getCurrentLocation();
    super.initState();
  }

  void getCurrentLocation() async {
    var res = await Geolocator().getCurrentPosition();
    setState(() {
      myPosition = res;
    });
  }

  Future<void> _onMapCreatedOrChanged(GoogleMapController controller) async {
    _controller = controller;

    final visibleRegion = await controller.getVisibleRegion();
    final lat1 = visibleRegion.southwest.latitude;
    final lng1 = visibleRegion.southwest.longitude;
    final lat2 = visibleRegion.northeast.latitude;
    final lng2 = visibleRegion.northeast.longitude;
    final request = await http.get(
        'https://eat-out-help-out.herokuapp.com/query?lat1=$lat1&lng1=$lng1&lat2=$lat2&lng2=$lng2');
    final data = json.jsonDecode(request.body);
    await setState(() {
      _markers.clear();
      for (final result in data['results']) {
        final marker = Marker(
          markerId:
              MarkerId("${result['name']}-${result['lat']}-${result['lng']}"),
          position: LatLng(result['lat'], result['lng']),
          infoWindow: InfoWindow(
            title: result['name'],
            snippet: formatAddress(result['name'], result['address']),
          ),
        );
        _markers[result['name']] = marker;
      }
    });
  }

  void _onMapCreatedOrChangedDebounced(CameraPosition cameraPosition) async {
    Debounce.milliseconds(1000, _onMapCreatedOrChanged, [_controller]);
  }

  @override
  Widget build(BuildContext context) {
    final map = myPosition == null
        ? null
        : GoogleMap(
            onMapCreated: _onMapCreatedOrChanged,
            onCameraMove: _onMapCreatedOrChangedDebounced,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            initialCameraPosition: CameraPosition(
              target:
                  LatLng(myPosition.latitude ?? 0, myPosition.longitude ?? 0),
              zoom: 11.0,
            ),
            markers: _markers.values.toSet(),
          );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('eat out help out'),
          backgroundColor: Colors.blue[700],
        ),
        body: map,
      ),
    );
  }
}
