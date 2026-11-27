// Génère les schémas d'exercices (PNG) à partir de fichiers JSON.
//
//   node tools/schemas/generer.js                 → tous les exercices
//   node tools/schemas/generer.js exercices/x.json → un seul
//
// Coordonnées en mètres, origine au centre du filet :
//   x : de -5,485 (gauche) à +5,485 (droite) — couloirs compris
//   y : de -11,885 (fond de court du haut) à +11,885 (fond du bas)
// Repères utiles : couloir simple x = ±4,115 ; ligne de service y = ±6,40.

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const DOSSIER = __dirname;
const S = 50; // pixels par mètre
// Taille des symboles sur le terrain (option `tailleSymboles` du JSON).
let K = 1;
const RECUL = 1.4; // marge autour du terrain (m)
const DEMI_L = 10.97 / 2;
const DEMI_H = 23.77 / 2;
const SIMPLE = 8.23 / 2;
const SERVICE = 6.4;

const COULEURS = {
  exterieur: '#3F8F63',
  terrain: '#2F6DB5',
  ligne: '#FFFFFF',
  plot: '#FF7A00',
  pastille: '#E9FF00',
  languette: '#FFFFFF',
  porte: '#FF3D7F',
  balle: '#E9FF00',
  deplacement: '#FFFFFF',
  encre: '#24234F',
  joueurs: ['#E53935', '#8E24AA', '#3949AB', '#F4511E'],
  entraineur: '#00897B',
  zone: '#FFEB3B',
  // Couleur fixe par lettre : un joueur garde sa couleur, fantôme compris.
  parNom: { A: '#E53935', B: '#8E24AA', C: '#3949AB', D: '#F4511E', R: '#6D4C41' },
  // Couleurs des plots de couleur : [x, y, "bleu"].
  plots: {
    orange: '#FF7A00',
    bleu: '#1E88E5',
    rouge: '#E53935',
    jaune: '#FDD835',
    vert: '#43A047',
  },
};

const LARGEUR = (2 * DEMI_L + 2 * RECUL) * S;
const HAUTEUR_TERRAIN = (2 * DEMI_H + 2 * RECUL) * S;

const px = (x) => (x + DEMI_L + RECUL) * S;
const py = (y) => (y + DEMI_H + RECUL) * S;

function terrain() {
  const l = (x1, y1, x2, y2) =>
    `<line x1="${px(x1)}" y1="${py(y1)}" x2="${px(x2)}" y2="${py(y2)}"/>`;
  return `
  <rect width="${LARGEUR}" height="${HAUTEUR_TERRAIN}" fill="${COULEURS.exterieur}"/>
  <rect x="${px(-DEMI_L)}" y="${py(-DEMI_H)}" width="${2 * DEMI_L * S}"
        height="${2 * DEMI_H * S}" fill="${COULEURS.terrain}"/>
  <g stroke="${COULEURS.ligne}" stroke-width="4" stroke-linecap="square">
    <rect x="${px(-DEMI_L)}" y="${py(-DEMI_H)}" width="${2 * DEMI_L * S}"
          height="${2 * DEMI_H * S}" fill="none"/>
    ${l(-SIMPLE, -DEMI_H, -SIMPLE, DEMI_H)}
    ${l(SIMPLE, -DEMI_H, SIMPLE, DEMI_H)}
    ${l(-SIMPLE, -SERVICE, SIMPLE, -SERVICE)}
    ${l(-SIMPLE, SERVICE, SIMPLE, SERVICE)}
    ${l(0, -SERVICE, 0, SERVICE)}
    ${l(0, -DEMI_H, 0, -DEMI_H + 0.3)}
    ${l(0, DEMI_H, 0, DEMI_H - 0.3)}
  </g>
  <line x1="${px(-DEMI_L - 0.9)}" y1="${py(0)}" x2="${px(DEMI_L + 0.9)}" y2="${py(0)}"
        stroke="#1B1B1B" stroke-width="7"/>
  <line x1="${px(-DEMI_L - 0.9)}" y1="${py(0)}" x2="${px(DEMI_L + 0.9)}" y2="${py(0)}"
        stroke="#FFFFFF" stroke-width="2" stroke-dasharray="3 5"/>
  <circle cx="${px(-DEMI_L - 0.9)}" cy="${py(0)}" r="6" fill="#1B1B1B"/>
  <circle cx="${px(DEMI_L + 0.9)}" cy="${py(0)}" r="6" fill="#1B1B1B"/>`;
}

