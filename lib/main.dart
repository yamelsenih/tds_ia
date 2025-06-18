import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Asegúrate de que esta importación esté
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tds_ia/model/tds_measure.dart';
import 'package:tds_ia/setup.dart';
import 'package:http/http.dart' as http;

import 'model/tds_measures_list.dart';

void main() async {
  // Asegúrate de inicializar FlutterBluePlus antes de usarlo.
  // Esto a menudo se hace automáticamente con las últimas versiones,
  // pero es buena práctica en el main si hay problemas.
  // FlutterBluePlus.instance; // Ya no es necesario instanciar así directamente.
  WidgetsFlutterBinding.ensureInitialized();
  await PersistenceUtil.initPersistence();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Micro:bit Acelerómetro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BluetoothAccelerometerScreen(),
    );
  }
}

class BluetoothAccelerometerScreen extends StatefulWidget {
  const BluetoothAccelerometerScreen({super.key});

  @override
  _BluetoothAccelerometerScreenState createState() => _BluetoothAccelerometerScreenState();
}

class _BluetoothAccelerometerScreenState extends State<BluetoothAccelerometerScreen> {
  // Ya no necesitas una instancia aquí.
  // FlutterBluePlus flutterBlue = FlutterBluePlus.instance; // ¡ELIMINA O COMENTA ESTA LÍNEA!
  final _measureBox = Hive.box(measureBoxName);
  BluetoothDevice? microbitDevice;
  BluetoothCharacteristic? uartCharacteristic; // Característica para UART
  String accelerometerData = 'Esperando datos...';
  bool isScanning = false;
  bool isConnected = false;
  DateTime? lastMeasurementTime;
  DateTime? lastAISupportTime;
  double? currentLatitude;
  double? currentLongitude;

