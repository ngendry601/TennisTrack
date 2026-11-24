# AGENTS.md

Consignes pour les agents (Claude, Copilot…) qui travaillent sur TennisTrack.
Le détail fonctionnel et le schéma complet sont dans [README.md](README.md).

## Le projet en bref

- Application **Flutter** (Dart ≥ 3.4) pour suivre des séances de tennis.
- Cibles : **Android et iOS**. Windows/Linux servent au développement
  (`sqflite_common_ffi`).
- Données : **SQLite locale** (`sqflite`), base `tennistrack.db`, version
  actuelle du schéma : **6** (`kDatabaseVersion` dans `lib/data/database.dart`).
- Pas de backend, pas de synchronisation, pas de `shared_preferences`.
- Dépendances : `sqflite`, `sqflite_common_ffi`, `path`, `image_picker`,
  `file_picker` (import du fichier d'images), `flutter_localizations`. N'en ajoute pas sans raison claire.

## Langue

- L'utilisateur est **francophone** : réponds en français.
- Toute l'interface est en **français** (locale `fr` uniquement).
- Commentaires de code, messages de commit, noms de tests et documentation :
  en **français**.
- Noms SQL en français (`seance`, `exercice`, `couleur_balle`…). Noms Dart des
  classes et champs en anglais (`TrainingSession`, `Exercise`, `pointsToWork`…),
  comme dans le code existant.

## Architecture

```text
UI (screens/, widgets/)
   │  lit et écoute
   ▼
SessionStore (services/session_store.dart)   ChangeNotifier, cache mémoire
   │  appelle
   ▼
TennisRepository (data/tennis_repository.dart)   requêtes SQL
   │
   ▼
SQLite (data/database.dart)   schéma, données de départ, migrations
```

- Les écrans reçoivent le `SessionStore` en paramètre (`store:`) ; pas de
  package de gestion d'état.
- Les écrans ne font **jamais** de SQL directement : tout passe par le store,
  qui passe par le repository.
- La logique pure (calculs, filtres, formats) va dans `lib/utils/` et se teste
  sans interface.
- `MainShell` (`lib/widgets/bar/bottom_navbar.dart`) porte les 5 onglets
  (Accueil, Séances, Exercices, Calendrier, Stats) dans un `IndexedStack` et
  le bouton flottant global (« Séance », ou « Exercice » sur l'onglet
  Exercices).
- Couleurs : uniquement via `AppColors` / le thème de `lib/theme/app_theme.dart`.

## Règles métier à respecter

- Durées toujours au format **`1h15min`** / `2h05min` / `45min` / `2h` via
  `lib/utils/formatters.dart`. Jamais `1,3 h`.
- Plages horaires au format `18h00 – 19h30`. L'heure de début est
  facultative : sans elle, on n'affiche que la durée.
- La semaine va du **lundi au dimanche** (`lib/utils/date_ranges.dart`).
- Une séance a **plusieurs catégories**, une couleur de balle, une intensité
  de 1 à 5.
- Les exercices sont **partagés** (bibliothèque) : modifier un exercice le
  modifie dans toutes ses séances. Supprimer une séance garde ses exercices ;
  supprimer un exercice le retire de toutes les séances.
- Un exercice a une durée **facultative** (`durationMinutes`, 1 à 240 min),
  la même dans toutes ses séances. Le total des exercices d'une séance est
  indicatif (`lib/utils/exercise_durations.dart`) : il peut dépasser la durée
  de la séance, et ne bloque jamais l'enregistrement.
- Le choix d'exercices dans une séance démarre filtré sur la couleur de balle
  de la séance.
- Les images sont stockées en **BLOB** dans SQLite (pas de chemin de fichier),
  redimensionnées à 1600 px max, qualité 80.
- Icônes de catégories et teintes des couleurs de balle : associées au **nom**
  dans `lib/models/models.dart`. Ajouter une catégorie = l'ajouter aussi dans
  la table d'icônes.
- `id == 0` sur un modèle signifie « pas encore enregistré ».

## Base de données : règles impératives

1. **Ne jamais supprimer ni recréer la base** de l'utilisateur : ses séances
   seraient perdues.
2. Tout changement de structure :
   - incrémenter `kDatabaseVersion` ;
   - ajouter un bloc `if (oldVersion < N)` dans `onUpgrade` qui conserve les
     données existantes ;
   - mettre à jour `onCreate` pour qu'une installation neuve ait le même
     schéma qu'une base migrée ;
   - ajouter un test de migration depuis la version précédente.
3. Nouvelles données de départ : les ajouter aux constantes `kSeed*` **et**
   les insérer avec `INSERT OR IGNORE` dans la migration.
4. `PRAGMA foreign_keys = ON` est activé dans `onConfigure` : ne pas le
   retirer, les `ON DELETE CASCADE` en dépendent.
5. Le trigger `supprime_seances_de_categorie` est voulu (supprimer une
   catégorie supprime ses séances). Ne pas le « corriger » sans demande.
6. Mettre à jour la section Schéma et l'historique des migrations du README.

## Vérifications avant de livrer

```bash
flutter analyze
flutter test
```

- Les tests utilisent `sqflite_common_ffi` et `inMemoryDatabasePath`.
- Toute nouvelle fonctionnalité ou migration s'accompagne de tests
  (`test/`). Les tests de widgets passent la locale `fr` et une date de
  référence fixe quand l'écran dépend d'aujourd'hui.
- Si Flutter n'est pas installé dans l'environnement, le dire clairement
  plutôt que d'affirmer que les tests passent.

## Git et livraison

- Messages de commit en français, à l'impératif présent
  (« Ajoute la bibliothèque d'exercices »), avec une liste des changements
  dans le corps.
- Un push qui touche `lib/`, `ios/` ou `pubspec.*` relance le workflow
  `.github/workflows/ios-build.yml` (fabrication du `.ipa` non signé).
- Mettre à jour le README quand une fonctionnalité, le schéma ou la
  structure des fichiers change, ainsi que ce fichier si une convention
  évolue.

## Schémas d'exercices

Les images d'illustration des exercices se génèrent avec
`tools/schemas/generer.js` à partir de fichiers JSON (voir
`tools/schemas/README.md`).

Quand l'utilisateur colle une liste au format `tennistrack-exercices`
(copiée depuis l'onglet Exercices) : créer un `exercices/<nom>.json` par
exercice avec la clé `"exercice": { "id", "nom" }` **recopiée exactement**,
lancer `node tools/schemas/paquet.js`, puis lui envoyer le fichier de
`tools/schemas/paquets/` à importer (Exercices → ⋮ → Importer les images).
Ignorer les exercices dont `a_une_image` vaut `true`, sauf demande contraire.
Poser des questions quand la disposition d'un exercice n'est pas claire. Vocabulaire de l'utilisateur :

- **Grand terrain** = terrain de simple entier, sur toute la longueur.
- **Demi-terrain** = moitié du terrain de simple **dans la largeur**
  (couloir simple → ligne médiane), sur toute la longueur.
- Plot = cône, pastille = disque de replacement, languette = bande au sol,
  porte = base avec un jalon.
- Gauche / droite : du point de vue du joueur qui frappe, face au filet.
