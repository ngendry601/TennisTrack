import 'dart:convert';
import 'dart:typed_data';

import '../models/models.dart';

/// Échange avec Claude pour les schémas d'exercices :
///
/// 1. l'appli copie la liste des exercices (sans les images) au format
///    [kExercisesExportFormat] ;
/// 2. Claude renvoie un fichier au format [kImagesImportFormat] qui contient
///    une image par exercice ;
/// 3. l'appli associe chaque image à son exercice (id + nom).
const String kExercisesExportFormat = 'tennistrack-exercices';
const String kImagesImportFormat = 'tennistrack-images';
const int kTransferVersion = 1;

/// Liste des exercices à envoyer à Claude, en JSON lisible.
/// Les images ne sont pas incluses (trop lourdes pour le presse-papiers) :
/// seul `a_une_image` indique si l'exercice en a déjà une.
String exportExercisesJson(List<Exercise> exercises) {
  return const JsonEncoder.withIndent('  ').convert({
    'format': kExercisesExportFormat,
    'version': kTransferVersion,
    'exercices': [
      for (final exercise in exercises)
        {
          'id': exercise.id,
          'nom': exercise.name,
          'points_travailles': exercise.pointsToWork,
          'deroulement': exercise.execution,
          'duree_minutes': exercise.durationMinutes,
          'themes': [for (final c in exercise.categories) c.nom],
          'couleurs_balle': [for (final c in exercise.ballColors) c.nom],
          'a_une_image': exercise.image != null,
        },
    ],
  });
}

/// Une image lue dans le fichier d'import.
class ImportedImage {
  const ImportedImage({
    required this.exerciseId,
    required this.name,
    required this.bytes,
  });

  /// Id de l'exercice au moment de l'export, ou `null` s'il est inconnu.
  final int? exerciseId;
  final String name;
  final Uint8List bytes;
}

/// Fichier d'import illisible ou d'un autre format.
class ImageImportException implements Exception {
  const ImageImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lit le fichier d'images envoyé par Claude.
///
/// Lève [ImageImportException] si le fichier n'est pas au bon format ou si
/// une image n'est ni un PNG ni un JPEG.
List<ImportedImage> parseImagesJson(String source) {
  final Object? data;
  try {
    data = jsonDecode(source);
  } on FormatException {
    throw const ImageImportException('Ce fichier n’est pas un fichier JSON.');
  }

  if (data is! Map<String, Object?> || data['format'] != kImagesImportFormat) {
    throw const ImageImportException(
        'Ce fichier ne contient pas d’images d’exercices TennisTrack.');
  }
  final version = data['version'];
  if (version is! int || version > kTransferVersion) {
    throw const ImageImportException(
        'Ce fichier vient d’une version plus récente de l’appli.');
  }
  final entries = data['images'];
  if (entries is! List) {
    throw const ImageImportException('Le fichier ne contient aucune image.');
  }

  return [
    for (final entry in entries) _parseEntry(entry),
  ];
}

ImportedImage _parseEntry(Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw const ImageImportException('Une image du fichier est invalide.');
  }
  final name = entry['nom'];
  final encoded = entry['image_base64'];
  final id = entry['exercice_id'];
  if (name is! String || name.trim().isEmpty || encoded is! String) {
    throw const ImageImportException('Une image du fichier est invalide.');
  }

  final Uint8List bytes;
  try {
    bytes = base64Decode(encoded);
  } on FormatException {
    throw ImageImportException('L’image de « $name » est illisible.');
  }
  if (!_isPngOrJpeg(bytes)) {
    throw ImageImportException(
        'L’image de « $name » n’est ni un PNG ni un JPEG.');
  }
  return ImportedImage(
    exerciseId: id is int ? id : null,
    name: name,
    bytes: bytes,
  );
}

bool _isPngOrJpeg(Uint8List bytes) {
  const png = [0x89, 0x50, 0x4E, 0x47];
  const jpeg = [0xFF, 0xD8, 0xFF];
  bool startsWith(List<int> magic) =>
      bytes.length >= magic.length &&
      Iterable<int>.generate(magic.length).every((i) => bytes[i] == magic[i]);
  return startsWith(png) || startsWith(jpeg);
}

/// Ce que l'import va faire, à montrer avant de l'appliquer.
class ImageImportPlan {
  const ImageImportPlan({
    required this.images,
    required this.replaced,
    required this.notFound,
  });

  /// Image à enregistrer pour chaque id d'exercice.
  final Map<int, Uint8List> images;

  /// Nombre d'exercices qui avaient déjà une image (elle sera remplacée).
  final int replaced;

  /// Noms des images qui ne correspondent à aucun exercice.
  final List<String> notFound;
}

/// Associe chaque image à un exercice de la bibliothèque.
///
/// Un exercice est retrouvé par son id **et** son nom (cas normal), sinon
/// par son nom seul s'il est unique (exercice recréé, appli réinstallée).
/// La casse et les espaces en trop sont ignorés dans les noms. Une image
/// sans correspondance sûre n'est jamais appliquée : elle est listée dans
/// [ImageImportPlan.notFound].
ImageImportPlan planImageImport(
  List<Exercise> exercises,
  List<ImportedImage> imports,
) {
  final byId = {for (final e in exercises) e.id: e};
  final byName = <String, List<Exercise>>{};
  for (final exercise in exercises) {
    byName.putIfAbsent(_normalize(exercise.name), () => []).add(exercise);
  }

  final images = <int, Uint8List>{};
  final notFound = <String>[];

  for (final imported in imports) {
    final name = _normalize(imported.name);
    final sameId = byId[imported.exerciseId];
    final sameName = byName[name] ?? const [];

    final Exercise? target;
    if (sameId != null && _normalize(sameId.name) == name) {
      target = sameId;
    } else if (sameName.length == 1) {
      target = sameName.single;
    } else {
      target = null;
    }

    if (target == null) {
      notFound.add(imported.name);
    } else {
      images[target.id] = imported.bytes;
    }
  }

  final replaced = images.keys.where((id) => byId[id]?.image != null).length;
  return ImageImportPlan(
    images: images,
    replaced: replaced,
    notFound: notFound,
  );
}

String _normalize(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
