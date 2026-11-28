# TennisTrack

Application Flutter pour référencer et catégoriser mes séances d'entraînement
de tennis : date, heure, durée, intensité, catégories, couleur de balle et
exercices issus d'une **bibliothèque d'exercices** réutilisables.

Les données sont stockées dans une **base SQLite locale**, sur le téléphone.
Il n'y a plus de liste de séances écrite en dur dans le code ni de
`shared_preferences`.

## Fonctionnalités

### Séances

- Date, **heure de début facultative**, durée du cours, intensité (1 à 5),
  plusieurs catégories et couleur de balle.
- **Préparation et rangement** (0 à 60 min chacun) : le temps d'installation
  avant le cours et de rangement après. Une nouvelle séance reprend les
  valeurs de la dernière séance enregistrée. Les détails et le calendrier
  affichent le temps sur place : `Sur place 9h00 – 10h45 · 1h45min` pour un
  cours de 9h15 à 10h30. **Toutes les statistiques** (heures du mois, totaux,
  heures par catégorie, total d'un jour) comptent préparation + cours +
  rangement.
- Durées affichées au format **`1h15min`** (jamais `1,3 h`), plages horaires
  au format `18h00 – 19h30`.
- **Détails d'une séance** : un appui sur une séance (accueil, liste ou
  calendrier) affiche ses informations et ses exercices en lecture seule.
  Le bouton **Modifier** ouvre ensuite le formulaire d'édition.
- **Suppression** dans l'onglet Séances : icône corbeille avec confirmation,
  ou glissement vers la gauche (avec confirmation également).
- Filtres par catégorie, intensité et durée, recherche libre.

### Heures hors séances

- Petit lien discret **« Ajouter des heures hors séance »** sur l'accueil
  (sous les chiffres du mois), ou bouton « Ajouter » d'un jour du
  calendrier : ajoute des
  heures passées hors des séances (voir jouer ses joueurs en championnat,
  aider un coach…) avec une **date**, une **durée** (15 min à 12h) et un
  **commentaire** libre. Des commentaires sont proposés : les derniers
  utilisés, puis Championnat, Tournoi, Aide coach, Réunion, Formation.
- Elles **comptent dans toutes les heures** (accueil, calendrier, stats), et
  apparaissent comme « Hors séances » dans la répartition par catégorie. Elles
  ne comptent pas dans le **nombre** de séances.
- Visibles sur l'accueil (semaine en cours), dans le détail d'un jour du
  calendrier et dans la carte du mois des stats. Un appui ouvre le
  formulaire pour les modifier ou les supprimer.

### Bibliothèque d'exercices

- Un exercice existe **une seule fois** et peut être utilisé dans plusieurs
  séances : le modifier met à jour **toutes** les séances qui l'utilisent.
- Chaque exercice a un nom, une **durée facultative** (en minutes, la même
  dans toutes les séances), des points à travailler, un déroulement (matériel
  compris), une **image illustrative importée depuis la galerie** (stockée en
  BLOB dans SQLite), des **thèmes** (catégories) et les **couleurs de balle**
  pour lesquelles il est adapté.
- **Onglet Exercices** : liste de la bibliothèque avec recherche et filtres
  par thème et couleur de balle, création, modification et suppression
  (avec confirmation).
- Dans une séance, le bouton d'ajout d'exercice propose :
  - **Choisir dans ma bibliothèque** : le filtre démarre sur la couleur de
    balle de la séance (modifiable), pour ne pas proposer d'exercices trop
    durs ;
  - **Créer un nouvel exercice** : les thèmes de la séance sont pré-cochés,
    et l'exercice rejoint la bibliothèque.
- **Affichage des images** : l'aperçu (fiche d'exercice, détails d'une
  séance) montre l'image **en entier**, sans la rogner. Un appui sur
  l'aperçu, ou sur la miniature dans la bibliothèque, l'ouvre en plein écran
  avec zoom à deux doigts (`lib/widgets/exercise_image.dart`).
- **Schémas illustratifs en lot** : menu **⋮** de l'onglet Exercices.
  « Copier la liste des exercices » copie la bibliothèque (sans les images)
  pour l'envoyer à Claude ; « Importer les images » lit le fichier `.json`
  d'images renvoyé (choisi dans l'app Fichiers) et, après un résumé, associe
  chaque image à son exercice (par id + nom, ou par nom unique). Les schémas
  sont générés avec `tools/schemas/` (voir
  [tools/schemas/README.md](tools/schemas/README.md)).
- Dans une séance (formulaire et détails), chaque exercice affiche sa durée,
  et le **total des exercices** est comparé à la durée de la séance :
  `Exercices : 1h10min sur 1h30min`, avec « dépasse de … » si le total est
  plus long, et le nombre d'exercices sans durée.
