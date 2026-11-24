// Fabrique le fichier à importer dans l'appli (Exercices → ⋮ → Importer
// les images) : toutes les images des exercices liés à la bibliothèque.
//
//   node tools/schemas/paquet.js
//
// Seuls les fichiers de exercices/ qui ont une clé
// "exercice": { "id": 12, "nom": "Nom exact dans l'appli" } sont inclus.
// L'id et le nom viennent de la liste copiée depuis l'appli
// (Exercices → ⋮ → Copier la liste des exercices).

const fs = require('fs');
const path = require('path');
const { fichiersExercices, rendre, DOSSIER } = require('./generer');

async function main() {
  const lies = fichiersExercices().filter(
    (f) => JSON.parse(fs.readFileSync(f, 'utf8')).exercice,
  );
  if (!lies.length) {
    console.error('Aucun fichier de exercices/ n\'a de clé "exercice".');
    process.exit(1);
  }

  const images = (await rendre(lies)).map(({ spec, png }) => ({
    exercice_id: spec.exercice.id ?? null,
    nom: spec.exercice.nom,
    image_base64: fs.readFileSync(png).toString('base64'),
  }));

  const date = new Date().toISOString().slice(0, 10);
  const cible = path.join(DOSSIER, 'paquets', `images-${date}.json`);
  fs.mkdirSync(path.dirname(cible), { recursive: true });
  fs.writeFileSync(
    cible,
    JSON.stringify({ format: 'tennistrack-images', version: 1, images }),
  );
  const mo = (fs.statSync(cible).size / 1024 / 1024).toFixed(1);
  console.log(`\n📦 ${path.relative(process.cwd(), cible)} : ${images.length} image(s), ${mo} Mo`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
