# TennisTrack

Application Flutter pour référencer et catégoriser mes séances d'entraînement
de tennis : date, heure, durée, intensité, catégories, couleur de balle et
exercices avec image illustrative.

Les données sont stockées dans une **base SQLite locale**, sur le téléphone.
Il n'y a plus de liste de séances écrite en dur dans le code ni de
`shared_preferences`.

## Fonctionnalités

- Séances avec date, **heure de début facultative**, durée, intensité,
  plusieurs catégories et couleur de balle.
- **Exercices illimités par séance** (bouton « Exo + ») : nom, points à
  travailler, déroulement avec le matériel, et **image illustrative importée
  depuis la galerie**. L'image est stockée directement dans SQLite (BLOB),
  pas seulement un chemin de fichier.
- Durées affichées au format **`1h15min`** (jamais `1,3 h`).
- **Onglet Calendrier** : grille mensuelle (semaine du lundi au dimanche) avec
  un point sur chaque jour contenant une séance. Un appui sur un jour affiche
  les horaires (`18h00 – 19h30`), la durée totale et les thèmes du jour.
  Les mois se parcourent avec les flèches, et le bouton « Ajouter » crée une
  séance directement à la date sélectionnée.
- **Accueil** : nombre de séances et heures du **mois en cours**, et liste
  limitée aux séances de la **semaine en cours** (lundi → dimanche). Toutes
  les séances restent disponibles dans l'onglet Séances.
- **Bouton « Séance » global** : il reste visible sur tous les onglets pour
  ajouter une séance depuis n'importe quel écran.
- **Onglet Statistiques** : total général (toutes les séances) et total
  d'heures par mois, nombre de séances, barre de comparaison et répartition
  des heures par catégorie.
- **Suppression d'une séance** dans l'onglet Séances : icône corbeille avec
  confirmation, ou glissement vers la gauche (avec confirmation également).
- **Détails d'une séance** : un appui sur une séance (accueil, liste ou
  calendrier) affiche ses informations et ses exercices en lecture seule.
  Le bouton **Modifier** ouvre ensuite le formulaire d'édition.
- Filtres par catégorie, intensité et durée, recherche libre.

## Lancer l'application

```bash
flutter pub get
flutter run
```

Plateformes visées : **Android et iOS**. L'application fonctionne aussi sur
Windows/Linux pour le développement (via `sqflite_common_ffi`).

### Sur iPhone, gratuitement

Le workflow GitHub Actions `.github/workflows/ios-build.yml` fabrique un
fichier `.ipa` non signé, à installer avec Sideloadly et un identifiant Apple
gratuit. Le pas-à-pas est dans
[docs/INSTALLER_SUR_IPHONE.md](docs/INSTALLER_SUR_IPHONE.md).

## Où sont les données ?

Au premier lancement, l'application crée la base `tennistrack.db` dans le
dossier de bases de données privé de l'application, puis insère les
catégories et les couleurs de balle de départ.

- La base est **propre à chaque téléphone**.
- Elle est **persistante** : fermer l'application ne l'efface pas.
- Elle est **modifiable** : ajout, modification et suppression de séances
  passent par SQLite.
- Les modifications ne sont **pas synchronisées** entre deux téléphones.
- Désinstaller l'application supprime la base.

Pourquoi ne pas livrer un fichier `app.db` dans les assets ? Le seul contenu
à pré-remplir représente 12 lignes (8 catégories + 4 couleurs). Les créer
dans `onCreate` évite d'embarquer un fichier binaire, d'avoir deux définitions
du schéma à maintenir, et de devoir gérer une copie « premier lancement ».
Le résultat est identique : une vraie base SQLite, créée sur le téléphone.

## Schéma

```text
categorie(id, nom UNIQUE)
couleur_balle(id, nom UNIQUE)

seance(
  id, date 'YYYY-MM-DD', duree_minutes, intensite 1..5,
  couleur_balle_id, heure_debut 'HH:mm' NULL
)

exercice(
  id, seance_id, nom, points_travailles, deroulement, image BLOB NULL
)

seance_categorie(seance_id, categorie_id)   -- plusieurs catégories par séance

INDEX sur seance(date)
INDEX sur seance_categorie(categorie_id)
INDEX sur exercice(seance_id)
```

