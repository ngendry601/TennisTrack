import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tennis_track/widgets/exercise_image.dart';

/// PNG valide de 1 × 1 pixel.
final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

void main() {
  testWidgets('l’aperçu montre l’image entière et s’ouvre en plein écran',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: ExerciseImagePreview(image: _png, title: 'Gamme'),
      ),
    ));

    // Image entière : ajustée (contain), jamais rognée (cover).
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);

    await tester.tap(find.byType(ExerciseImagePreview));
    await tester.pumpAndSettle();

    expect(find.byType(FullImageScreen), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Gamme'), findsOneWidget);
  });
}