// --- Symboles -------------------------------------------------------------

const plot = (cx, cy, couleur = 'orange') => `
  <g transform="translate(${cx} ${cy})">
    <circle r="${15 * K}" fill="${COULEURS.plots[couleur] ?? COULEURS.plot}"
            stroke="#1B1B1B" stroke-opacity="0.6" stroke-width="3"/>
    <circle r="${6 * K}" fill="#FFFFFF" opacity="0.9"/>
  </g>`;

// Plus large qu'un joueur : reste visible quand un joueur est dessus.
const pastille = (cx, cy, r = 33 * K) => `
  <circle cx="${cx}" cy="${cy}" r="${r}" fill="${COULEURS.pastille}"
          stroke="${COULEURS.encre}" stroke-width="3"/>`;

const languette = (x1, y1, x2, y2) => `
  <line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${COULEURS.languette}"
        stroke-width="7" stroke-dasharray="16 10" stroke-linecap="butt"/>`;

// Porte : base triangulaire avec un jalon au centre. `angle` en degrés,
// 0 = pointe vers le bas.
const porte = (cx, cy, angle = 0) => `
  <g transform="translate(${cx} ${cy}) rotate(${angle})">
    <polygon points="-15,-12 15,-12 0,15" fill="${COULEURS.porte}"
             stroke="#5A0A28" stroke-width="3" stroke-linejoin="round"/>
    <circle r="4" fill="#FFFFFF"/>
  </g>`;

// `fantome` : position visée (joueur en transparence, contour pointillé).
const joueur = (cx, cy, nom, couleur, fantome = false) => `
  <g transform="translate(${cx} ${cy})" ${fantome ? 'opacity="0.55"' : ''}>
    <circle r="${24 * K}" fill="${couleur}" stroke="#FFFFFF" stroke-width="${4 * K}"
            ${fantome ? 'stroke-dasharray="7 5"' : ''}/>
    <text y="${8 * K}" text-anchor="middle" font-size="${22 * K}" font-weight="700"
          fill="#FFFFFF">${nom}</text>
  </g>`;

const balleIcone = (cx, cy) => `
  <g transform="translate(${cx} ${cy})">
    <circle r="9" fill="${COULEURS.balle}" stroke="${COULEURS.encre}" stroke-width="2"/>
    <path d="M -6 -6 Q 0 0 -6 6 M 6 -6 Q 0 0 6 6" fill="none"
          stroke="${COULEURS.encre}" stroke-width="1.5"/>
  </g>`;

const badge = (cx, cy, texte) => `
  <g transform="translate(${cx} ${cy})">
    <circle r="${15 * K}" fill="${COULEURS.encre}" stroke="#FFFFFF" stroke-width="3"/>
    <text y="${6 * K}" text-anchor="middle" font-size="${17 * K}" font-weight="700"
          fill="#FFFFFF">${texte}</text>
  </g>`;