- `PRAGMA foreign_keys = ON` est exécuté à chaque ouverture.
- Supprimer une séance supprime automatiquement ses liens de catégories.
- Supprimer une catégorie supprime aussi les séances liées (trigger
  `supprime_seances_de_categorie`). C'est le comportement demandé ; il n'y a
  pas encore d'écran de suppression de catégorie.
- La date de la séance est directement dans `seance.date`. Une table
  `planification` séparée n'est utile que si tu veux placer **la même**
  séance sur plusieurs jours. Ce n'est pas le cas aujourd'hui ; on pourra
  l'ajouter plus tard via une migration.
- `heure_debut` est facultative : les séances enregistrées avant la version 2
  de la base gardent `NULL` et affichent uniquement leur durée. La migration
  `v1 → v2` ajoute la colonne sans toucher aux séances existantes.
- La version 3 supprime `lieu` et `notes` de `seance` (reconstruction de la
  table avec conservation des séances et des liens de catégories) et ajoute
  la table `exercice`. Les images sont des BLOB : une sauvegarde de
  `tennistrack.db` contient donc aussi les images.
- Supprimer une séance supprime automatiquement ses exercices
  (`ON DELETE CASCADE`).

## Ajouter une catégorie ou une couleur

Les catégories et couleurs sont dans la base. Tu peux les modifier avec un
outil comme **DB Browser for SQLite** en ouvrant le fichier `tennistrack.db`
du téléphone (nécessite un téléphone rooté ou une copie via `adb`), ou ajouter
plus tard un écran d'administration dans l'application.

L'icône d'une catégorie est associée à son **nom** dans
`lib/models/models.dart`. Une catégorie inconnue reçoit l'icône tennis.

## Structure

```text
lib/
├── main.dart                       ouverture de la base + lancement
├── models/models.dart              TrainingCategory, BallColor, TrainingSession
├── data/
│   ├── database.dart               création du schéma + données de départ
│   ├── tennis_repository.dart      requêtes SQL (CRUD)
│   ├── database_factory_init*.dart SQLite sur Windows/Linux (dev)
├── services/session_store.dart     cache mémoire + notifications UI
├── utils/formatters.dart           format 1h15min + plages horaires
├── utils/date_ranges.dart          semaine lundi→dimanche, mois civil
├── widgets/                        boîte de confirmation de suppression
└── screens/                        accueil, liste, détails et formulaire de
                                    séance, formulaire d'exercice, calendrier,
                                    statistiques mensuelles
```

## Tests

```bash
flutter analyze
flutter test
```

Les tests de `test/database_test.dart` utilisent une base SQLite en mémoire
et vérifient la création du schéma, l'ajout/modification/suppression d'une
séance, les exercices et leur image BLOB, les horaires de début/fin, le
trigger de suppression par catégorie et les migrations `v1 → v3`.
`test/formatters_test.dart` vérifie le format `1h15min` et les plages
horaires. `test/date_ranges_test.dart` vérifie les bornes de la semaine
(lundi → dimanche) et du mois. `test/screens_test.dart` vérifie les stats du
mois et la liste de la semaine sur l'accueil, l'affichage des heures par
mois, le détail d'un jour dans le calendrier, l'ouverture des détails d'une
séance puis de sa modification, et la suppression d'une séance depuis
l'onglet Séances.

## Import d'image

L'image est choisie avec `image_picker` depuis la galerie, redimensionnée
(max. 1600 px, qualité 80) puis enregistrée en BLOB dans la table `exercice`.
Sur iOS, la clé `NSPhotoLibraryUsageDescription` est déclarée dans
`ios/Runner/Info.plist`.

## Faire évoluer le schéma

1. Incrémenter `kDatabaseVersion` dans `lib/data/database.dart`.
2. Ajouter le `ALTER TABLE` / `CREATE TABLE` correspondant dans `onUpgrade`.
3. Ne jamais supprimer la base de l'utilisateur pour « réinitialiser » :
   cela effacerait ses séances.

## Anciennes données

L'ancienne version stockait les séances dans `shared_preferences`
(clé `sessions_v1`). Comme convenu, il n'y a pas de migration automatique :
la nouvelle base démarre avec les catégories et les couleurs, sans séance.
