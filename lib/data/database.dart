import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Version du schéma. À incrémenter à chaque changement de structure,
/// puis ajouter la migration correspondante dans [onUpgrade].
const int kDatabaseVersion = 7;

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
  'Attaque',
  'Défense',
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
        await _createExerciseTables(db);
        await _addExerciseDuration(db);
        await _addSessionSetupAndPackUp(db);
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

        // v4 -> v5 : bibliothèque d'exercices partagés entre les séances,
        // et nouvelles catégories Attaque et Défense.
        if (oldVersion < 5) {
          await _migrateExercisesToV5(db);
        }

        // v5 -> v6 : durée facultative des exercices. Les exercices
        // existants n'ont pas de durée (`NULL`).
        if (oldVersion < 6) {
          await _addExerciseDuration(db);
        }

        // v6 -> v7 : temps de préparation et de rangement des séances.
        // Les séances existantes en ont 0.
        if (oldVersion < 7) {
          await _addSessionSetupAndPackUp(db);
        }
      },
    ),
  );
}

/// Ferme la base (utile pour les tests).
Future<void> closeAppDatabase(Database db) => db.close();

/// Crée la bibliothèque d'exercices et ses liens.
///
/// Un exercice existe une seule fois : le modifier met à jour toutes les
/// séances qui l'utilisent via `seance_exercice`.
Future<void> _createExerciseTables(Database db) async {
  final batch = db.batch();

  batch.execute('''
    CREATE TABLE exercice (
      id                 INTEGER PRIMARY KEY AUTOINCREMENT,
      nom                TEXT NOT NULL,
      points_travailles  TEXT NOT NULL DEFAULT '',
      deroulement        TEXT NOT NULL DEFAULT '',
      image              BLOB
    )
  ''');

  batch.execute('''
    CREATE TABLE seance_exercice (
      seance_id    INTEGER NOT NULL,
      exercice_id  INTEGER NOT NULL,
      ordre        INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (seance_id, exercice_id),
      FOREIGN KEY (seance_id)   REFERENCES seance(id)   ON DELETE CASCADE,
      FOREIGN KEY (exercice_id) REFERENCES exercice(id) ON DELETE CASCADE
    )
  ''');

  batch.execute('''
    CREATE TABLE exercice_categorie (
      exercice_id   INTEGER NOT NULL,
      categorie_id  INTEGER NOT NULL,
      PRIMARY KEY (exercice_id, categorie_id),
      FOREIGN KEY (exercice_id)  REFERENCES exercice(id)  ON DELETE CASCADE,
      FOREIGN KEY (categorie_id) REFERENCES categorie(id) ON DELETE CASCADE
    )
  ''');

  batch.execute('''
    CREATE TABLE exercice_couleur_balle (
      exercice_id       INTEGER NOT NULL,
      couleur_balle_id  INTEGER NOT NULL,
      PRIMARY KEY (exercice_id, couleur_balle_id),
      FOREIGN KEY (exercice_id)      REFERENCES exercice(id)      ON DELETE CASCADE,
      FOREIGN KEY (couleur_balle_id) REFERENCES couleur_balle(id) ON DELETE CASCADE
    )
  ''');

  batch.execute(
      'CREATE INDEX idx_seance_exercice_exercice ON seance_exercice(exercice_id)');
  batch.execute(
      'CREATE INDEX idx_exercice_categorie_categorie ON exercice_categorie(categorie_id)');
  batch.execute(
      'CREATE INDEX idx_exercice_couleur_couleur ON exercice_couleur_balle(couleur_balle_id)');

  await batch.commit(noResult: true);
}

/// Ajoute le temps de préparation (avant le cours) et de rangement (après),
/// en minutes. Ils s'ajoutent à la durée du cours dans les statistiques.
Future<void> _addSessionSetupAndPackUp(Database db) async {
  await db.execute(
    'ALTER TABLE seance ADD COLUMN preparation_minutes INTEGER NOT NULL '
    'DEFAULT 0 CHECK (preparation_minutes >= 0)',
  );
  await db.execute(
    'ALTER TABLE seance ADD COLUMN rangement_minutes INTEGER NOT NULL '
    'DEFAULT 0 CHECK (rangement_minutes >= 0)',
  );
}

/// Ajoute la durée de l'exercice, en minutes (facultative).
///
/// Volontairement séparée de [_createExerciseTables] : la migration v4 -> v5
/// recrée la table au format v5, puis la v6 ajoute la colonne.
Future<void> _addExerciseDuration(Database db) => db.execute(
      'ALTER TABLE exercice ADD COLUMN duree_minutes INTEGER '
      'CHECK (duree_minutes IS NULL OR duree_minutes > 0)',
    );

/// Migration v4 -> v5 : chaque exercice lié à une séance rejoint la
/// bibliothèque.
///
/// Les exercices au contenu strictement identique sont fusionnés. Chaque
/// exercice hérite des catégories et des couleurs de balle de ses séances.
Future<void> _migrateExercisesToV5(Database db) async {
  await db.execute('ALTER TABLE exercice RENAME TO exercice_ancien');
  await db.execute('DROP INDEX IF EXISTS idx_exercice_seance');
  await _createExerciseTables(db);

  await db.execute('''
    CREATE TEMP TABLE exercice_correspondance AS
    SELECT e.id AS ancien_id,
           e.seance_id AS seance_id,
           (SELECT MIN(d.id) FROM exercice_ancien d
            WHERE d.nom = e.nom
              AND d.points_travailles = e.points_travailles
              AND d.deroulement = e.deroulement
              AND d.image IS e.image) AS nouveau_id
    FROM exercice_ancien e
  ''');

  await db.execute('''
    INSERT INTO exercice (id, nom, points_travailles, deroulement, image)
    SELECT id, nom, points_travailles, deroulement, image
    FROM exercice_ancien
    WHERE id IN (SELECT nouveau_id FROM exercice_correspondance)
  ''');

  await db.execute('''
    INSERT OR IGNORE INTO seance_exercice (seance_id, exercice_id, ordre)
    SELECT seance_id, nouveau_id, ancien_id
    FROM exercice_correspondance
    ORDER BY ancien_id
  ''');

  await db.execute('''
    INSERT OR IGNORE INTO exercice_categorie (exercice_id, categorie_id)
    SELECT c.nouveau_id, sc.categorie_id
    FROM exercice_correspondance c
    JOIN seance_categorie sc ON sc.seance_id = c.seance_id
  ''');

  await db.execute('''
    INSERT OR IGNORE INTO exercice_couleur_balle (exercice_id, couleur_balle_id)
    SELECT c.nouveau_id, s.couleur_balle_id
    FROM exercice_correspondance c
    JOIN seance s ON s.id = c.seance_id
  ''');

  await db.execute('DROP TABLE exercice_correspondance');
  await db.execute('DROP TABLE exercice_ancien');

  // OR IGNORE : ne crée pas de doublon si la catégorie existe déjà.
  await db.execute("INSERT OR IGNORE INTO categorie (nom) VALUES ('Attaque')");
  await db.execute("INSERT OR IGNORE INTO categorie (nom) VALUES ('Défense')");
}

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