- Supprimer une séance **garde** ses exercices dans la bibliothèque.
  Supprimer un exercice de la bibliothèque le retire de toutes ses séances.

### Écrans

- **Accueil** :
  - nombre de séances et heures du **mois en cours** ;
  - bande **L M M J V S D** de la semaine en cours (jours joués en évidence,
    aujourd'hui repéré par un point) ;
  - répartition du mois par catégorie (« Les plus travaillées ») et
    comparaison avec le mois précédent (`+2h30min par rapport à octobre`) ;
  - **dernier jour** joué : toutes les séances de ce jour (tous les groupes),
    dans l'ordre de la journée, avec leurs thèmes et exercices (les séances
    futures sont ignorées) ;
  - liste des séances de la **semaine en cours** (lundi → dimanche).
- **Séances** : toutes les séances, avec filtres et recherche.
- **Exercices** : la bibliothèque d'exercices.
- **Calendrier** : grille mensuelle (lundi → dimanche) avec un point sur
  chaque jour contenant une séance. Un appui sur un jour affiche les
  horaires, la durée totale et les thèmes du jour. Les mois se parcourent
  avec les flèches, et le bouton « Ajouter » crée une séance directement à
  la date sélectionnée. Les noms des jours et des mois viennent de la base.
- **Statistiques** : total général et total d'heures par mois, nombre de
  séances, barre de comparaison et répartition des heures par catégorie.
- **Bouton flottant global** : « Séance » sur tous les onglets, sauf
  l'onglet Exercices où il devient « Exercice ».

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
gratuit. Il se lance à la main (« Run workflow ») ou à chaque push qui
modifie `lib/`, `ios/` ou `pubspec.*`. Le pas-à-pas est dans
[docs/INSTALLER_SUR_IPHONE.md](docs/INSTALLER_SUR_IPHONE.md).

## Où sont les données ?

Au premier lancement, l'application crée la base `tennistrack.db` dans le
dossier de bases de données privé de l'application, puis insère les données
de départ : 10 catégories, 4 couleurs de balle, les 7 jours et les 12 mois.

- La base est **propre à chaque téléphone**.
- Elle est **persistante** : fermer l'application ne l'efface pas.
- Elle est **modifiable** : ajout, modification et suppression de séances et
  d'exercices passent par SQLite.
- Les modifications ne sont **pas synchronisées** entre deux téléphones.
- Désinstaller l'application supprime la base.

Pourquoi ne pas livrer un fichier `app.db` dans les assets ? Le contenu à
pré-remplir est minime. Le créer dans `onCreate` évite d'embarquer un fichier
binaire, d'avoir deux définitions du schéma à maintenir, et de devoir gérer
une copie « premier lancement ». Le résultat est identique : une vraie base
SQLite, créée sur le téléphone.

### Données de départ

- **Catégories** : Service, Coup droit, Revers, Volée / Filet, Jeu de jambes,
  Physique, Positionnement / Replacement, Tactique, Attaque, Défense.
- **Couleurs de balle** (niveau du joueur) : Rouge, Orange, Vert, Jaune.
- **Jours** (`id` = `DateTime.weekday`, 1 = lundi) et **mois**
  (`id` = `DateTime.month`, 1 = janvier), avec nom et abréviation.

## Schéma (version 8)

```text
categorie(id, nom UNIQUE)
couleur_balle(id, nom UNIQUE)
jour_semaine(id 1..7, nom UNIQUE, abreviation UNIQUE)
mois(id 1..12, nom UNIQUE, abreviation UNIQUE)

seance(
  id, date 'YYYY-MM-DD', duree_minutes > 0, intensite 1..5,
  couleur_balle_id, heure_debut 'HH:mm' NULL,
  preparation_minutes >= 0 DEFAULT 0, rangement_minutes >= 0 DEFAULT 0
)
seance_categorie(seance_id, categorie_id)      -- plusieurs catégories par séance

activite(id, date 'YYYY-MM-DD', duree_minutes > 0, commentaire)
                                               -- heures hors séances

exercice(
  id, nom, points_travailles, deroulement, image BLOB NULL,
  duree_minutes > 0 NULL
)
seance_exercice(seance_id, exercice_id, ordre) -- exercices partagés
exercice_categorie(exercice_id, categorie_id)  -- thèmes de l'exercice
exercice_couleur_balle(exercice_id, couleur_balle_id)

INDEX sur seance(date)
INDEX sur seance_categorie(categorie_id)
INDEX sur seance_exercice(exercice_id)
INDEX sur exercice_categorie(categorie_id)
INDEX sur exercice_couleur_balle(couleur_balle_id)
```