// Flèche (droite ou courbe), raccourcie de `ecart` px à chaque bout pour ne
// pas recouvrir les joueurs ou les plots.
function fleche({ de, a, courbe = 0, couleur, pointilles, numero, posNumero = 0.5, ecartDebut = 30, ecartFin = 22, epaisseur = 5 }) {
  const [x1, y1] = [px(de[0]), py(de[1])];
  const [x2, y2] = [px(a[0]), py(a[1])];
  const dx = x2 - x1;
  const dy = y2 - y1;
  const long = Math.hypot(dx, dy);
  // Point de contrôle décalé perpendiculairement.
  const cx = (x1 + x2) / 2 - (dy / long) * courbe * long;
  const cy = (y1 + y2) / 2 + (dx / long) * courbe * long;

  const point = (t) => [
    (1 - t) ** 2 * x1 + 2 * (1 - t) * t * cx + t ** 2 * x2,
    (1 - t) ** 2 * y1 + 2 * (1 - t) * t * cy + t ** 2 * y2,
  ];
  // Paramètres t correspondant à l'écart voulu (approximation suffisante).
  const t0 = Math.min(ecartDebut / long, 0.4);
  const t1 = 1 - Math.min(ecartFin / long, 0.4);
  const [ax, ay] = point(t0);
  const [bx, by] = point(t1);
  // Contrôle de la sous-courbe [t0, t1].
  const ctrl = (t) => [
    (1 - t) * x1 + t * cx,
    (1 - t) * y1 + t * cy,
  ];
  const [c0x, c0y] = ctrl(t0);
  const [c1x, c1y] = [(1 - t1) * cx + t1 * x2, (1 - t1) * cy + t1 * y2];
  // Intersection des tangentes pour le nouveau point de contrôle.
  const den = (c0x - ax) * (by - c1y) - (c0y - ay) * (bx - c1x);
  let qx = (ax + bx) / 2;
  let qy = (ay + by) / 2;
  if (Math.abs(den) > 1e-6) {
    const s = ((bx - ax) * (by - c1y) - (by - ay) * (bx - c1x)) / den;
    qx = ax + s * (c0x - ax);
    qy = ay + s * (c0y - ay);
  }

  // Pointe de flèche orientée selon la tangente finale.
  const angle = Math.atan2(by - qy, bx - qx);
  const t = 18 * K;
  const pointe = [
    [bx, by],
    [bx - t * Math.cos(angle - 0.45), by - t * Math.sin(angle - 0.45)],
    [bx - t * Math.cos(angle + 0.45), by - t * Math.sin(angle + 0.45)],
  ];
  // Le trait s'arrête à la base de la pointe.
  const fx = bx - 12 * K * Math.cos(angle);
  const fy = by - 12 * K * Math.sin(angle);

  // Numéro posé à côté du trait (côté extérieur de la courbe) pour ne pas
  // cacher la flèche.
  const [nx, ny] = [-dy / long, dx / long];
  const sens = courbe < 0 ? -1 : 1;
  const [px0, py0] = point(posNumero);
  const [mx, my] = [px0 + nx * sens * 26 * K, py0 + ny * sens * 26 * K];
  return `
  <path d="M ${ax} ${ay} Q ${qx} ${qy} ${fx} ${fy}" fill="none" stroke="#000"
        stroke-opacity="0.25" stroke-width="${epaisseur * K + 4}"
        ${pointilles ? 'stroke-dasharray="14 10"' : ''} stroke-linecap="round"/>
  <path d="M ${ax} ${ay} Q ${qx} ${qy} ${fx} ${fy}" fill="none" stroke="${couleur}"
        stroke-width="${epaisseur * K}" ${pointilles ? 'stroke-dasharray="14 10"' : ''}
        stroke-linecap="round"/>
  <polygon points="${pointe.map((p) => p.join(',')).join(' ')}" fill="${couleur}"
           stroke="#000" stroke-opacity="0.25" stroke-width="2"/>
  ${numero != null ? badge(mx, my, numero) : ''}`;
}

// Zone à viser : rectangle jaune translucide à bord pointillé.
// Hachures jaunes (définies une fois dans <defs>) : lisibles sur le bleu.
const zone = (x1, y1, x2, y2) => `
  <rect x="${Math.min(x1, x2)}" y="${Math.min(y1, y2)}" width="${Math.abs(x2 - x1)}"
        height="${Math.abs(y2 - y1)}" fill="url(#hachures)"
        stroke="${COULEURS.zone}" stroke-width="3" stroke-dasharray="10 6"/>`;

