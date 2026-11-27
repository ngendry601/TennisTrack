// Import conditionnel : sur une plateforme qui a « dart:io » (téléphone, PC),
// on utilise la version _io ; sinon (web) la version vide _stub.
export 'database_factory_init_stub.dart'
    if (dart.library.io) 'database_factory_init_io.dart';
