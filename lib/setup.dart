import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tds_ia/model/tds_measure.dart';

class PersistenceUtil {
  static Future<void> initPersistence() async {
    if (!kIsWeb) {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String appDocPath = appDocDir.path;
      Hive.init(appDocPath);
    } else {
      Hive.initFlutter();
    }
    await _createAdapters();
  }

  static _createAdapters() async {
    Hive.registerAdapter(TdsMeasureAdapter());
  }
}
