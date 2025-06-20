import 'dart:async';
import 'dart:io';
import 'package:awesome_select/awesome_select.dart';
// import 'package:collection/collection.dart' show IterableNullableExtension;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/class/producto_class.dart';
import 'package:flutter_app/src/class/productos_class.dart';
import 'package:flutter_app/src/providers/auth_provider.dart';
import 'package:flutter_app/src/providers/dominios.dart';
import 'package:flutter_app/src/services/dominio.dart';
import 'package:flutter_app/src/services/storage.dart';
import 'package:flutter_app/src/core/widgets/menu.dart';

import 'package:hexcolor/hexcolor.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_app/src/utils/preferences.dart';

// import 'package:circular_menu/circular_menu.dart';
// import 'package:geolocator/geolocator.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:flutter_app/src/services/mapa_services.dart';
import 'package:dropdown_search/dropdown_search.dart';

import 'package:csv/csv.dart';
import 'package:provider/provider.dart';

class MapaInicial extends StatefulWidget {
  @override
  _MapaInicialState createState() => _MapaInicialState();
}

class _MapaInicialState extends State<MapaInicial> {
  final _prefs = Preferences();
  late BitmapDescriptor _marcadorHuerta;
  late LatLng _latLng;
  static List<Marker> customMarkers = [];
  late LocationData _locationData;
  static late BitmapDescriptor myIcon;
  static late BitmapDescriptor myIconAlt;
  static final servicioMapa = ServicioMapa();
  static String? localidadSeleccionada = '';
  static late BuildContext _context;
  static List<String> idHuertas = [];
  static List<Map<String, dynamic>> huertasTotales = [];
  Completer<GoogleMapController> _controller = Completer();
  MapType? _tipoMapa = MapType.normal;
  Location location = new Location();
  bool _esCarga = false;
  bool _visibleIndicador = true;
  bool _visibleUbicacion = true;
  bool _visibleTipoSMap = true;
  bool _visibleFadeInTipoMap = false;
  bool _visibleTipoMapas = false;
  bool _busquedaVisible = false;
  bool _busquedaVisibleBtn = true;
  bool _infoHuerta = false;
  bool? comercializacion = false;
  bool? redes = false;
  bool? espacioPublico = false;
  bool? rutas = false;
  String _codigo = '';
  String? _nombre = '';
  String _area = '';
  String _codigoUPZ = '';
  String? _localidad = '';
  String? _direccion = '';
  String _telefono = '';
  String _productos = '';
  String? _coordenadaX = '';
  String? _coordenadaY = '';

  List<dynamic>? _localidades = [];
  String? _seleccionLocalidad = '';

  List<dynamic>? _UPZs = [];
  String? _seleccionUPZ = '';

  String? _seleccionTipo = '';
  List<String> _tipoHuerta = [
    '',
    'Comercialización',
    'Redes',
    'Rutas',
    'Espacio público'
  ];

  Map<int, MapType> _mapas = {
    0: MapType.normal,
    1: MapType.satellite,
    2: MapType.terrain,
    3: MapType.hybrid,
  };

  List<List<dynamic>> _data = [];
  final Set<Polygon> _polygon = {};

  List<LatLng> latlngSegmentLocalidad = [];
  List<LatLng> polygonLatLongs = [];
  final Set<Polyline> _polyline = {};
  Map<dynamic, List<LatLng>> lstPolilines = {};
  List<String> lstUpz = [];
  List<LatLng> latlngSegmentUpz = [];
  // LatLng _lastMapPosition = LatLng(4.59680951, -74.08242253);
  String _codigoLocalidad = '';

  bool mostrarCardsIndicadores = false;

  static void filtrarHuertas(bool? comercializaProductos, String idProducto,
      VoidCallback callback, VoidCallback poblarLocalidades) {
    eliminarHuertas();
    servicioMapa.getHuertasPorProducto(idProducto).then((value) {
      idHuertas = value!.objetoRespuesta!.map((e) => e.id.toString()).toList();
      huertasTotales = value.objetoRespuesta!.map((e) => e.toJson()).toList();
      customMarkers.addAll(value.objetoRespuesta!.map<Marker?>((e) {
        if (comercializaProductos!) {
          if (e.tieneVisitaComercializacion!) {
            return Marker(
              markerId: MarkerId(
                e.id.toString(),
              ),
              position:
                  LatLng(double.parse(e.latitud!), double.parse(e.longitud!)),
              icon: e.mercadosCampesinos != null && e.mercadosCampesinos!
                  ? myIconAlt
                  : myIcon,
              infoWindow: InfoWindow(
                title: e.nombre,
                snippet: e.localidad,
              ),
              onTap: () {
                // Aquí puedes manejar la acción al tocar el marcador, como mostrar un diálogo.
                _showDialog(e.nombre, e.id, e.mercadosCampesinos, _context);
              },
            );
          }
          return null;
        } else {
          return Marker(
            markerId: MarkerId(
              e.id.toString(),
            ),
            position:
                LatLng(double.parse(e.latitud!), double.parse(e.longitud!)),
            icon: e.mercadosCampesinos != null && e.mercadosCampesinos!
                ? myIconAlt
                : myIcon,
            infoWindow: InfoWindow(
              title: e.nombre,
              snippet: e.localidad,
            ),
            onTap: () {
              // Aquí puedes manejar la acción al tocar el marcador, como mostrar un diálogo.
              _showDialog(e.nombre, e.id, e.mercadosCampesinos, _context);
            },
          );
        }
      }).whereType<Marker>());
      callback();
      poblarLocalidades();
    });
  }

