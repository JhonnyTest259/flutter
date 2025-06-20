import 'package:flutter/material.dart';
import 'package:location/location.dart';

class _LocationService {
  Future<Map<String, double?>?> obtenerCoordenadas(BuildContext context) async {
    Map<String, double?>? coords;
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    Location location = new Location();

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        _mostrarAlerta(context);
        return coords;
      }
    }
    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        // Error
        _mostrarAlerta(context);
        return coords;
      }
    }
    var posicion = await location.getLocation();
    coords = {};
    coords['lat'] = posicion.latitude;
    coords['lng'] = posicion.longitude;
    return coords;
  }

  void _mostrarAlerta(BuildContext context) {
    AlertDialog alert = AlertDialog(
      title: Text("Error"),
      content: Text("Error obteniendo coordenadas."),
      actions: [
        TextButton(
          child: Text("Aceptar"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}

final locationService = _LocationService();
