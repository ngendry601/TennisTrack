import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Version du schéma. À incrémenter à chaque changement de structure,
/// puis ajouter la migration correspondante dans [onUpgrade].
const int kDatabaseVersion = 4;

const String _databaseName = 'tennistrack.db';

/// Catégories créées au premier lancement.
/// Ce sont les mêmes noms que dans l'ancien enum SessionCategory :
/// les icônes de l'interface sont associées à ces noms.
const List<String> kSeedCategories = [
  'Service',
  'Coup droit',
  'Revers',
  'Volée / Filet',
  'Jeu de jambes',
  'Physique',
  'Positionnement / Replacement',
  'Tactique',
];

/// Couleurs de balle créées au premier lancement (niveau du joueur).
const List<String> kSeedBallColors = ['Rouge', 'Orange', 'Vert', 'Jaune'];

/// Jours du calendrier (nom, abréviation). L'id en base suit
/// `DateTime.weekday` : 1 = lundi … 7 = dimanche.
const List<(String, String)> kSeedWeekdays = [
  ('Lundi', 'Lun'),
  ('Mardi', 'Mar'),
  ('Mercredi', 'Mer'),
  ('Jeudi', 'Jeu'),
  ('Vendredi', 'Ven'),
  ('Samedi', 'Sam'),
  ('Dimanche', 'Dim'),
];

/// Mois du calendrier (nom, abréviation). L'id en base suit
/// `DateTime.month` : 1 = janvier … 12 = décembre.
const List<(String, String)> kSeedMonths = [
  ('Janvier', 'Janv.'),
  ('Février', 'Févr.'),
  ('Mars', 'Mars'),
  ('Avril', 'Avr.'),
  ('Mai', 'Mai'),
  ('Juin', 'Juin'),
  ('Juillet', 'Juil.'),
  ('Août', 'Août'),
  ('Septembre', 'Sept.'),
  ('Octobre', 'Oct.'),
  ('Novembre', 'Nov.'),
  ('Décembre', 'Déc.'),
];

/// Ouvre (et crée si besoin) la base SQLite de l'application.
///
/// La base est créée directement sur le téléphone au premier lancement,
/// avec les catégories et les couleurs de balle. Elle est ensuite
/// persistante et modifiable : elle ne repart pas de zéro à chaque
/// ouverture de l'application.
Future<Database> openAppDatabase({String? path}) async {
  final databasePath =
      path ?? join(await databaseFactory.getDatabasesPath(), _databaseName);

  return databaseFactory.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: kDatabaseVersion,
      // SQLite n'active pas les clés étrangères par défaut : sans cette
      // ligne, les ON DELETE CASCADE ne fonctionnent pas.
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        final batch = db.batch();

        batch.execute('''
        CREATE TABLE couleur_balle (
          id   INTEGER PRIMARY KEY AUTOINCREMENT,
          nom  TEXT NOT NULL UNIQUE
        )
      ''');

        batch.execute('''
        CREATE TABLE categorie (
          id   INTEGER PRIMARY KEY AUTOINCREMENT,
          nom  TEXT NOT NULL UNIQUE
        )
      ''');

        batch.execute('''
        CREATE TABLE seance (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          date              TEXT NOT NULL,
          duree_minutes     INTEGER NOT NULL CHECK (duree_minutes > 0),
          intensite         INTEGER NOT NULL CHECK (intensite BETWEEN 1 AND 5),
          couleur_balle_id  INTEGER NOT NULL,
          heure_debut       TEXT,
          FOREIGN KEY (couleur_balle_id) REFERENCES couleur_balle(id)
            ON DELETE RESTRICT
        )
      ''');

        batch.execute('''
        CREATE TABLE exercice (
          id                 INTEGER PRIMARY KEY AUTOINCREMENT,
          seance_id          INTEGER NOT NULL,
          nom                TEXT NOT NULL,
          points_travailles  TEXT NOT NULL DEFAULT '',
          deroulement        TEXT NOT NULL DEFAULT '',
          image              BLOB,
          FOREIGN KEY (seance_id) REFERENCES seance(id) ON DELETE CASCADE
        )
      ''');

        batch.execute('''
        CREATE TABLE seance_categorie (
          seance_id     INTEGER NOT NULL,
          categorie_id  INTEGER NOT NULL,
          PRIMARY KEY (seance_id, categorie_id),
          FOREIGN KEY (seance_id)    REFERENCES seance(id)    ON DELETE CASCADE,
          FOREIGN KEY (categorie_id) REFERENCES categorie(id) ON DELETE CASCADE
        )
      ''');

        batch.execute('CREATE INDEX idx_seance_date ON seance(date)');
        batch.execute(
            'CREATE INDEX idx_seance_categorie_categorie ON seance_categorie(categorie_id)');
        batch
            .execute('CREATE INDEX idx_exercice_seance ON exercice(seance_id)');

        // Supprimer une catégorie supprime aussi les séances liées.
        // Attention : une séance classée dans « Service » et « Physique »
        // est supprimée si on supprime « Service », même si elle appartient
        // aussi à « Physique ». C'est le comportement demandé au départ.
        batch.execute('''
        CREATE TRIGGER supprime_seances_de_categorie
        BEFORE DELETE ON categorie
        BEGIN
          DELETE FROM seance
          WHERE id IN (
            SELECT seance_id FROM seance_categorie
            WHERE categorie_id = OLD.id
          );
        END
      ''');

        for (final nom in kSeedBallColors) {
          batch.insert('couleur_balle', {'nom': nom});
        }
        for (final nom in kSeedCategories) {
          batch.insert('categorie', {'nom': nom});
        }

        await batch.commit(noResult: true);
        await _createCalendarTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2 : ajout de l'heure de début (facultative) pour le
        // calendrier. Les séances existantes gardent `NULL` et affichent
        // seulement leur durée jusqu'à ce qu'elles soient modifiées.
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE seance ADD COLUMN heure_debut TEXT');
        }

        // v2 -> v3 : suppression de `lieu` et `notes`, ajout des exercices.
        // SQLite ne sait pas retirer plusieurs colonnes de façon portable :
        // on reconstruit la table en conservant les séances et leurs liens
        // avec les catégories.
        if (oldVersion < 3) {
          await _migrateSeanceToV3(db);
        }

        // v3 -> v4 : jours et mois du calendrier en base. Les séances
        // existantes ne sont pas touchées.
        if (oldVersion < 4) {
          await _createCalendarTables(db);
        }
      },
    ),
  );
}