- `PRAGMA foreign_keys = ON` est exécuté à chaque ouverture (sans lui, les
  `ON DELETE CASCADE` ne fonctionnent pas).
- Supprimer une séance supprime ses liens de catégories et d'exercices, mais
  **pas** les exercices eux-mêmes.
- Supprimer un exercice supprime ses liens avec les séances, les catégories
  et les couleurs.
- Supprimer une catégorie supprime aussi les séances liées (trigger
  `supprime_seances_de_categorie`), même si elles ont d'autres catégories.
  C'est le comportement demandé ; il n'y a pas encore d'écran de suppression
  de catégorie.
- Une couleur de balle utilisée par une séance ne peut pas être supprimée
  (`ON DELETE RESTRICT`).
- La date de la séance est directement dans `seance.date`. Une table
  `planification` séparée n'est utile que si tu veux placer **la même**
  séance sur plusieurs jours. Ce n'est pas le cas aujourd'hui ; on pourra
  l'ajouter plus tard via une migration.
- Les images sont des BLOB : une sauvegarde de `tennistrack.db` contient
  donc aussi les images.

### Historique des migrations

| Version | Changement |
| ------- | ---------- |
| v1 → v2 | Ajout de `seance.heure_debut` (facultative). Les anciennes séances gardent `NULL` et affichent uniquement leur durée. |
| v2 → v3 | Suppression de `lieu` et `notes` (reconstruction de `seance` en conservant séances et liens de catégories) et ajout de la table `exercice` (un exercice par séance). |
| v3 → v4 | Ajout des tables `jour_semaine` et `mois` pour le calendrier. |
| v4 → v5 | Bibliothèque d'exercices : les exercices deviennent partagés (`seance_exercice`). Les exercices au contenu strictement identique sont fusionnés ; chacun hérite des catégories et de la couleur de balle de ses séances. Ajout des catégories Attaque et Défense. |
| v5 → v6 | Ajout de `exercice.duree_minutes` (facultative). Les exercices existants n'ont pas de durée (`NULL`). |
| v6 → v7 | Ajout de `seance.preparation_minutes` et `seance.rangement_minutes`. Les séances existantes en ont 0. |
| v7 → v8 | Ajout de la table `activite` (heures hors séances : championnat, aide coach…). |

## Ajouter une catégorie ou une couleur

Les catégories et couleurs sont dans la base. Tu peux les modifier avec un
outil comme **DB Browser for SQLite** en ouvrant le fichier `tennistrack.db`
du téléphone (nécessite un téléphone rooté ou une copie via `adb`), ou ajouter
plus tard un écran d'administration dans l'application.

Pour une nouvelle installation, ajoute aussi le nom dans `kSeedCategories`
(ou `kSeedBallColors`) de `lib/data/database.dart`, et prévois un
`INSERT OR IGNORE` dans une migration pour les bases existantes.

L'icône d'une catégorie et la teinte d'une couleur de balle sont associées à
leur **nom** dans `lib/models/models.dart`. Une catégorie inconnue reçoit
l'icône tennis, une couleur inconnue s'affiche en gris.

## Structure

```text
lib/
├── main.dart                         ouverture de la base + lancement (locale fr)
├── models/models.dart                TrainingCategory, BallColor, CalendarWeekday,
│                                     CalendarMonth, Exercise, TrainingSession
├── data/
│   ├── database.dart                 schéma, données de départ, migrations
│   ├── tennis_repository.dart        requêtes SQL (CRUD séances et exercices)
│   └── database_factory_init*.dart   SQLite sur Windows/Linux (dev)
├── services/session_store.dart       cache mémoire + notifications UI
├── theme/app_theme.dart              palette (AppColors) et thème
├── utils/
│   ├── formatters.dart               format 1h15min + plages horaires
│   ├── date_ranges.dart              semaine lundi→dimanche, mois civil
│   ├── home_stats.dart               répartition par catégorie, dernière séance,
│   │                                 comparaison avec le mois précédent
│   ├── exercise_filters.dart         filtre texte / thème / couleur de balle
│   ├── exercise_durations.dart       total des durées des exercices d'une séance
│   ├── session_times.dart            préparation, rangement, temps sur place
│   ├── extra_hours.dart              heures hors séances : total, suggestions
│   └── exercise_transfer.dart        export de la liste d'exercices, lecture
│                                     et association des images importées
├── widgets/
│   ├── bar/bottom_navbar.dart        MainShell : 5 onglets + bouton flottant
│   ├── bar/appbar.dart               barre du haut
│   ├── home_cards.dart               cartes de l'accueil
│   ├── exercise_widgets.dart         affichage commun des exercices
│   ├── extra_hours_tile.dart         carte d'une entrée « Autres heures »
│   ├── exercise_image.dart           aperçu entier + plein écran des images
│   ├── session_card_frame.dart       cadre des cartes de séance
│   └── confirm_delete_session.dart   boîte de confirmation de suppression
└── screens/
    ├── home_screen.dart              accueil
    ├── calendar_screen.dart          calendrier mensuel
    ├── monthly_stats_screen.dart     statistiques
    ├── extra_hours_form_screen.dart  formulaire « Autres heures »
    ├── session/                      liste, détails et formulaire de séance
    └── seance/                       bibliothèque, choix et formulaire
                                      d'exercice

tools/schemas/                        générateur des schémas d'exercices (Node)
```

