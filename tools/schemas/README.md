# Schémas d'exercices

Génère les images d'illustration des exercices (PNG), à importer ensuite
dans l'appli depuis la galerie du téléphone.

```bash
node tools/schemas/generer.js                                       # tous
node tools/schemas/generer.js tools/schemas/exercices/plot-et-replacement.json
```

Nécessite Node et Playwright (Chromium). Les images sortent dans
`tools/schemas/images/`.

## Décrire un exercice

Un fichier JSON par exercice dans `exercices/`. Coordonnées en **mètres**,
origine au centre du filet, terrain vu du dessus et vertical :

- `x` : -5,485 (gauche) → +5,485 (droite), couloirs compris ;
  couloir simple à x = ±4,115 ; ligne médiane à x = 0.
- `y` : -11,885 (fond du haut) → +11,885 (fond du bas) ;
  lignes de service à y = ±6,40 ; filet à y = 0.

| Clé | Format | Dessin |
| --- | --- | --- |
| `joueurs` | `[{ "nom": "A", "pos": [x, y], "couleur"?: "#hex", "fantome"?: true }]` | jeton de couleur (`fantome` : placement visé, en transparence) |
| `textes` | `[{ "pos": [x, y], "texte": "GAUCHE", "taille"?: 30, "opacite"?: 0.55 }]` | texte posé sur le terrain |
| `plots` | `[[x, y], …]` | plot orange |
| `pastilles` | `[[x, y], …]` | disque jaune (replacement) |
| `languettes` | `[[[x1, y1], [x2, y2]], …]` | trait blanc en pointillés |
| `portes` | `[[x, y, angle?], …]` | triangle rose (base + jalon) |
| `balles` | flèches (voir ci-dessous) | pointillés jaunes |
| `deplacements` | flèches | trait blanc |
| `etapes` | `["texte", …]` | liste numérotée sous la légende |

Une flèche : `{ "de": [x, y], "a": [x, y], "courbe": 0.3, "numero": 2 }`.
`courbe` (négatif = de l'autre côté) bombe la flèche, `numero` ajoute une
pastille numérotée à côté (`posNumero` de 0 à 1 pour la déplacer le long de
la flèche), `ecartDebut` / `ecartFin` (px) raccourcissent les extrémités.

La légende n'affiche que les éléments utilisés.