/// Ferme la base (utile pour les tests).
Future<void> closeAppDatabase(Database db) => db.close();

/// Crée et remplit les tables `jour_semaine` et `mois`.
Future<void> _createCalendarTables(Database db) async {
  final batch = db.batch();

  batch.execute('''
    CREATE TABLE jour_semaine (
      id          INTEGER PRIMARY KEY CHECK (id BETWEEN 1 AND 7),
      nom         TEXT NOT NULL UNIQUE,
      abreviation TEXT NOT NULL UNIQUE
    )
  ''');

  batch.execute('''
    CREATE TABLE mois (
      id          INTEGER PRIMARY KEY CHECK (id BETWEEN 1 AND 12),
      nom         TEXT NOT NULL UNIQUE,
      abreviation TEXT NOT NULL UNIQUE
    )
  ''');

  for (final (index, (nom, abreviation)) in kSeedWeekdays.indexed) {
    batch.insert('jour_semaine',
        {'id': index + 1, 'nom': nom, 'abreviation': abreviation});
  }
  for (final (index, (nom, abreviation)) in kSeedMonths.indexed) {
    batch.insert(
        'mois', {'id': index + 1, 'nom': nom, 'abreviation': abreviation});
  }

  await batch.commit(noResult: true);
}

/// Migration v2 -> v3 : nouvelle table `seance` sans `lieu`/`notes`.
///
/// Les liens séance <-> catégorie sont copiés dans une table temporaire,
/// puis restaurés : la suppression de l'ancienne table ne doit rien perdre.
Future<void> _migrateSeanceToV3(Database db) async {
  await db.execute('DROP TRIGGER IF EXISTS supprime_seances_de_categorie');

  await db.execute('''
    CREATE TEMP TABLE seance_categorie_sauvegarde AS
    SELECT seance_id, categorie_id FROM seance_categorie
  ''');
  await db.execute('DELETE FROM seance_categorie');

  await db.execute('''
    CREATE TABLE seance_v3 (
      id                INTEGER PRIMARY KEY AUTOINCREMENT,
      date              TEXT NOT NULL,
      duree_minutes     INTEGER NOT NULL CHECK (duree_minutes > 0),
      intensite         INTEGER NOT NULL CHECK (intensite BETWEEN 1 AND 5),
      couleur_balle_id  INTEGER NOT NULL,
      heure_debut       TEXT,
      FOREIGN KEY (couleur_balle_id) REFERENCES couleur_balle(id)
        ON DELETE RESTRICT
    )
  ''');

  await db.execute('''
    INSERT INTO seance_v3
      (id, date, duree_minutes, intensite, couleur_balle_id, heure_debut)
    SELECT id, date, duree_minutes, intensite, couleur_balle_id, heure_debut
    FROM seance
  ''');

  await db.execute('DROP TABLE seance');
  await db.execute('ALTER TABLE seance_v3 RENAME TO seance');
  await db.execute('CREATE INDEX idx_seance_date ON seance(date)');

  await db.execute('''
    INSERT INTO seance_categorie (seance_id, categorie_id)
    SELECT seance_id, categorie_id FROM seance_categorie_sauvegarde
  ''');
  await db.execute('DROP TABLE seance_categorie_sauvegarde');

  await db.execute('''
    CREATE TRIGGER supprime_seances_de_categorie
    BEFORE DELETE ON categorie
    BEGIN
      DELETE FROM seance
      WHERE id IN (
        SELECT seance_id FROM seance_categorie
        WHERE categorie_id = OLD.id
      );
    END
  ''');

  await db.execute('''
    CREATE TABLE exercice (
      id                 INTEGER PRIMARY KEY AUTOINCREMENT,
      seance_id          INTEGER NOT NULL,
      nom                TEXT NOT NULL,
      points_travailles  TEXT NOT NULL DEFAULT '',
      deroulement        TEXT NOT NULL DEFAULT '',
      image              BLOB,
      FOREIGN KEY (seance_id) REFERENCES seance(id) ON DELETE CASCADE
    )
  ''');
  await db.execute('CREATE INDEX idx_exercice_seance ON exercice(seance_id)');
}