  final String microbitName = 'BBC micro:bit'; // Nombre por defecto del Micro:bit
  final String apiUrl = 'https://n8n.dev.solopcloud.com/webhook/12c1e593-7bad-4d4f-9ce7-fbf64b6ffb85';

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si los servicios de ubicación están habilitados
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Los servicios de ubicación no están habilitados.
      // Puedes mostrar un diálogo al usuario para que los active.
      print('Servicios de ubicación deshabilitados.');
      setState(() {
        currentLatitude = null;
        currentLongitude = null;
      });
      return Future.error('Location services are disabled.');
    }

    // Verificar el estado de los permisos de ubicación
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Los permisos están denegados, solicitarlos
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Permisos de ubicación denegados.');
        setState(() {
          currentLatitude = null;
          currentLongitude = null;
        });
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Los permisos están denegados permanentemente.
      // Puedes indicar al usuario que vaya a la configuración de la app.
      print('Permisos de ubicación denegados permanentemente.');
      setState(() {
        currentLatitude = null;
        currentLongitude = null;
      });
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    // Si los permisos están concedidos, obtener la posición actual
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high, // O LocationAccuracy.low para menos precisión/consumo
        timeLimit: Duration(seconds: 10), // Tiempo máximo para obtener la ubicación
      );
      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
      });
      print('Coordenadas obtenidas: Lat: $currentLatitude, Lon: $currentLongitude');
    } catch (e) {
      print('Error al obtener la ubicación: $e');
      setState(() {
        currentLatitude = null;
        currentLongitude = null;
      });
    }
  }
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    if (statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true &&
        statuses[Permission.locationWhenInUse]?.isGranted == true) {
      _startScan();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permisos Bluetooth y/o ubicación denegados.')),
      );
    }
  }

  void _startScan() {
    setState(() {
      isScanning = true;
      accelerometerData = 'Escaneando dispositivos...';
    });

    // Cambios aquí: Llamar a los métodos directamente desde FlutterBluePlus
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    // Cambios aquí: Usar FlutterBluePlus.scanResults
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.name == microbitName) {
          // Cambios aquí: Usar FlutterBluePlus.stopScan()
          FlutterBluePlus.stopScan();
          setState(() {
            microbitDevice = r.device;
            isScanning = false;
            accelerometerData = 'Micro:bit encontrado: ${r.device.name}. Conectando...';
          });
          _connectToDevice(r.device);
          break;
        }
      }
    });

    // Cambios aquí: Usar FlutterBluePlus.isScanning
    FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && isScanning) {
        setState(() {
          isScanning = false;
          if (microbitDevice == null) {
            accelerometerData = 'No se encontró el Micro:bit. Reintentando...';
            Future.delayed(const Duration(seconds: 2), () {
              _startScan();
            });
          }
        });
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        isConnected = true;
        accelerometerData = 'Conectado al Micro:bit. Buscando servicios...';
      });

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        // El Micro:bit UART Service UUID es 6E400001-B5A3-F393-E0A9-E50E24DCCA9E
        // La característica RX (receive) para escribir es 6E400002-B5A3-F393-E0A9-E50E24DCCA9E
        // La característica TX (transmit) para leer es 6E400003-B5A3-F393-E0A9-E50E24DCCA9E
        if (service.uuid.toString().toUpperCase().replaceAll("-", "") == '6E400001B5A3F393E0A9E50E24DCCA9E') {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase().replaceAll("-", "") == '6E400002B5A3F393E0A9E50E24DCCA9E') {
              uartCharacteristic = characteristic;
              await uartCharacteristic!.setNotifyValue(true);
              uartCharacteristic!.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  String receivedData = String.fromCharCodes(value);
                  setState(() {
                    accelerometerData = receivedData;
                    _getCurrentLocation();
                  });
                  _saveData(receivedData);
                }
              });
              setState(() {
                accelerometerData = 'Recibiendo datos del acelerómetro...';
              });
              return;
            }
          }
        }
      }
      setState(() {
        accelerometerData = 'No se encontró la característica UART TX. Asegúrate de que el Micro:bit está enviando datos.';
      });
    } catch (e) {
      setState(() {
        isConnected = false;
        accelerometerData = 'Error al conectar o al leer datos: $e';
      });
      _disconnectDevice();
    }
  }

  _saveData(String data) async {
    try {
      final measure = double.parse(data);
      if (measure != null) {
        setState(() {
          lastMeasurementTime = DateTime.now(); // Captura el momento actual
        });
        double latitude = 0;
        double longitude = 0;
        final currentLatitude = this.currentLatitude;
        if(currentLatitude != null) {
          latitude = currentLatitude.toDouble();
        }
        final currentLongitude = this.currentLongitude;
        if(currentLongitude != null) {
          longitude = currentLongitude.toDouble();
        }
        _measureBox.add(TdsMeasure(measure: measure, latitude: latitude, longitude: longitude, datetime: lastMeasurementTime ?? DateTime.now()));
        print('Acelerómetro (JSON) - measure: $measure, latitude: $latitude, longitude: $longitude, datetime: $lastMeasurementTime');
      } else {
        print('Error: Valores de acelerómetro nulos en JSON: $data');
      }
    } catch (e) {
      print('Error al parsear JSON o datos: $e, Data: $data');
    }
    _getAISupport();
  }
  
  _getAISupport() async {
    if(lastAISupportTime == null) {
      setState(() {
        lastAISupportTime = DateTime.now();
      });
    }
    Duration difference = DateTime.now().difference(lastAISupportTime!);
    if(difference.inSeconds >= 10) {
      lastAISupportTime = DateTime.now();
      getTop20Measurements().forEach((element) {
        print("Top 20 - measure: ${element.measure}, latitude: ${element.latitude}, longitude: ${element.longitude}, datetime: ${element.datetime}");
      });
      final payload = TdsMeasuresPayload(
        measures: getTop20Measurements(),
      );

      // 2. Convierte el objeto Payload completo a una cadena JSON
      final String jsonBody = jsonEncode(payload.toJson());
      try {
        final response = await http.post(
          Uri.parse(apiUrl), // Convierte tu URL de string a Uri
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8', // Informa al servidor que envías JSON
          },
          body: jsonBody, // El cuerpo de la solicitud es la cadena JSON
        );

        // 3. Verifica la respuesta del servidor
        if (response.statusCode == 200 || response.statusCode == 201) { // 200 OK, 201 Created
          print('Datos enviados exitosamente al API. Respuesta: ${response.body}');
          // Aquí podrías actualizar un mensaje en la UI o limpiar el estado
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Medición enviada al servidor! ${response.body}")),
          );
        } else {
          print('Error al enviar datos al API. Código de estado: ${response.statusCode}, Cuerpo: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al enviar datos: ${response.statusCode}')),
          );
        }
      } catch (e) {
        print('Excepción al conectar con el API: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión al API: $e')),
        );
      }
    }
  }

  List<TdsMeasure> getTop20Measurements() {
    // 1. Crear una copia mutable para ordenar
    List<TdsMeasure> sortedList = List.from(_measureBox.values);

    // 2. Ordenar de manera descendente por timestamp
    // 'b.timestamp.compareTo(a.timestamp)' ordena de más nuevo a más antiguo
    sortedList.sort((a, b) => b.datetime.compareTo(a.datetime));

    // 3. Limitar a los primeros 20 registros
    // Si la lista tiene menos de 20 elementos, take(20) devolverá todos los elementos.
    return sortedList.take(20).toList();
  }

  Future<void> _disconnectDevice() async {
    if (microbitDevice != null && isConnected) {
      await microbitDevice!.disconnect();
      setState(() {
        isConnected = false;
        accelerometerData = 'Desconectado del Micro:bit.';
        microbitDevice = null;
        uartCharacteristic = null;
      });
    }
  }

  @override
  void dispose() {
    _disconnectDevice();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Micro:bit Acelerómetro'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                accelerometerData,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              if (isScanning)
                const CircularProgressIndicator(),
              if (!isScanning && !isConnected)
                ElevatedButton(
                  onPressed: _startScan,
                  child: const Text('Iniciar Escaneo y Conectar'),
                ),
              if (isConnected)
                ElevatedButton(
                  onPressed: _disconnectDevice,
                  child: const Text('Desconectar'),
                ),
              const SizedBox(height: 20),
              const Text(
                'Datos del acelerómetro (X, Y, Z):',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                'Raw: $accelerometerData',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}