### Par où commencer pour lire le code

Le code est commenté en français. Ordre de lecture conseillé :

1. `lib/main.dart` : démarrage de l'appli.
2. `lib/widgets/bar/bottom_navbar.dart` : les 5 onglets et le bouton flottant.
3. `lib/models/models.dart` : les objets manipulés (séance, exercice…).
4. `lib/services/session_store.dart` : la mémoire de l'appli, utilisée par
   tous les écrans.
5. `lib/data/tennis_repository.dart` puis `lib/data/database.dart` : la base
   SQLite.
6. Un écran simple, par exemple `lib/screens/session/sessions_screen.dart`,
   puis le formulaire `lib/screens/session/session_form_screen.dart`.

## Tests

```bash
flutter analyze
flutter test
```

Les tests utilisent une base SQLite en mémoire (`sqflite_common_ffi`).

- `test/database_test.dart` : création du schéma et des données de départ
  (catégories, couleurs, jours, mois), ajout/modification/suppression d'une
  séance, trigger de suppression par catégorie, migration `v1 → v3`.
- `test/exercise_library_test.dart` : catégories Attaque et Défense, mise à
  jour d'un exercice dans toutes ses séances, suppression séance/exercice
  indépendante, migration `v4 → v5`, filtres de la bibliothèque, choix
  démarrant sur la couleur de balle de la séance.
- `test/exercise_duration_test.dart` : total des durées et libellé,
  enregistrement et contrainte en base, saisie dans la fiche d'exercice,
  total dans les détails d'une séance, migration `v5 → v6`.
- `test/exercise_transfer_test.dart` : export de la liste, lecture du
  fichier d'images (et refus des fichiers invalides), association par id +
  nom ou nom unique, enregistrement en base, import depuis l'onglet
  Exercices.
- `test/formatters_test.dart` : format `1h15min` et plages horaires.
- `test/date_ranges_test.dart` : bornes de la semaine (lundi → dimanche) et
  du mois.
- `test/home_stats_test.dart` : répartition par catégorie, séances du
  dernier jour, comparaison avec le mois précédent.
- `test/extra_hours_test.dart` : heures hors séances (libellé, suggestions,
  répartition, base, lien de l'accueil, calendrier, stats), migration
  `v7 → v8`.
- `test/session_setup_test.dart` : préparation et rangement (arrivée,
  départ, textes, statistiques, valeurs reprises de la dernière séance,
  base, détails), séances du dernier jour sur l'accueil, migration `v6 → v7`.
- `test/screens_test.dart` et `test/widget_test.dart` : stats et liste de la
  semaine sur l'accueil, heures par mois, détail d'un jour du calendrier,
  détails puis modification d'une séance, suppression depuis l'onglet
  Séances, navigation et recherche.

## Import d'image

L'image est choisie avec `image_picker` depuis la galerie, redimensionnée
(max. 1600 px, qualité 80) puis enregistrée en BLOB dans la table `exercice`.
L'import en lot des schémas utilise `file_picker` pour choisir le fichier
`.json` (iOS 14 minimum ; le projet cible iOS 15).
Sur iOS, la clé `NSPhotoLibraryUsageDescription` est déclarée dans
`ios/Runner/Info.plist`.

## Faire évoluer le schéma

1. Incrémenter `kDatabaseVersion` dans `lib/data/database.dart`.
2. Ajouter la migration correspondante dans `onUpgrade`
   (`if (oldVersion < N) { … }`), et mettre à jour `onCreate` pour les
   nouvelles installations.
3. Ajouter un test de migration depuis la version précédente.
4. Ne jamais supprimer la base de l'utilisateur pour « réinitialiser » :
   cela effacerait ses séances.

## Anciennes données

L'ancienne version stockait les séances dans `shared_preferences`
(clé `sessions_v1`). Comme convenu, il n'y a pas de migration automatique :
la nouvelle base démarre avec les données de départ, sans séance.