const DEFS = `<defs>
  <pattern id="hachures" width="14" height="14" patternUnits="userSpaceOnUse"
           patternTransform="rotate(45)">
    <rect width="14" height="14" fill="${'#FFEB3B'}" fill-opacity="0.18"/>
    <rect width="6" height="14" fill="${'#FFEB3B'}" fill-opacity="0.75"/>
  </pattern>
</defs>`;

const echapper = (t) =>
  String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

/// Coupe un texte en lignes d'au plus [max] caractères, aux espaces.
function couper(texte, max = 46) {
  const lignes = [];
  let ligne = '';
  for (const mot of String(texte).split(' ')) {
    if (ligne && (ligne + ' ' + mot).length > max) {
      lignes.push(ligne);
      ligne = mot;
    } else {
      ligne = ligne ? `${ligne} ${mot}` : mot;
    }
  }
  if (ligne) lignes.push(ligne);
  return lignes;
}

// --- Légende --------------------------------------------------------------

function legende(spec) {
  const items = [];
  const joueurs = spec.joueurs ?? [];
  if (joueurs.some((j) => j.role !== 'entraineur' && !j.fantome)) items.push(['joueur', 'Joueur']);
  if (joueurs.some((j) => j.role === 'entraineur')) items.push(['entraineur', 'Entraîneur']);
  if (spec.joueurs?.some((j) => j.fantome)) items.push(['fantome', 'Placement visé']);
  if (spec.plots?.length) items.push(['plot', 'Plot']);
  if (spec.pastilles?.length) items.push(['pastille', 'Pastille']);
  if (spec.languettes?.length) items.push(['languette', 'Languette']);
  if (spec.portes?.length) items.push(['porte', 'Porte']);
  if (spec.balles?.length) items.push(['balle', 'Balle']);
  if (spec.deplacements?.length) items.push(['deplacement', 'Déplacement']);
  if (spec.zones?.length) items.push(['zone', spec.legendeZone ?? 'Zone à viser']);
  if (spec.ballesPosees?.length) items.push(['ballePosee', 'Balle posée']);
  for (const l of spec.lignes ?? []) {
    if (l.legende) items.push([`ligne:${l.couleur ?? '#E53935'}`, l.legende]);
  }

  // Textes longs coupés en plusieurs lignes (environ 44 caractères).
  const etapes = (spec.etapes ?? []).map((t) => couper(t));
  const notes = (spec.notes ?? []).map((t) => couper(`• ${t}`));
  const nbLignesTexte =
    etapes.reduce((n, l) => n + l.length, 0) + notes.reduce((n, l) => n + l.length, 0);

  const colonnes = 2;
  const hLigne = 56;
  const lignes = Math.ceil(items.length / colonnes);
  const hauteur = 40 + lignes * hLigne + (nbLignesTexte ? 24 + nbLignesTexte * 34 : 0) + 20;

  const symbole = (type, x, y) => {
    if (type.startsWith('ligne:')) {
      return `<line x1="${x - 30}" y1="${y}" x2="${x + 30}" y2="${y}"
          stroke="${type.slice(6)}" stroke-width="6" stroke-linecap="round"/>`;
    }
    switch (type) {
      case 'joueur': return joueur(x, y, 'A', COULEURS.joueurs[0]);
      case 'entraineur': return joueur(x, y, 'E', COULEURS.entraineur);
      case 'zone': return zone(x - 28, y - 16, x + 28, y + 16);
      case 'ballePosee': return balleIcone(x, y);
      case 'fantome': return joueur(x, y, 'A', COULEURS.joueurs[0], true);
      case 'plot': return plot(x, y);
      case 'pastille': return pastille(x, y, 19);
      case 'languette': return languette(x - 26, y, x + 26, y);
      case 'porte': return porte(x, y);
      case 'balle': return `<line x1="${x - 30}" y1="${y}" x2="${x + 20}" y2="${y}"
          stroke="${COULEURS.balle}" stroke-width="5" stroke-dasharray="14 10"/>
          <polygon points="${x + 32},${y} ${x + 16},${y - 8} ${x + 16},${y + 8}" fill="${COULEURS.balle}"/>`;
      case 'deplacement': return `<line x1="${x - 30}" y1="${y}" x2="${x + 20}" y2="${y}"
          stroke="${COULEURS.deplacement}" stroke-width="5"/>
          <polygon points="${x + 32},${y} ${x + 16},${y - 8} ${x + 16},${y + 8}" fill="${COULEURS.deplacement}"/>`;
    }
  };

  const largeurCol = (LARGEUR - 60) / colonnes;
  let svg = `<rect y="0" width="${LARGEUR}" height="${hauteur}" fill="#FAFAFD"/>`;
  items.forEach(([type, texte], i) => {
    const col = i % colonnes;
    const lig = Math.floor(i / colonnes);
    const x = 30 + col * largeurCol + 40;
    const y = 40 + lig * hLigne;
    // Fond sombre pour les symboles blancs / jaunes.
    svg += `<rect x="${x - 40}" y="${y - 24}" width="80" height="48" rx="10"
                  fill="${COULEURS.terrain}"/>`;
    svg += symbole(type, x, y);
    svg += `<text x="${x + 56}" y="${y + 8}" font-size="23" fill="${COULEURS.encre}">${texte}</text>`;
  });

  let y = 40 + lignes * hLigne + 14;
  etapes.forEach((lignesEtape, i) => {
    svg += badge(70, y, i + 1);
    for (const ligne of lignesEtape) {
      svg += `<text x="100" y="${y + 8}" font-size="22" fill="${COULEURS.encre}">${echapper(ligne)}</text>`;
      y += 34;
    }
  });
  for (const lignesNote of notes) {
    lignesNote.forEach((ligne, i) => {
      svg += `<text x="${i === 0 ? 58 : 76}" y="${y + 8}" font-size="21" font-style="italic"
                fill="${COULEURS.encre}" opacity="0.8">${echapper(ligne)}</text>`;
      y += 34;
    });
  }
  return { svg, hauteur };
}

