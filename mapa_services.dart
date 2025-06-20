import 'dart:convert';
import 'package:flutter_app/src/class/producto_class.dart';
import 'package:flutter_app/src/class/productos_class.dart';
import 'package:flutter_app/src/config/environment.dart';

import 'package:http/http.dart' as http;
import 'package:flutter_app/src/utils/preferences.dart';

class ServicioMapa {
  final _prefs = Preferences();

  Future<Map<String, dynamic>> getHuertas() async {
    final url = Env.buildURL('api/upz/ver-todas-app');

    final resp = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer ${_prefs.token}'},
    );
    try {
      Map<String, dynamic> decodedResp = json.decode(resp.body);

      if (decodedResp.containsKey('error')) {
        return {
          'codigo': decodedResp['error'],
          'descripcion': decodedResp['descripcion']
        };
      } else {
        if (decodedResp['codigo'] == 'OK') {
          return {
            'codigo': decodedResp['codigo'],
            'objeto': decodedResp['objeto_respuesta']
          };
        } else {
          return {
            'codigo': decodedResp['error'],
            'descripcion': decodedResp['descripcion']
          };
        }
      }
    } catch (e) {
      print(e.toString());
      return {};
    }
  }

  Future<Map<String, dynamic>> getHuertas500Metros({lat, double? lng}) async {
    final url = Env.buildURLAux(
        'ServiciosAppArboladoUrbano/api/getInfoHuertasProximas?pLongitud=$lng&pLatitud=$lat');

    final resp = await http.get(
      Uri.parse(url),
      //headers: {'Authorization': 'Bearer ${_prefs.token}'},
    );

    try {
      List<dynamic>? decodedResp = json.decode(resp.body);
      return {'codigo': 'OK', 'objeto': decodedResp};
    } catch (e) {
      print(e.toString());
      print(resp.body);
      return {'codigo': 'error', 'descripcion': e.toString()};
    }
  }

  Future<ProductosClass> getTodosProductos({lat, double? lng}) async {
    final url = Env.buildURLHuertas('api/productos/obtener-todos-especie');

    final resp = await http.get(
      Uri.parse(url),
      //headers: {'Authorization': 'Bearer ${_prefs.token}'},
    );

    // try {
    dynamic decodedResp = json.decode(resp.body);
    return ProductosClass.fromJson(decodedResp);
    // } catch (e) {
    //   print(e.toString());
    //   print(resp.body);
    //   return null;
    // }
  }

  Future<ProductosClass?> getHuertasPorProducto(String id) async {
    final url =
        Env.buildURLHuertas('api/huertas/obtener-todos-id-especie?id=$id');

    final resp = await http.get(
      Uri.parse(url),
      //headers: {'Authorization': 'Bearer ${_prefs.token}'},
    );

    try {
      dynamic decodedResp = json.decode(resp.body);
      return ProductosClass.fromJson(decodedResp);
    } catch (e) {
      print(e.toString());
      print(resp.body);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getHuertaPorId({int? id}) async {
    final url = Env.buildURLHuertas('api/huertas/obtener-por-id?id=$id');

    final resp = await http.get(
      Uri.parse(url),
      //headers: {'Authorization': 'Bearer ${_prefs.token}'},
    );

    // try {
    Map<String, dynamic>? decodedResp = json.decode(resp.body);
    return decodedResp;
    // } catch (e) {
    // print(e.toString());
    // return null;
    // }
  }

  Future<ProductoClass?> getProductosPorHuertaId(int? id) async {
    final url =
        Env.buildURLHuertas('api/productos/obtener-por-huerta?idHuerta=$id');

    final resp = await http.get(
      Uri.parse(url),
      //headers: {'Authorization': 'Bearer ${_prefs.token}'},
    );

    try {
      Map<String, dynamic> decodedResp = json.decode(resp.body);
      return ProductoClass.fromJson(decodedResp);
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> cargarLocalidades() async {
    // final resp = await http.get(
    //   Uri.parse(
    //       'http://20.114.225.188:8080/jardin-api/api/localidad/ver-por-perfiles'),
    //   headers: {'Authorization': 'Bearer ${_prefs.token}'},
    // );
    final url = Env.buildURL('api/localidad/ver-por-perfiles');
    final resp = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer ${_prefs.token}'},
    );

    Map<String, dynamic> decodedResp = json.decode(resp.body);
    print(decodedResp);
    try {
      List<Map<String, dynamic>> res =
          List<Map<String, dynamic>>.from(decodedResp['objeto_respuesta']);
      return res;
    } catch (e) {
      List<Map<String, dynamic>> res = List<Map<String, dynamic>>.from({});
      return res;
    }
  }

  Future<List<Map<String, dynamic>>> cargarUPZs() async {
    // final resp = await http.get(
    //   Uri.parse(
    //       'http://20.114.225.188:8080/jardin-api/api/upz/ver-por-perfiles'),
    //   headers: {'Authorization': 'Bearer ${_prefs.token}'},
    // );
    final url = Env.buildURL('api/upz/ver-por-perfiles');
    final resp = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer ${_prefs.token}'},
    );

    Map<String, dynamic> decodedResp = json.decode(resp.body);
    print("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
    print(decodedResp);
    try {
      List<Map<String, dynamic>> res =
          List<Map<String, dynamic>>.from(decodedResp['objeto_respuesta']);
      return res;
    } catch (e) {
      List<Map<String, dynamic>> res = List<Map<String, dynamic>>.from({});
      return res;
    }
  }

  Future<Map<String, dynamic>> filtrarHuertas(
      String codLoc, String codUpz, String? codTipo) async {
    final data = {'localidad': codLoc, 'upz': codUpz, 'tipoHuerta': codTipo};

    // final resp = await http.post(
    //     Uri.parse(
    //         'http://20.114.225.188:8080/jardin-api/api/huertas/listar-filtradas-gps'),
    //     headers: {
    //       'Authorization': 'Bearer ${_prefs.token}',
    //       'Content-Type': 'application/json'
    //     },
    //     body: json.encode(data));
    final url = Env.buildURL('api/huertas/listar-filtradas-gps');
    final resp = await http.post(Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${_prefs.token}',
          'Content-Type': 'application/json'
        },
        body: json.encode(data));

    Map<String, dynamic> decodedResp = json.decode(resp.body);

    if (decodedResp['codigo'] == 'OK') {
      return {
        'codigo': decodedResp['codigo'],
        'objeto': decodedResp['objeto_respuesta']
      };
    } else {
      return {
        'codigo': decodedResp['codigo'],
        'descripcion': decodedResp['descripcion']
      };
    }
  }

  Future<Map<String, dynamic>> getInfoLocalidadYUpz(
      double latitud, double longitud) async {
    final resp = await http.get(
      Uri.parse(
          'http://20.114.225.188/ServiciosAppArboladoUrbano/api/getLocalidadUPZ?pLongitud=$longitud&pLatitud=$latitud'),
    );

    Map<String, dynamic> decodedResp = json.decode(resp.body);

    if (decodedResp.length > 0) {
      return {'ok': true, 'informacionArbol': decodedResp};
    } else {
      return {'ok': false, 'mensaje': 'Error realizando la consulta'};
    }
  }
}
