import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Sur Windows et Linux, sqflite n'a pas d'implémentation native :
/// on utilise SQLite via FFI. Sur Android/iOS/macOS, rien à faire.
///
/// Cela permet aussi de tester l'application sur le PC pendant le
/// développement, sans téléphone branché.
void initDatabaseFactory() {
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