// --- Assemblage -----------------------------------------------------------

function construireSvg(spec) {
  K = spec.tailleSymboles ?? 1;
  const couleurJoueur = (j, i) =>
    j.couleur ?? COULEURS.parNom[j.nom] ?? COULEURS.joueurs[i % COULEURS.joueurs.length];
  let corps = terrain();

  for (const [[x1, y1], [x2, y2]] of spec.languettes ?? []) {
    corps += languette(px(x1), py(y1), px(x2), py(y2));
  }
  // Parties du terrain non utilisées, assombries : [[x1, y1], [x2, y2]].
  for (const [[x1, y1], [x2, y2]] of spec.masques ?? []) {
    corps += `<rect x="${px(Math.min(x1, x2))}" y="${py(Math.min(y1, y2))}"
      width="${Math.abs(x2 - x1) * S}" height="${Math.abs(y2 - y1) * S}"
      fill="#0B1530" opacity="0.5"/>`;
  }
  // Zones à viser : { de: [x, y], a: [x, y], texte?: "..." }.
  for (const z of spec.zones ?? []) {
    corps += zone(px(z.de[0]), py(z.de[1]), px(z.a[0]), py(z.a[1]));
    if (z.texte) {
      corps += `<text x="${px((z.de[0] + z.a[0]) / 2)}" y="${py((z.de[1] + z.a[1]) / 2)}"
        text-anchor="middle" dominant-baseline="middle" font-size="${z.taille ?? 16}"
        font-weight="700" fill="#FFFFFF">${echapper(z.texte)}</text>`;
    }
  }
  // Lignes droites (fil au-dessus du filet…) : { de, a, couleur?, legende? }.
  for (const l of spec.lignes ?? []) {
    corps += `<line x1="${px(l.de[0])}" y1="${py(l.de[1])}" x2="${px(l.a[0])}" y2="${py(l.a[1])}"
      stroke="${l.couleur ?? '#E53935'}" stroke-width="${l.epaisseur ?? 6}" stroke-linecap="round"/>`;
  }
  // Textes posés sur le terrain (noms de zones…).
  for (const t of spec.textes ?? []) {
    corps += `<text x="${px(t.pos[0])}" y="${py(t.pos[1])}" text-anchor="middle"
      dominant-baseline="middle" font-size="${t.taille ?? 30}" font-weight="700"
      letter-spacing="${t.espacement ?? 3}" fill="#FFFFFF" opacity="${t.opacite ?? 0.55}">${t.texte}</text>`;
  }
  for (const [x, y] of spec.pastilles ?? []) corps += pastille(px(x), py(y));
  for (const b of spec.balles ?? []) {
    corps += fleche({ ...b, couleur: COULEURS.balle, pointilles: true, ecartDebut: b.ecartDebut ?? 30, ecartFin: b.ecartFin ?? 30 });
  }
  for (const d of spec.deplacements ?? []) {
    corps += fleche({ ...d, couleur: COULEURS.deplacement });
  }
  for (const [x, y, couleur] of spec.plots ?? []) corps += plot(px(x), py(y), couleur);
  for (const [x, y] of spec.ballesPosees ?? []) corps += balleIcone(px(x), py(y) - 4);
  for (const [x, y, angle] of spec.portes ?? []) corps += porte(px(x), py(y), angle);
  (spec.joueurs ?? []).forEach((j, i) => {
    const couleur = j.role === 'entraineur' ? (j.couleur ?? COULEURS.entraineur) : couleurJoueur(j, i);
    corps += joueur(px(j.pos[0]), py(j.pos[1]), j.nom, couleur, j.fantome);
  });
  for (const b of spec.balles ?? []) {
    if (b.icone) corps += balleIcone(px(b.icone[0]), py(b.icone[1]));
  }

  K = 1; // la légende garde toujours la même taille
  const { svg: svgLegende, hauteur } = legende(spec);
  const hauteurTotale = HAUTEUR_TERRAIN + hauteur;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${LARGEUR}" height="${hauteurTotale}"
      viewBox="0 0 ${LARGEUR} ${hauteurTotale}" font-family="DejaVu Sans, Liberation Sans, sans-serif">
    ${DEFS}
    ${corps}
    <g transform="translate(0 ${HAUTEUR_TERRAIN})">${svgLegende}</g>
  </svg>`;
}

// Côté le plus long des images, comme les images importées dans l'appli.
const COTE_MAX = 1600;

/// Liste les fichiers JSON d'exercices (tous, ou ceux passés en argument).
function fichiersExercices(args = []) {
  return args.length
    ? args.map((f) => path.resolve(f))
    : fs.readdirSync(path.join(DOSSIER, 'exercices'))
        .filter((f) => f.endsWith('.json'))
        .sort()
        .map((f) => path.join(DOSSIER, 'exercices', f));
}

/// Rend chaque fichier en PNG dans images/ et renvoie [{ fichier, spec, png }].
async function rendre(fichiers) {
  const navigateur = await chromium.launch();
  fs.mkdirSync(path.join(DOSSIER, 'images'), { recursive: true });
  const resultats = [];

  for (const fichier of fichiers) {
    const spec = JSON.parse(fs.readFileSync(fichier, 'utf8'));
    const svg = construireSvg(spec);
    const largeur = Number(svg.match(/width="([\d.]+)"/)[1]);
    const hauteur = Number(svg.match(/height="([\d.]+)"/)[1]);
    const echelle = Math.min(1.5, COTE_MAX / Math.max(largeur, hauteur));

    const page = await navigateur.newPage({ deviceScaleFactor: echelle });
    await page.setContent(`<html><body style="margin:0">${svg}</body></html>`);
    const nom = path.basename(fichier, '.json');
    const cible = path.join(DOSSIER, 'images', `${nom}.png`);
    await page.locator('svg').screenshot({ path: cible });
    await page.close();
    console.log(`✔ ${path.relative(process.cwd(), cible)}`);
    resultats.push({ fichier, spec, png: cible });
  }
  await navigateur.close();
  return resultats;
}

module.exports = { construireSvg, fichiersExercices, rendre, DOSSIER };

if (require.main === module) {
  rendre(fichiersExercices(process.argv.slice(2))).catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