  @override
  void initState() {
    super.initState();
    // después del primer frame, intentamos cargar o re-sincronizar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrSyncDominios();
    });
    _context = context;
    _validarToken();
    ubicarUsuario();
    cargarIconos();
  }

  Future<void> _loadOrSyncDominios() async {
    final mapa = await storageService.leerArchivoDominios();
    final provider = Provider.of<DominioProvider>(context, listen: false);
    if (mapa.isEmpty) {
      // si no había datos, forzamos sincronizar
      await dominioService.sincronizarDominios(context);
      // y recargamos desde disco
      final nuevos = await storageService.leerArchivoDominios();
      provider.dominios = nuevos;
    } else {
      // ya había algo: simplemente lo cargamos al provider
      provider.dominios = mapa;
    }
  }

  void cargarIconos() {
    BitmapDescriptor.asset(
            ImageConfiguration(
              size: Size(8, 8),
            ),
            'assets/icon/huerta_icon_sm.png')
        .then(
      (onValue) {
        myIcon = onValue;
      },
    );
    BitmapDescriptor.asset(
            ImageConfiguration(
              size: Size(8, 8),
            ),
            'assets/icon/huerta_icon_alt_sm.png')
        .then(
      (onValue) {
        myIconAlt = onValue;
      },
    );
  }

  void _validarToken() async {
    // se valida servicio para el estado de token
    final servicioMapa = ServicioMapa();
    Map<String, dynamic> respuestaToken = await servicioMapa.getHuertas();
    if (_prefs.token != '' && respuestaToken['codigo'] == 'invalid_token') {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('No se puede acceder a la funcionalidad'),
            content: Text('Señor usuario usted debe iniciar sesión.'),
            actions: <Widget>[
              TextButton(
                child: Text('Aceptar'),
                onPressed: () {
                  Provider.of<AuthProvider>(context, listen: false).logout();
                  Navigator.pushReplacementNamed(context, 'login');
                },
              ),
            ],
          );
        },
      );
    } else {
      location = new Location();
      _getUserLocation();

      _marcadorInicial();
      _tipoMapa = _mapas[_prefs.tipoMapa];
      _latLng = LatLng(4.59680951, -74.08242253);

      _getHuertas();
    }
  }

  @override
  Widget build(BuildContext context) {
    // final circularMenu = CircularMenu(
    //     toggleButtonSize: 35,
    //     toggleButtonColor: HexColor("#20a01d"),
    //     radius: 120,
    //     alignment: Alignment.bottomLeft,
    //     items: [
    //       CircularMenuItem(
    //         onTap: () {
    //           _tipoMapa = MapType.normal;
    //           _prefs.tipoMapa = 0;
    //           setState(() {});
    //         },
    //         icon: Icons.my_location,
    //         color: Colors.blue.withValues(alpha: 0.7),
    //       ),
    //       CircularMenuItem(
    //           icon: Icons.share_location,
    //           color: Colors.grey.withValues(alpha: 0.7),
    //           onTap: () {
    //             _tipoMapa = MapType.satellite;
    //             _prefs.tipoMapa = 1;
    //             setState(() {});
    //           }),
    //       CircularMenuItem(
    //           icon: Icons.add_location_rounded,
    //           color: Colors.brown.withValues(alpha: 0.7),
    //           onTap: () {
    //             _tipoMapa = MapType.terrain;
    //             _prefs.tipoMapa = 2;
    //             setState(() {});
    //           }),
    //       CircularMenuItem(
    //           icon: Icons.map_rounded,
    //           color: Colors.red.withValues(alpha: 0.7),
    //           onTap: () {
    //             _tipoMapa = MapType.hybrid;
    //             _prefs.tipoMapa = 3;
    //             setState(() {});
    //           }),
    //     ]);

    // return WillPopScope(
    //   onWillPop: (() => exit(0)) as Future<bool> Function()?,
    //   child: Scaffold(
    //     appBar: AppBar(
    //       title: Text('APP AGRICULTURA URBANA'),
    //       backgroundColor: HexColor("#20a01d").withValues(alpha: 0.8),
    //       actions: [Menu()],
    //       automaticallyImplyLeading: false,
    //     ),
    //     body: WillPopScope(
    //         onWillPop: () async => false, child: SafeArea(child: _contenido())),
    //   ),
    // );
    return PopScope<Object?>(
      // Prevent the automatic pop…
      canPop: false,
      // …and handle back (gesture or button) with result-aware callback:
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        // If pop was blocked (didPop == false), do your custom logic:
        if (!didPop) {
          // e.g. close the app “the Flutter way”
          SystemNavigator.pop();
        }
        // If didPop == true, the route was already popped—nothing else to do.
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('APP AGRICULTURA URBANA'),
          backgroundColor: HexColor("#20a01d").withValues(alpha: 0.8),
          actions: [Menu()],
          automaticallyImplyLeading: false,
        ),
        body: PopScope<Object?>(
          // Inner PopScope to lock back within the body
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            // No-op: always block
          },
          child: SafeArea(child: _contenido()),
        ),
      ),
    );
  }

  void _getUserLocation() async {
    // Position position = await Geolocator().getCurrentPosition();
    // Position position = await Geolocator.getCurrentPosition();
  }

  void _marcadorInicial() async {
    String os = Platform.operatingSystem; //in your code
    print(os);

    BitmapDescriptor.asset(
            ImageConfiguration(),
            os == 'ios'
                ? 'assets/mapa/ubicacion-iphone.png'
                : 'assets/mapa/ubicacion.png')
        .then((value) {
      // _marcadorPrincipal = value;
    });

    BitmapDescriptor.asset(ImageConfiguration(),
            os == 'ios' ? 'assets/mapa/huerta.png' : 'assets/mapa/huerta.png')
        .then((value) {
      _marcadorHuerta = value;
    });
  }

  void filtrarPorLocalidad() {
    eliminarHuertas();
    List<Map<String, dynamic>> huertas = huertasTotales
        .where((element) => element['localidad'] == localidadSeleccionada)
        .toList();
    idHuertas = huertas.map((e) => e['id'].toString()).toList();
    agregarMarcadorHuerta(huertas);
  }

  Widget _contenido() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(child: _validarMapa()),
              Visibility(
                visible: _visibleIndicador,
                child: Center(child: _capturaLocalizacion()),
              ),
              Visibility(
                visible: _infoHuerta,
                child: Container(
                    margin: EdgeInsets.all(10.0), child: _opcionesHuerta()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                      child: Container(
                          //color: Colors.red,
                          )),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        color: Colors.red,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: _floatActionButton(),
                      ),
                    ],
                  ),
                ],
              ),
              _tiposMapa(),
              _prefs.token == '' ? Center() : _filtrarCampos(),
              Positioned(
                  child: ExpansionPanelFiltro(() {
                setState(() {});
              }, filtrarPorLocalidad)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _validarMapa() {
    if (_esCarga == false) {
      return _cargarMapaVacio();
    } else {
      return _cargarMapaPosicion();
    }
  }

  Widget _cargarMapaVacio() {
    Future.delayed(Duration(seconds: 10), () {
      setState(() {});
    });

    return GoogleMap(
      onLongPress: (lat) {
        // print(lat);
        _obtenerLocalizacionBusqueda(lat.latitude, lat.longitude);
      },
      compassEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      polylines: _polyline,
      polygons: _polygon,
      mapType: _tipoMapa!,
      markers: customMarkers.toSet(),
      initialCameraPosition: CameraPosition(
        bearing: 0,
        target: LatLng(4.59680951, -74.12),
        zoom: 10.5,
        tilt: 1.0,
      ),
      onMapCreated: (GoogleMapController controller) {
        _controller.complete(controller);
      },
    );
  }

  Widget _cargarMapaPosicion() {
    final CameraPosition _kGooglePlex = CameraPosition(
      bearing: 0,
      tilt: 1.0,
      target: _latLng,
      zoom: 10.5,
    );

    // customMarkers.add(Marker(
    //     markerId: MarkerId('geo-location'),
    //     position: _latLng,
    //     icon: _marcadorPrincipal));

    Set<Circle> circle = Set<Circle>();
    circle.add(new Circle(
        circleId: CircleId("geo-location"),
        radius: 130.0,
        zIndex: 1,
        strokeColor: Colors.blue,
        strokeWidth: 1,
        center: _latLng,
        fillColor: Colors.blue.withValues(alpha: 40)));

    return GoogleMap(
      onLongPress: (latlng) {
        // print(lat);
        _obtenerLocalizacionBusqueda(latlng.latitude, latlng.longitude);
        obtenerHuertas500Metros(LatLng(latlng.latitude, latlng.longitude));
      },
      compassEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      polylines: _polyline,
      polygons: _polygon,
      mapType: _tipoMapa!,

      markers: customMarkers.toSet(),
      //circles: circle,
      initialCameraPosition: _kGooglePlex,
      onMapCreated: (GoogleMapController controller) {
        _controller.complete(controller);
      },
    );
  }

  static void eliminarHuertas() {
    customMarkers.removeWhere(
        (Marker marker) => idHuertas.contains(marker.markerId.value));
  }

  Future<void> obtenerHuertas500Metros(LatLng latLng) async {
    Map<String, dynamic> respuesta = await servicioMapa.getHuertas500Metros(
        lat: latLng.latitude, lng: latLng.longitude);

    if (respuesta['codigo'] == 'OK') {
      List<dynamic> huertas = respuesta['objeto'];
      eliminarHuertas();
      idHuertas = huertas.map((e) => e['id'].toString()).toList();
      agregarMarcadorHuerta(huertas);
    }
  }

  void agregarMarcadorHuerta(List<dynamic> huertas) {
    customMarkers.addAll(huertas.map<Marker>((e) => Marker(
          markerId: MarkerId(
            e['id'].toString(),
          ),
          position: LatLng(double.parse(e['latitud'].toString()),
              double.parse(e['longitud'].toString())),
          icon: e['mercados_campesinos'] != null && e['mercados_campesinos']
              ? myIconAlt
              : myIcon,
          infoWindow: InfoWindow(
            title: e['nombre'],
            snippet: e['nombre_localidad'],
          ),
          onTap: () {
            // Aquí puedes manejar la acción al tocar el marcador, como mostrar un diálogo.
            _showDialog(
                e['nombre'], e['id'], e['mercados_campesinos'], _context);
          },
        )));
    setState(() {});
  }

  static void _showDialog(
      String? title, int? id, bool? mercadosCampesinos, BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title!),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: FutureBuilder(
                future: servicioMapa.getHuertaPorId(id: id),
                builder: (context, AsyncSnapshot<dynamic> snapshot) {
                  if (snapshot.hasData) {
                    return InfoHuerta(
                        snapshot.data, servicioMapa, mercadosCampesinos);
                  } else {
                    return Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                },
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _capturaLocalizacion() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LoadingIndicator(
          indicatorType: Indicator.orbit,
          colors: [Color(0xAA6EB1E6)],
        ),
      ],
    );
  }

  Widget _tiposMapa() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: Container(),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 7.0),
          child: Align(
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                  child: Visibility(
                      visible: _visibleTipoSMap, child: _opcionesMapas()))),
        ),
        SizedBox(height: 5.0)
      ],
    );
  }

  Widget _opcionesMapas() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.7),
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              topLeft: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.all(8.0),
          child: Column(
            children: [
              AnimatedOpacity(
                // If the widget is visible, animate to 0.0 (invisible).
                // If the widget is hidden, animate to 1.0 (fully visible).
                opacity: _visibleFadeInTipoMap ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
                // The green box must be a child of the AnimatedOpacity widget.
                child: Visibility(
                  visible: _visibleTipoMapas,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          _tipoMapa = MapType.normal;
                          _prefs.tipoMapa = 0;
                          setState(() {});
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: Colors.blue.withValues(alpha: 0.7),
                          ),
                          height: 40,
                          width: 40,
                          child: Container(
                            child: Image(
                              image: AssetImage(
                                  'assets/mapa/MapaVista-Normal.png'),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 1.0,
                      ),
                      Text('Normal',
                          style: TextStyle(fontSize: 8.0, color: Colors.white)),
                      SizedBox(
                        height: 5.0,
                      ),
                      InkWell(
                        onTap: () {
                          _tipoMapa = MapType.satellite;
                          _prefs.tipoMapa = 1;
                          setState(() {});
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: Colors.grey.withValues(alpha: 0.9),
                          ),
                          height: 40,
                          width: 40,
                          child: Container(
                            child: Image(
                              image: AssetImage(
                                  'assets/mapa/MapaVista-Satelital.png'),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 1.0,
                      ),
                      Text('Satelital',
                          style: TextStyle(fontSize: 8.0, color: Colors.white)),
                      SizedBox(
                        height: 5.0,
                      ),
                      InkWell(
                        onTap: () {
                          _tipoMapa = MapType.terrain;
                          _prefs.tipoMapa = 2;
                          setState(() {});
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: Colors.brown.withValues(alpha: 0.7),
                          ),
                          height: 40,
                          width: 40,
                          child: Container(
                            child: Image(
                              image: AssetImage(
                                  'assets/mapa/MapaVista-Terreno.png'),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 1.0,
                      ),
                      Text('Terreno',
                          style: TextStyle(fontSize: 8.0, color: Colors.white)),
                      SizedBox(
                        height: 5.0,
                      ),
                      InkWell(
                        onTap: () {
                          _tipoMapa = MapType.hybrid;
                          _prefs.tipoMapa = 3;
                          setState(() {});
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: Colors.red.withValues(alpha: 0.7),
                          ),
                          height: 40,
                          width: 40,
                          child: Container(
                            child: Image(
                              image: AssetImage(
                                  'assets/mapa/MapaVista-Hibrido.png'),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 1.0,
                      ),
                      Text('Híbrido',
                          style: TextStyle(fontSize: 8.0, color: Colors.white)),
                      SizedBox(
                        height: 13.0,
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  _visibleTipoMapas = !_visibleTipoMapas;
                  _visibleFadeInTipoMap = !_visibleFadeInTipoMap;
                  setState(() {});
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    color: HexColor("#20a01d").withValues(alpha: 0.8),
                  ),
                  height: 40,
                  width: 40,
                  child: Container(
                    child: _visibleTipoMapas == false
                        ? Icon(Icons.map_rounded, color: Colors.white)
                        : Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _floatActionButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Visibility(
          visible: _visibleUbicacion,
          child: Center(
              child: InkWell(
                  onTap: () async {
                    _visibleIndicador = true;
                    await ubicarUsuario();
                  },
                  child: _buscarUbicacion())),
        ),
      ],
    );
  }

  Future<void> ubicarUsuario() async {
    setState(() {});
    _locationData = await location.getLocation();

    _latLng = LatLng(_locationData.latitude!, _locationData.longitude!);
    //customMarkers = [];
    _obtenerLocalizacionBusqueda(
        _locationData.latitude!, _locationData.longitude!);
  }

  Widget _buscarUbicacion() {
    final size = MediaQuery.of(context).size;

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        Container(
          margin: EdgeInsets.only(right: 39),
          height: 40,
          width: size.width * 0.4,
          decoration: BoxDecoration(
            color: HexColor("#20a01d").withValues(alpha: 0.9),
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              topLeft: Radius.circular(20),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'Capturar Ubicación',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Image(
            image: AssetImage('assets/mapa/localizacion.png'),
            width: 68,
          ),
        ),
      ],
    );
  }

  void _obtenerLocalizacionBusqueda(double latitud, double longitud) async {
    _visibleIndicador = true;
    _esCarga = true;
    setState(() {});

    final GoogleMapController mapController = await _controller.future;
    mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
            bearing: 0,
            tilt: 1.0,
            target: LatLng(latitud, longitud),
            zoom: 12.0),
      ),
    );

    //await _getHuertas(); //pendiente de servicio

    customMarkers.add(Marker(
      markerId: MarkerId('geo-location-ubicacion'),
      position: LatLng(latitud, longitud),
    ));

    mostrarCardsIndicadores = true;
    _getInfoLocalidadYUpz(latitud, longitud);
  }

  Future<void> _getInfoLocalidadYUpz(double latitud, double longitud) async {
    Map<String, dynamic> respuesta =
        await servicioMapa.getInfoLocalidadYUpz(latitud, longitud);

    if (respuesta['ok']) {
      if (respuesta['informacionArbol']['Nombre_localidad'] != "") {
        _prefs.valorLocIndicadores =
            respuesta['informacionArbol']['Nombre_localidad'];
        _prefs.valorUPZindicadores =
            respuesta['informacionArbol']['Nombre_upz'];

        _loadCSV(respuesta['informacionArbol']['Codigo_localidad'],
            respuesta['informacionArbol']['Codigo_upz']);
      } else {
        _visibleIndicador = false;
        setState(() {});
      }
    }
  }

  void _loadCSV(codigoLocalidad, codigoUpz) async {
    print('cod localidad: ' + codigoLocalidad + ' cod upz: ' + codigoUpz);

    final _rawDataLocalidad =
        await rootBundle.loadString("assets/LOCALIDAD.csv");
    List<List<dynamic>> _listDataLocalidad =
        CsvToListConverter().convert(_rawDataLocalidad);
    _data = _listDataLocalidad;

    latlngSegmentLocalidad.clear();
    polygonLatLongs.clear();

    _data.forEach((element) {
      List<dynamic> dato = element[0].toString().split(';');
      if (dato[1] == codigoLocalidad) {
        LatLng latLocalidad =
            LatLng(double.parse(dato[3]), double.parse(dato[2]));
        latlngSegmentLocalidad.add(latLocalidad);
        polygonLatLongs.add(latLocalidad);
      }
    });

    final _rawDataUpz = await rootBundle.loadString("assets/UPZ.csv");
    List<List<dynamic>> _listData = CsvToListConverter().convert(_rawDataUpz);
    _data = _listData;

    if (_codigoLocalidad != '') {
      if (_codigoLocalidad != codigoLocalidad) {
        _polyline.clear();
      }
    }
    lstPolilines.addAll({
      '$codigoUpz-$codigoLocalidad': [],
    });

    lstUpz.add('$codigoUpz-$codigoLocalidad');

    _data.forEach((element) {
      List<dynamic> dato = element[0].toString().split(';');
      if (dato[1] == codigoUpz) {
        LatLng lat = LatLng(double.parse(dato[3]), double.parse(dato[2]));
        latlngSegmentUpz.add(lat);
        lstPolilines['$codigoUpz-$codigoLocalidad']?.add(lat);
        // _lastMapPosition = lat;
      }
    });

    lstUpz.forEach((element) {
      if ('$codigoUpz-$codigoLocalidad' == element) {
        _polyline.add(Polyline(
          polylineId: PolylineId('line$codigoUpz'),
          visible: true,
          points: lstPolilines[element]!,
          width: 2,
          color: Colors.green,
        ));
      }
    });

    _polygon.add(Polygon(
        polygonId: PolygonId('polygono'),
        visible: true,
        points: polygonLatLongs,
        strokeColor: Colors.red,
        fillColor: Colors.green.withValues(alpha: 0.1),
        strokeWidth: 2));

    _codigoLocalidad = codigoLocalidad;
    _visibleIndicador = false;
    setState(() {});
  }

  Future<void> _getHuertas() async {
    final servicioMapa = ServicioMapa();
    Map<String, dynamic> respuesta = await servicioMapa.getHuertas();

    if (respuesta['codigo'] == 'OK') {
      customMarkers = [];
      List<dynamic> listaMapa = respuesta['objeto'];
      listaMapa.forEach((element) {
        Map<String, dynamic>? huerta = element['huerta'];
        if (huerta != null) {
          List<dynamic>? productosHuerta = element['productosHuerta'];

          customMarkers.add(Marker(
              infoWindow: InfoWindow(
                  title: '${huerta['nombre']}',
                  snippet: 'Código : ${huerta['id']}',
                  onTap: () async {
                    _visibleTipoSMap = false;
                    _busquedaVisibleBtn = false;
                    _busquedaVisible = false;
                    _visibleUbicacion = false;

                    _codigo = huerta['id'].toString();
                    _nombre = huerta['nombre'];
                    _area = huerta['area'].toString();
                    _codigoUPZ = huerta['upzHuerta']['id'].toString() +
                        ' - ' +
                        huerta['upzHuerta']['nombre'];
                    _localidad = huerta['localidad']['nombre'];
                    _direccion = huerta['direccionHuerta'];
                    _telefono = huerta['cliente']['telefonoAdultoAcompanante']
                        .toString();

                    _coordenadaX = huerta['latitud'];
                    _coordenadaY = huerta['longitud'];

                    _productos = '';
                    productosHuerta!.forEach((value) {
                      _productos = _productos + '\n' + value;
                    });

                    comercializacion = element['comercializa'];
                    redes = huerta['redAgricultores'];
                    espacioPublico = element['espacioPublico'];
                    rutas = huerta['tieneCualidadesRutaAgro'];

                    _cargarOpciones();
                  }),
              markerId: MarkerId('geo-location-${huerta['id']}'),
              position: LatLng(
                  huerta['latitud'] == ""
                      ? 0.0
                      : double.parse(huerta['latitud']),
                  huerta['longitud'] == ""
                      ? 0.0
                      : double.parse(huerta['longitud'])),
              icon: _marcadorHuerta));
        }
      });
      _esCarga = true;
      _visibleIndicador = false;
      setState(() {});
    } else {
      _visibleIndicador = false;
      setState(() {});
    }
  }

  void _cargarOpciones() {
    _infoHuerta = true;

    setState(() {});
  }

  Widget _filtrarCampos() {
    return Container(
      margin: EdgeInsets.only(top: 70),
      child: Column(
        children: [
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: Container()),
                  Padding(
                      padding: const EdgeInsets.only(right: 7.0),
                      child: Align(
                          alignment: Alignment.topLeft,
                          child: SingleChildScrollView(
                              child: Visibility(
                                  visible: _busquedaVisibleBtn,
                                  child: _filtrar())))),
                ],
              ),
            ],
          ),
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    topLeft: Radius.circular(20),
                  ),
                ),
                child: Visibility(
                    visible: _busquedaVisible,
                    child: Padding(
                        padding: const EdgeInsets.all(8.0), child: _campos())),
              ),
            ],
          ),
          Visibility(
            visible: _busquedaVisibleBtn,
            child: Row(
              children: [
                Expanded(child: Container()),
                _floatActionButtonLocalidad(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _filtrar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: CircleAvatar(
        backgroundColor: Colors.blue,
        child: IconButton(
          onPressed: () {
            if (_busquedaVisible) {
              _busquedaVisible = false;
              _visibleTipoSMap = true;
              _visibleUbicacion = true;
            } else {
              _busquedaVisible = true;
              _visibleTipoSMap = false;
              _visibleUbicacion = false;
            }

            setState(() {});
          },
          icon: Icon(
            Icons.search,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _campos() {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Container(
          //height: size.height * 0.6,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(
                Radius.circular(20.0),
              ),
            ),
            elevation: 9,
            color: Colors.white,
            child: Container(
              width: size.width,
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  children: [
                    _campoLocalidad(),
                    SizedBox(
                      height: 20.0,
                    ),
                    _campoUPZ(),
                    SizedBox(
                      height: 20.0,
                    ),
                    _campoTipoHuerta(),
                    SizedBox(
                      height: 20.0,
                    ),
                    _btnGuardar()
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoLocalidad() {
    // String selectedItemValue = "Localidad";
    final servicioMapa = ServicioMapa();

    return FutureBuilder(
      future: servicioMapa.cargarLocalidades(),
      builder: (BuildContext context,
          AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        if (snapshot.hasData) {
          if (snapshot.data!.length > 0) {
            _localidades = snapshot.data;
            // return Row(
            //       children: <Widget>[
            //         Expanded(
            //             child: DropdownSearch<String>(
            //           mode: Mode.DIALOG,
            //           showSelectedItem: true,
            //           label: "Localidad:",
            //           items: getLocalidades(),
            //           onChanged: (opt) {
            //             setState(() {
            //               _seleccionLocalidad = opt;
            //             });
            //           },
            //           dropdownSearchBaseStyle: TextStyle(fontSize: 13.0),
            //           searchBoxStyle: TextStyle(fontSize: 15.0),
            //           selectedItem: _seleccionLocalidad,
            //           showSearchBox: true,
            //           searchFieldProps: TextFieldProps(
            //             decoration: InputDecoration(
            //               border: OutlineInputBorder(),
            //               contentPadding: EdgeInsets.fromLTRB(12, 12, 8, 0),
            //               labelText: "Buscar localidad",
            //             ),
            //           ),
            //         ))
            //       ],
            //     ) ??
            return Row(
              children: <Widget>[
                Expanded(
                    child: DropdownSearch<String>(
                  // 1. Provisión de ítems (sincronía)
                  items: (filter, loadProps) => getLocalidades(),

                  // 2. Ítem inicial y callback de selección
                  selectedItem: _seleccionLocalidad,
                  onChanged: (opt) => setState(() {
                    _seleccionLocalidad = opt;
                  }),

                  // 3. Decoración del campo cerrado (reemplaza `label` y estilos base)
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: "Localidad:",
                      border: OutlineInputBorder(),
                      // aquí podrías añadir estilo de texto si lo necesitas:
                      // hintStyle: TextStyle(fontSize: 13),
                    ),
                  ),

                  // 4. Configuración del popup como diálogo con búsqueda
                  popupProps: PopupProps.dialog(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.fromLTRB(12, 12, 8, 0),
                        labelText: "Buscar localidad",
                      ),
                    ),
                    // Opcional: ajusta fit, scroll infinito, título, etc.
                  ),
                ))
              ],
            );
            // ??
            // Container();
          } else {
            return Container();
          }
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _campoUPZ() {
    // String selectedItemValue = "UPZ";
    final servicioMapa = ServicioMapa();

    return FutureBuilder(
      future: servicioMapa.cargarUPZs(),
      builder: (BuildContext context,
          AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        if (snapshot.hasData) {
          if (snapshot.data!.length > 0) {
            _UPZs = snapshot.data;
            // return Row(
            //       children: <Widget>[
            //         Expanded(
            //             child: DropdownSearch<String>(
            //           mode: Mode.DIALOG,
            //           showSelectedItem: true,
            //           label: "UPZ:",
            //           items: getUPZs(),
            //           onChanged: (opt) {
            //             setState(() {
            //               _seleccionUPZ = opt;
            //             });
            //           },
            //           dropdownSearchBaseStyle: TextStyle(fontSize: 13.0),
            //           searchBoxStyle: TextStyle(fontSize: 15.0),
            //           selectedItem: _seleccionUPZ,
            //           showSearchBox: true,
            //           searchFieldProps: TextFieldProps(
            //             decoration: InputDecoration(
            //               border: OutlineInputBorder(),
            //               contentPadding: EdgeInsets.fromLTRB(12, 12, 8, 0),
            //               labelText: "Buscar UPZ",
            //             ),
            //           ),
            //         ))
            //       ],
            //     ) ??
            return Row(
              children: <Widget>[
                Expanded(
                    child: DropdownSearch<String>(
                  // 1. Provisión de ítems (sincronía o asincronía)
                  items: (filter, loadProps) => getUPZs(),

                  // 2. Valor inicial y callback de selección
                  selectedItem: _seleccionUPZ,
                  onChanged: (opt) => setState(() {
                    _seleccionUPZ = opt;
                  }),

                  // 3. Decoración del campo cerrado
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: "UPZ:",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  // 4. Configuración del popup como diálogo con búsqueda
                  popupProps: PopupProps.dialog(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.fromLTRB(12, 12, 8, 0),
                        labelText: "Buscar UPZ",
                      ),
                    ),
                  ),
                ))
              ],
            );
            // ??
            // Container();
          } else {
            return Container();
          }
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _campoTipoHuerta() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        // Expanded(
        //     child: DropdownSearch<String>(
        //   mode: Mode.DIALOG,
        //   showSelectedItem: true,
        //   label: "Tipo huerta:",
        //   items: _tipoHuerta,
        //   onChanged: (opt) {
        //     setState(() {
        //       _seleccionTipo = opt;
        //     });
        //   },
        //   dropdownSearchBaseStyle: TextStyle(fontSize: 13.0),
        //   searchBoxStyle: TextStyle(fontSize: 15.0),
        //   selectedItem: _seleccionTipo,
        //   showSearchBox: true,
        // ))
        Expanded(
            child: DropdownSearch<String>(
          // 1. Provisión de ítems (sincronía)
          items: (filter, loadProps) => _tipoHuerta,

          // 2. Valor inicial y callback de selección
          selectedItem: _seleccionTipo,
          onChanged: (opt) => setState(() {
            _seleccionTipo = opt;
          }),

          // 3. Decoración del campo cerrado
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              labelText: "Tipo huerta:",
              border: OutlineInputBorder(),
            ),
          ),

          // 4. Configuración del popup como diálogo con búsqueda
          popupProps: PopupProps.dialog(
            showSearchBox: true,
            // Si quisieras customizar la caja de búsqueda, puedes añadir aquí searchFieldProps
          ),
        ))
      ],
    );
  }

  List<String> getLocalidades() {
    List<String> lista = [];

    _localidades!.forEach((tipo) {
      lista.add('${tipo['id']} - ${tipo['nombre']}');
    });

    return lista;
  }

  List<String> getUPZs() {
    List<String> lista = [];

    _UPZs!.forEach((tipo) {
      lista.add('${tipo['id']} - ${tipo['nombre']}');
    });

    return lista;
  }

  Widget _btnGuardar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        new ElevatedButton(
            // color: Colors.redAccent,
            // textColor: Colors.white,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all<Color>(Colors.redAccent),
              textStyle:
                  WidgetStateProperty.all(TextStyle(color: Colors.white)),
            ),
            child: Row(children: <Widget>[
              Text("Limpiar búsqueda", style: TextStyle(fontSize: 15.0)),
              // Icon(Icons.save_outlined),
            ]),
            onPressed: () {
              _limpiarFormulario();
            }),
        SizedBox(width: 5.0),
        new ElevatedButton(
            // color: Colors.green,
            // textColor: Colors.white,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all<Color>(Colors.green),
              textStyle:
                  WidgetStateProperty.all(TextStyle(color: Colors.white)),
            ),
            child: Row(children: <Widget>[
              Text("Buscar", style: TextStyle(fontSize: 13.0)),
              // Icon(Icons.save_outlined),
            ]),
            onPressed: () {
              // aca
              _visibleIndicador = true;
              setState(() {});
              _buscarHuertas();
            }),
      ],
    );
  }

  void _limpiarFormulario() {
    _visibleIndicador = true;
    setState(() {});
    _seleccionLocalidad = '';
    _seleccionUPZ = '';
    _seleccionTipo = '';
    _getHuertas();
  }

  Future<void> _buscarHuertas() async {
    List codLoc = _seleccionLocalidad!.split(' -');
    String codLocString = codLoc[0];

    List codUpz = _seleccionUPZ!.split(' -');
    String codUpzString = codUpz[0];

    String? codTipoString = '';

    if (_seleccionTipo != '') {
      List codTipo = _seleccionTipo!.split('');
      codTipoString = codTipo[0] + codTipo[1];

      codTipoString = codTipoString!.toLowerCase();

      if (codTipoString == 'es') {
        codTipoString = 'ep';
      }
    }

    final servicioMapa = ServicioMapa();
    Map<String, dynamic> respuesta = await servicioMapa.filtrarHuertas(
        codLocString, codUpzString, codTipoString);

    if (respuesta['codigo'] == 'OK') {
      customMarkers = [];
      List<dynamic> listaMapa = respuesta['objeto'];
      listaMapa.forEach((element) {
        Map<String, dynamic> huerta = element['huerta'];
        List<dynamic>? productosHuerta = element['productosHuerta'];

        customMarkers.add(Marker(
            infoWindow: InfoWindow(
                title: '${huerta['nombre']}',
                snippet: 'Código : ${huerta['id']}',
                onTap: () async {
                  _visibleTipoSMap = false;
                  _busquedaVisibleBtn = false;
                  _busquedaVisible = false;
                  _visibleUbicacion = false;

                  _codigo = huerta['id'].toString();
                  _nombre = huerta['nombre'];
                  _area = huerta['area'].toString();
                  _codigoUPZ = huerta['upzHuerta']['id'].toString() +
                      ' - ' +
                      huerta['upzHuerta']['nombre'];
                  _localidad = huerta['localidad']['nombre'];
                  _direccion = huerta['direccionHuerta'];
                  _telefono =
                      huerta['cliente']['telefonoAdultoAcompanante'].toString();

                  _coordenadaX = huerta['latitud'];
                  _coordenadaY = huerta['longitud'];

                  _productos = '';
                  productosHuerta!.forEach((value) {
                    _productos = _productos + '\n' + value;
                  });

                  comercializacion = element['comercializa'];
                  redes = huerta['redAgricultores'];
                  espacioPublico = element['espacioPublico'];
                  rutas = huerta['tieneCualidadesRutaAgro'];

                  _cargarOpciones();
                }),
            markerId: MarkerId('geo-location-${huerta['id']}'),
            position: LatLng(double.parse(huerta['latitud']),
                double.parse(huerta['longitud'])),
            icon: _marcadorHuerta));
      });
      _esCarga = true;
      _visibleIndicador = false;
      setState(() {});
    } else {
      _visibleIndicador = false;
      setState(() {});
    }
  }

  Widget _opcionesHuerta() {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Container(
          height: size.height * 0.9,
          child: ListView(
            children: [
              Container(
                height: size.height * 0.8,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(20.0),
                    ),
                  ),
                  elevation: 9,
                  //color: HexColor("#20a01d").withValues(alpha:0.4),
                  color: Colors.white.withValues(alpha: 0.8),
                  child: Container(
                    width: size.width,
                    //height: size.height * 0.9,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: ListView(
                        children: [
                          SizedBox(height: 10.0),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Text('${_nombre}',
                                style: TextStyle(
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
                          ),
                          SizedBox(
                            height: 20.0,
                          ),
                          _informacionHuerta(),
                          _informacionIconos(),
                          _informacionIconos2()
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: size.height * 0.07,
          child: Row(
            children: [
              Expanded(child: Container()),
              IconButton(
                onPressed: () {
                  _infoHuerta = false;
                  _visibleTipoSMap = true;
                  _busquedaVisibleBtn = true;
                  _visibleUbicacion = true;

                  setState(() {});
                },
                icon: CircleAvatar(
                  radius: 23.0,
                  child: CircleAvatar(
                    radius: 22.0,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.close,
                      color: Colors.green,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _informacionHuerta() {
    // final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.only(left: 15.0, right: 15.0, bottom: 25.0),
      child: Container(
        color: Colors.white.withValues(alpha: 0.8),
        child: Column(
          children: [
            Container(
              color: Colors.green[200],
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text(
                          'Código:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.0),
                        )),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text('|',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.0,
                                color: Colors.green))),
                  ),
                  Expanded(
                    flex: 5,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text('$_codigo',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11.0))),
                  ),
                ],
              ),
            ),
            Container(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text(
                          'Nombre:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.0),
                        )),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text('|',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.0,
                                color: Colors.green))),
                  ),
                  Expanded(
                    flex: 5,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text('$_nombre',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11.0))),
                  ),
                ],
              ),
            ),
            Container(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text(
                          'Área:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.0),
                        )),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text('|',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.0,
                                color: Colors.green))),
                  ),
                  Expanded(
                    flex: 5,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text(
                          '$_area' + ' M2',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.0),
                        )),
                  )
                ],
              ),
            ),
            Container(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text(
                          'Código UPZ:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.0),
                        )),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text('|',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.0,
                                color: Colors.green))),
                  ),
                  Expanded(
                    flex: 5,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text('$_codigoUPZ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11.0))),
                  ),
                ],
              ),
            ),
            Container(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text(
                          'Localidad:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.0),
                        )),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text('|',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.0,
                                color: Colors.green))),
                  ),
                  Expanded(
                    flex: 5,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text('$_localidad',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11.0))),
                  ),
                ],
              ),
            ),
            Container(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text(
                          'Dirección:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.0),
                        )),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text('|',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.0,
                                color: Colors.green))),
                  ),
                  Expanded(
                    flex: 5,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text('$_direccion',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11.0))),
                  ),
                ],
              ),
            ),
            Container(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text(
                          'Teléfono del líder:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.0),
                        )),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text('|',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.0,
                                color: Colors.green))),
                  ),
                  Expanded(
                    flex: 5,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: _telefono == 'null'
                            ? Text(' - ', style: TextStyle(fontSize: 11.0))
                            : Text('$_telefono',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.0))),
                  ),
                ],
              ),
            ),
            Container(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text(
                          'Productos huerta:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.0),
                        )),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text('|',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.0,
                                color: Colors.green))),
                  ),
                  Expanded(
                    flex: 5,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text('$_productos',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11.0))),
                  ),
                ],
              ),
            ),
            Container(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text(
                          'Coordenada X:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.0),
                        )),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text('|',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.0,
                                color: Colors.green))),
                  ),
                  Expanded(
                    flex: 5,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        color: Colors.green[100],
                        child: Text('$_coordenadaX',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11.0))),
                  ),
                ],
              ),
            ),
            Container(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text(
                          'Coordenada Y:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.0),
                        )),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text('|',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.0,
                                color: Colors.green))),
                  ),
                  Expanded(
                    flex: 5,
                    child: Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text('$_coordenadaY',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11.0))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _informacionIconos() {
    return Container(
      padding: EdgeInsets.all(15.0),
      child: Row(
        children: [
          InkWell(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: Colors.white.withValues(alpha: 0.4),
              ),
              height: 40,
              width: 40,
              child: comercializacion!
                  ? Container(
                      child: Image(
                          image:
                              AssetImage('assets/mapa/comercializacionON.png')))
                  : Container(
                      child: Image(
                        image:
                            AssetImage('assets/mapa/comercializacionOFF.png'),
                      ),
                    ),
            ),
          ),
          SizedBox(
            height: 1.0,
          ),
          Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.all(3.0),
                //color: Colors.green[100],
                child: comercializacion!
                    ? Text('Comercialización',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.green))
                    : Text('Comercialización',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
              )),
          SizedBox(
            height: 5.0,
          ),
          InkWell(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: Colors.white.withValues(alpha: 0.4),
              ),
              height: 40,
              width: 40,
              child: redes!
                  ? Container(
                      child:
                          Image(image: AssetImage('assets/mapa/redesON.png')))
                  : Container(
                      child: Image(
                        image: AssetImage('assets/mapa/redesOFF.png'),
                      ),
                    ),
            ),
          ),
          SizedBox(
            height: 1.0,
          ),
          Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.all(3.0),
                //color: Colors.green[100],
                child: redes!
                    ? Text('Redes',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.green))
                    : Text('Redes',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
              )),
        ],
      ),
    );
  }

  Widget _informacionIconos2() {
    return Container(
      padding: EdgeInsets.all(15.0),
      child: Row(
        children: [
          InkWell(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: Colors.white.withValues(alpha: 0.4),
              ),
              height: 40,
              width: 40,
              child: espacioPublico!
                  ? Container(
                      child: Image(
                          image:
                              AssetImage('assets/mapa/espacioPublicoON.png')))
                  : Container(
                      child: Image(
                        image: AssetImage('assets/mapa/espacioPublicoOFF.png'),
                      ),
                    ),
            ),
          ),
          SizedBox(
            height: 1.0,
          ),
          Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.all(3.0),
                //color: Colors.green[100],
                child: espacioPublico!
                    ? Text('Espacio público',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.green))
                    : Text('Espacio público',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
              )),
          SizedBox(
            height: 5.0,
          ),
          InkWell(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: Colors.white.withValues(alpha: 0.4),
              ),
              height: 40,
              width: 40,
              child: rutas!
                  ? Container(
                      child:
                          Image(image: AssetImage('assets/mapa/rutasON.png')))
                  : Container(
                      child: Image(
                        image: AssetImage('assets/mapa/rutasOFF.png'),
                      ),
                    ),
            ),
          ),
          SizedBox(
            height: 1.0,
          ),
          Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.all(3.0),
                //color: Colors.green[100],
                child: rutas!
                    ? Text('Rutas',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.green))
                    : Text('Rutas',
                        style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
              )),
          SizedBox(
            height: 13.0,
          ),
        ],
      ),
    );
  }

  Widget _floatActionButtonLocalidad() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Visibility(
          visible: mostrarCardsIndicadores,
          child: Center(
              child: InkWell(onTap: () async {}, child: _redirecIndicadores())),
        ),
      ],
    );
  }

  Widget _redirecIndicadores() {
    final size = MediaQuery.of(context).size;
    String? texto = 'Localidad y UPZ    ';

    if (_prefs.valorLocIndicadores != 0) {
      texto = _prefs.valorLocIndicadores +
          ' - ' +
          _prefs.valorUPZindicadores +
          '  ';
    } else {
      texto = 'No localización';
    }

    return InkWell(
      onTap: () {
        //Navigator.pushNamed(context, 'indicadores');
      },
      child: Container(
        margin: EdgeInsets.only(right: 5.0),
        padding: EdgeInsets.only(left: 15.0),
        height: 35,
        //aca upz localidad
        width: size.width * 0.5,
        decoration: BoxDecoration(
          color: HexColor("#20a01d").withValues(alpha: 0.9),
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            topLeft: Radius.circular(20),
          ),
        ),
        alignment: Alignment.center,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image(image: AssetImage('assets/indicadores.png')),
                SizedBox(
                  width: 5.0,
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      texto,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InfoHuerta extends StatelessWidget {
  final Map<String, dynamic>? huerta;
  final ServicioMapa servicioMapa;
  final bool? mercadosCampesinos;
  InfoHuerta(this.huerta, this.servicioMapa, this.mercadosCampesinos);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(10, 0, 10, 5),
      child: Column(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Nombre localidad: ${huerta!['objeto_respuesta']['localidad']['nombre']}",
          ),
          Text(
              "Tipo de huerta: ${huerta!['objeto_respuesta']['tipoHuerta']['nombre']}"),
          Text(
              "Tipo de espacio: ${huerta!['objeto_respuesta']['tipoEspacio']['nombre']}"),
          Text(
              "Participa en mercados campesinos: ${mercadosCampesinos != null && mercadosCampesinos! ? 'Sí' : 'No'}"),
          Divider(
            height: 5,
            thickness: 2,
          ),
          Center(
            child: Text('Productos'),
          ),
          FutureBuilder(
            future: servicioMapa
                .getProductosPorHuertaId(huerta!['objeto_respuesta']['id']),
            builder: (context, AsyncSnapshot<ProductoClass?> snapshot) {
              if (snapshot.hasData) {
                var productos = snapshot.data!.objetoRespuesta!;
                Map<String, List<String>> productosPorCategoria = {};

                for (String producto in productos) {
                  List<String> partes = producto.split(' - ');

                  if (partes.length == 2) {
                    String nombreProducto = partes[0].trim();
                    String categoriaProducto = partes[1].trim();

                    productosPorCategoria.putIfAbsent(
                        categoriaProducto, () => []);
                    productosPorCategoria[categoriaProducto]!
                        .add(nombreProducto);
                  }
                }
                if (!productosPorCategoria.isNotEmpty) {
                  return Text('No hay productos para mostrar');
                } else {
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: productosPorCategoria.length,
                    itemBuilder: (context, index) {
                      String categoria =
                          productosPorCategoria.keys.elementAt(index);
                      List<String> productos =
                          productosPorCategoria[categoria]!;

                      return ListTile(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoria,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: productos.map((producto) {
                                return Text('- $producto');
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
              } else {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
          )
        ],
      ),
    );
  }
}

class ExpansionPanelFiltro extends StatefulWidget {
  final VoidCallback callback;
  final VoidCallback callbackFiltrarPorLocalidad;
  @override
  _ExpansionPanelFiltroState createState() => _ExpansionPanelFiltroState();
  ExpansionPanelFiltro(this.callback, this.callbackFiltrarPorLocalidad);
}

class _ExpansionPanelFiltroState extends State<ExpansionPanelFiltro> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Card(
        color: Colors.white.withValues(alpha: 0.3),
        elevation: 4,
        child: ExpansionPanelList(
          elevation: 1,
          expandedHeaderPadding: EdgeInsets.all(0),
          expansionCallback: (int index, bool isExpanded) {
            setState(() {
              _isExpanded = !isExpanded;
            });
          },
          children: [
            ExpansionPanel(
              backgroundColor: Colors.green.shade200.withValues(alpha: 0.9),
              headerBuilder: (BuildContext context, bool isExpanded) {
                return ListTile(
                  title: Text(
                    'Filtros',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
              body: Padding(
                padding: EdgeInsets.all(16.0),
                // child: Text(''),
                child:
                    Filtro(widget.callback, widget.callbackFiltrarPorLocalidad),
              ),
              isExpanded: _isExpanded,
            ),
          ],
        ),
      ),
    );
  }
}

class Filtro extends StatefulWidget {
  final VoidCallback callback;
  final VoidCallback callbackFiltrarPorLocalidad;
  @override
  _FiltroState createState() => _FiltroState();
  Filtro(this.callback, this.callbackFiltrarPorLocalidad);
}

class _FiltroState extends State<Filtro> {
  bool? comercioSelected = false;
  String selectedOption = '';
  List<String> selectedItems = [];
  final servicioMapa = ServicioMapa();
  late ProductosClass productos;

  // List<String> localidades = ['Opción 1', 'Opción 2', 'Opción 3'];
  List<S2Choice<String>> dropdownOptions2 = [];
  List<S2Choice<String?>> localidades = [];
  S2Choice<String>? selectedProduct;
  bool mostrarFiltroLocalidades = false;

  @override
  void initState() {
    super.initState();
    servicioMapa.getTodosProductos().then((value) {
      setState(() {
        productos = value;
        dropdownOptions2 =
            productos.objetoRespuesta!.map<S2Choice<String>>((e) {
          return S2Choice(
              value: e.id.toString(),
              title: e.nombre!.split('-').first,
              activeStyle: S2ChoiceStyle(color: Colors.green));
        }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleccione para filtrar solo huertas que comercializan productos:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            CheckboxListTile(
              title: Text('Comercializa productos'),
              value: comercioSelected,
              onChanged: (value) {
                setState(() {
                  comercioSelected = value;
                });
              },
            ),
            SizedBox(height: 16),
            // Text(
            //   'Selecciona una localidad:',
            //   style: TextStyle(fontWeight: FontWeight.bold),
            // ),
            // DropdownButton<String>(
            //   hint: Text('Selecciona una opción'),
            //   dropdownColor: Colors.green,
            //   value: selectedOption == '' ? localidades.first : selectedOption,
            //   onChanged: (value) {
            //     setState(() {
            //       selectedOption = value;
            //     });
            //   },
            //   items: localidades
            //       .where((option) => option != null) // Elimina elementos null
            //       .toSet() // Elimina duplicados
            //       .map((e) => DropdownMenuItem(
            //             value: e,
            //             child: Text(e),
            //           ))
            //       .toList(),
            // ),
            SizedBox(height: 16),
            Text(
              'Selecciona uno o varios productos:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SmartSelect<String>.single(
              choiceConfig: S2ChoiceConfig(
                  type: S2ChoiceType.chips, layout: S2ChoiceLayout.wrap),
              title: 'Tipos de productos',
              modalFilterHint: 'Selecciona uno',
              placeholder: 'Seleccione uno',
              modalConfig: S2ModalConfig(
                  type: S2ModalType.bottomSheet, filterHint: 'Seleccione uno'),
              choiceItems: dropdownOptions2,
              onChange: (state) => setState(() {
                selectedProduct = state.choice;
              }),
              selectedValue: selectedOption,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                print('Comercializa productos: $comercioSelected');
                print('Opción seleccionada: $selectedProduct');
                _MapaInicialState.filtrarHuertas(comercioSelected,
                    selectedProduct!.value, widget.callback, poblarLocalidades);
              },
              child: Text('Aplicar'),
            ),

            Visibility(
                visible: mostrarFiltroLocalidades,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10),
                    Divider(
                      thickness: 2,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Selecciona una localidad (Al seleccionar se aplicará el filtro automáticamente):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SmartSelect<String?>.single(
                      choiceConfig: S2ChoiceConfig(
                          type: S2ChoiceType.chips,
                          layout: S2ChoiceLayout.wrap),
                      title: 'Localidades',
                      modalFilterHint: 'Localidad',
                      placeholder: 'Localidad',
                      modalConfig: S2ModalConfig(
                          type: S2ModalType.bottomSheet,
                          filterHint: 'Localidad'),
                      choiceItems: localidades,
                      onChange: (state) => setState(() {
                        // selectedProduct = state.choice;
                        _MapaInicialState.localidadSeleccionada =
                            state.choice!.value;
                        widget.callbackFiltrarPorLocalidad();
                      }),
                      selectedValue: selectedOption,
                    ),
                  ],
                ))
          ],
        ),
      ),
    );
  }

  void poblarLocalidades() {
    mostrarFiltroLocalidades = true;
    localidades = _MapaInicialState.huertasTotales
        .map<S2Choice<String?>>((e) {
          return S2Choice(
              value: e['localidad'],
              title: e['localidad'],
              activeStyle: S2ChoiceStyle(color: Colors.green));
        })
        .toSet()
        .toList();

    setState(() {});
  }
}
