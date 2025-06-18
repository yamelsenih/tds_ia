import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Asegúrate de que esta importación esté
import 'package:permission_handler/permission_handler.dart';
import 'package:tds_ia/setup.dart';

void main() async {
  // Asegúrate de inicializar FlutterBluePlus antes de usarlo.
  // Esto a menudo se hace automáticamente con las últimas versiones,
  // pero es buena práctica en el main si hay problemas.
  // FlutterBluePlus.instance; // Ya no es necesario instanciar así directamente.
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

  BluetoothDevice? microbitDevice;
  BluetoothCharacteristic? uartCharacteristic; // Característica para UART
  String accelerometerData = 'Esperando datos...';
  bool isScanning = false;
  bool isConnected = false;

  final String microbitName = 'BBC micro:bit'; // Nombre por defecto del Micro:bit

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
            if (characteristic.uuid.toString().toUpplserCase().replaceAll("-", "") == '6E400002B5A3F393E0A9E50E24DCCA9E') {
              uartCharacteristic = characteristic;
              await uartCharacteristic!.setNotifyValue(true);
              uartCharacteristic!.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  String receivedData = String.fromCharCodes(value);
                  setState(() {
                    accelerometerData = receivedData;
                  });
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