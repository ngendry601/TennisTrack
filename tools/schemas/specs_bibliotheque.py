# Script qui a écrit les fichiers exercices/NN-*.json de la bibliothèque
# (positions de chaque exercice). Le relancer réécrit ces fichiers.
"""Écrit un fichier JSON par exercice dans tools/schemas/exercices/."""
import json, math, re, unicodedata, os

OUT = '/home/user/TennisTrack/tools/schemas/exercices'
SX, DX, BL, SL = 4.115, 5.485, 11.885, 6.4
EX, EY = 6.885, 13.285  # bords de l'image (avec marge)

# Masques usuels
COULOIRS = [[[-EX, -EY], [-SX, EY]], [[SX, -EY], [EX, EY]]]
def carres_seulement():
    """Seulement les carrés de service (terrain mini / balle rouge)."""
    return [[[-EX, -EY], [EX, -SL]], [[-EX, SL], [EX, EY]],
            [[-EX, -SL], [-SX, SL]], [[SX, -SL], [EX, SL]]]
def couloir_gauche_seul():
    """Demi-terrain de gauche (à l'écran) seulement."""
    return [[[-EX, -EY], [-SX, EY]], [[0, -EY], [EX, EY]]]

def slug(t):
    t = unicodedata.normalize('NFKD', t).encode('ascii', 'ignore').decode()
    return re.sub(r'[^a-z0-9]+', '-', t.lower()).strip('-')

def J(nom, x, y, **kw): return {'nom': nom, 'pos': [x, y], **kw}
def E(x, y): return {'nom': 'E', 'pos': [x, y], 'role': 'entraineur'}
def F(nom, x, y): return {'nom': nom, 'pos': [x, y], 'fantome': True}
def B(de, a, **kw): return {'de': de, 'a': a, **kw}

specs = {}

specs[(6, 'Arrêt après la frappe')] = dict(
    tailleSymboles=0.8,
    masques=couloir_gauche_seul()[:1] + [[[0, -EY], [EX, EY]],
             [[-SX, -EY], [0, -SL]], [[-SX, SL], [0, EY]]],
    zones=[{'de': [-4.0, -6.3], 'a': [-2.9, -4.9]}, {'de': [-1.2, -6.3], 'a': [-0.1, -4.9]}],
    joueurs=[J('A', -2.06, 5.0), J('B', -2.06, -1.6)],
    balles=[B([-2.06, -1.6], [-2.06, 4.4], courbe=0.15, numero=1, posNumero=0.5, ecartFin=18),
            B([-2.06, 5.0], [-3.45, -5.6], courbe=-0.05, numero=2, posNumero=0.6, ecartFin=10),
            B([-2.06, 5.0], [-0.65, -5.6], courbe=0.05, ecartFin=10)],
    etapes=['B lance la balle à la main vers A',
            'A frappe en visant une des deux zones',
            'Après la frappe, A reste en équilibre'],
    notes=['Plus facile : laisser plusieurs rebonds',
           'Plus difficile : B envoie à la raquette',
           'Plus difficile : les 2 joueurs jouent'],
)

specs[(40, 'Attaque CD')] = dict(
    masques=COULOIRS, legendeZone="Zone d'attaque",
    zones=[{'de': [-SX, -0.15], 'a': [SX, -3.2]}, {'de': [-SX, 0.15], 'a': [SX, 3.2]}],
    joueurs=[J('A', 0.5, 11.0), J('B', -0.5, -11.0)],
    balles=[B([0.5, 11.0], [-0.5, -10.4], courbe=-0.12, numero=1, posNumero=0.75),
            B([-0.5, -11.0], [1.8, 2.0], courbe=-0.1, numero=2, posNumero=0.3, ecartFin=10),
            B([1.6, 3.0], [-3.2, -9.5], courbe=-0.05, numero=4, posNumero=0.5, ecartDebut=22)],
    deplacements=[B([0.5, 11.0], [1.6, 3.4], courbe=0.12, numero=3, posNumero=0.55)],
    etapes=['5 échanges obligatoires avant de jouer le point',
            'La balle tombe entre le filet et le milieu des carrés de service',
            'A avance vers la balle',
            'A est obligé d’attaquer en coup droit'],
)

specs[(23, 'Coup droit')] = dict(
    masques=carres_seulement(), tailleSymboles=0.85,
    joueurs=[J('A', 0.8, 4.8), E(2.6, 2.4)],
    portes=[[1.2, -3.0, 0]], plots=[[-2.6, -5.2], [2.9, -5.2]],
    balles=[B([2.6, 2.4], [1.5, 4.4], courbe=0.2, numero=1, posNumero=0.5, ecartFin=14),
            B([0.8, 4.8], [1.2, -2.4], courbe=0.02, numero=2, posNumero=0.45, ecartFin=18),
            B([0.8, 4.8], [-2.5, -4.7], courbe=0.05, numero=3, posNumero=0.6, ecartFin=18)],
    etapes=['L’adulte lance la balle à la main',
            'Semaine 1 : la balle doit passer la porte',
            'Semaine 2 : le joueur vise les plots'],
    notes=['Semaine 3 : focus sur la préparation et la prise'],
)

specs[(36, 'Course frappe')] = dict(
    tailleSymboles=0.85,
    joueurs=[J('A', -4.8, 2.6), J('B', -4.8, 5.6)],
    plots=[[-1.2, 2.6], [-1.2, 5.6]], ballesPosees=[[-1.2, 2.6], [-1.2, 5.6]],
    deplacements=[B([-4.8, 2.6], [-1.6, 2.6], courbe=0.15, numero=1, posNumero=0.5, ecartFin=22),
                  B([-4.8, 5.6], [-1.6, 5.6], courbe=0.15, ecartFin=22)],
    balles=[B([-1.2, 2.6], [-0.4, -4.5], courbe=0.05, numero=2, posNumero=0.5, ecartDebut=22),
            B([-1.2, 5.6], [1.2, -5.5], courbe=0.05, ecartDebut=22)],
    etapes=['Départ dans le couloir : course jusqu’au plot',
            'Poser le ballon violet ou la balle rouge et frapper de l’autre côté'],
)

specs[(5, 'Différence CD/R')] = dict(
    masques=carres_seulement(), tailleSymboles=0.85,
    joueurs=[J('A', 0, 5.0), J('B', 0, -5.0)],
    plots=[[-3.9, 3.2, 'bleu'], [3.9, 3.2, 'rouge'], [3.9, -3.2, 'bleu'], [-3.9, -3.2, 'rouge']],
    textes=[{'pos': [-3.2, 1.9], 'texte': 'R', 'taille': 26, 'opacite': 0.9},
            {'pos': [3.2, 1.9], 'texte': 'CD', 'taille': 26, 'opacite': 0.9}],
    balles=[B([0, -5.0], [-2.6, 3.6], courbe=0.04, numero=1, posNumero=0.75, ecartFin=10),
            B([0, -5.0], [2.6, 3.6], courbe=-0.04, numero=2, posNumero=0.75, ecartFin=10)],
    etapes=['Balle du côté du plot bleu : revers. A annonce « Revers » (ou « Bleu »)',
            'Balle du côté du plot rouge : coup droit. A annonce « Coup droit » (ou « Rouge »)'],
    notes=['Plot bleu à gauche, rouge à droite, vus par le joueur qui frappe'],
)

specs[(14, 'Découverte volée')] = dict(
    masques=carres_seulement(), tailleSymboles=0.9,
    plots=[[-1.5, -3.0], [1.5, -3.0], [-1.5, 3.0], [1.5, 3.0]],
    joueurs=[J('A', 0, 3.0), J('B', 0, -3.0)],
    balles=[B([0, 3.0], [1.4, -2.5], courbe=0.1, numero=1, posNumero=0.5, ecartFin=14)],
    deplacements=[B([0, -3.0], [1.05, -2.9], courbe=-0.6, numero=2, posNumero=0.6, ecartDebut=22, ecartFin=16)],
    etapes=['A lance la balle à la main vers un des 2 plots d’en face',
            'B se déplace et attrape la balle avant le rebond'],
    notes=['Jeu de jambes en continu', 'Puis on inverse les rôles'],
)

specs[(42, 'Défense')] = dict(
    masques=COULOIRS, legendeZone='Zone de renvoi',
    zones=[{'de': [-SX, -6.7], 'a': [SX, -11.8], 'texte': 'Renvoi haut et profond'}],
    joueurs=[E(0.5, -4.0), J('A', -2.6, 11.0), J('B', 0, 11.3), J('C', 2.6, 11.0)],
    balles=[B([0.5, -4.0], [-2.4, 10.3], courbe=0.03, numero=1, posNumero=0.4, ecartFin=16),
            B([-2.6, 11.0], [-1.0, -9.5], courbe=-0.18, numero=2, posNumero=0.5)],
    etapes=['L’entraîneur attaque',
            'Le joueur renvoie la balle haut et derrière les carrés de service'],
    notes=['2 à 3 joueurs contre l’entraîneur'],
)

specs[(26, 'Engagement contrôle')] = dict(
    masques=carres_seulement(), tailleSymboles=0.9,
    zones=[{'de': [-3.6, -1.4], 'a': [-0.8, -4.6]}],
    joueurs=[J('A', 1.0, 5.0), J('B', -1.0, -5.0)],
    balles=[B([1.0, 5.0], [-2.2, -3.0], courbe=0.08, numero=1, posNumero=0.5, ecartFin=10),
            B([-2.2, -3.4], [1.0, 4.4], courbe=0.08, numero=2, posNumero=0.5, ecartDebut=14, ecartFin=18)],
    deplacements=[B([-1.0, -5.0], [-2.0, -3.9], courbe=0.3, ecartFin=10)],
    etapes=['A engage à la cuillère dans la zone',
            'B contrôle avec la raquette, puis renvoie'],
    notes=['Semaine 1 : B contrôle, puis c’est lui qui engage',
           'Semaine 2 : B contrôle, frappe et on joue l’échange',
           'Semaine 3 : échanges classiques'],
)

specs[(28, 'Engagement puis course')] = dict(
    masques=COULOIRS, tailleSymboles=0.85,
    joueurs=[J('A', -1.0, 11.2), J('B', -2.06, -11.2), J('C', 1.0, -11.2), J('D', 2.06, 11.2), E(6.0, 0.7)],
    balles=[B([6.0, 0.7], [-3.6, 7.2], courbe=0.08, numero=1, posNumero=0.3, ecartFin=10),
            B([6.0, 0.7], [3.6, -7.2], courbe=0.15, ecartFin=10),
            B([-3.3, 8.0], [-2.06, -10.6], courbe=0.04, numero=3, posNumero=0.5, ecartDebut=18)],
    deplacements=[B([-1.0, 11.2], [-3.2, 8.3], courbe=0.2, numero=2, posNumero=0.5, ecartFin=12)],
    etapes=['L’entraîneur engage loin du joueur',
            'Le joueur se déplace vite pour aller frapper',
            'Les deux joueurs jouent le point'],
    notes=['Même chose sur l’autre demi-terrain'],
)

specs[(4, 'Feu tricolore')] = dict(
    masques=carres_seulement(), tailleSymboles=0.85,
    joueurs=[J('A', 0, 5.0), J('B', 0, -5.0), J('C', 0, -8.6)],
    plots=[[-3.9, 3.2, 'bleu'], [3.9, 3.2, 'rouge'], [-0.9, -9.6, 'bleu'], [0.9, -9.6, 'rouge']],
    textes=[{'pos': [0, -11.1], 'texte': 'C lève un plot', 'taille': 18, 'espacement': 1, 'opacite': 0.9}],
    balles=[B([0, -5.0], [0.3, 4.3], courbe=0.05, numero=1, posNumero=0.6, ecartFin=16)],
    etapes=['B envoie la balle à A',
            'C, derrière B, lève un plot : bleu → A fait un revers, rouge → A fait un coup droit'],
    notes=['Plus facile : un contrôle avant la frappe',
           'Plus difficile : viser une zone précise'],
)

specs[(7, 'Frappe devant soi')] = dict(
    masques=COULOIRS, tailleSymboles=0.9,
    languettes=[[[-SX, 7.9], [SX, 7.9]]],
    joueurs=[J('A', 0.8, 8.8), J('B', 2.4, 5.6)],
    textes=[{'pos': [-2.0, 9.2], 'texte': 'Raquette devant à l’impact', 'taille': 15, 'espacement': 1, 'opacite': 0.85}],
    balles=[B([2.4, 5.6], [1.2, 7.7], courbe=0.2, numero=1, posNumero=0.5, ecartFin=10),
            B([1.0, 7.6], [-1.0, -8.0], courbe=0.03, numero=2, posNumero=0.4, ecartDebut=12)],
    etapes=['B lance la balle à la main',
            'A, derrière les languettes, frappe avec la raquette loin devant (devant les languettes)'],
    notes=['Languettes 2 pas avant la ligne des carrés de service'],
)

specs[(1, 'Gamme')] = dict(
    masques=COULOIRS, tailleSymboles=0.85,
    joueurs=[J('A', 2.4, 11.0), J('B', -2.4, -11.0), J('C', -2.4, 11.0), J('D', 2.4, -11.0),
             F('A', 1.1, 10.2), F('C', -1.1, 10.2)],
    textes=[{'pos': [-2.6, -2.4], 'texte': 'DIAG. CD', 'taille': 17, 'espacement': 1, 'opacite': 0.8},
            {'pos': [2.6, -2.4], 'texte': 'DIAG. R', 'taille': 17, 'espacement': 1, 'opacite': 0.8}],
    balles=[B([2.4, 11.0], [-2.4, -10.4], courbe=0.03, numero=1, posNumero=0.25),
            B([-2.4, 11.0], [2.4, -10.4], courbe=-0.03, numero=2, posNumero=0.25)],
    etapes=['Diagonale coup droit : A et B',
            'Diagonale revers : C et D'],
    notes=['Être replacé et prêt quand l’adversaire frappe',
           'Replacement un peu à droite du centre en diagonale CD, un peu à gauche en diagonale R'],
)

specs[(2, 'Gamme')] = dict(
    masques=COULOIRS, tailleSymboles=0.85,
    languettes=[[[0, -BL], [0, -SL]], [[0, SL], [0, BL]]],
    textes=[{'pos': [-2.06, -9.4], 'texte': 'GAUCHE', 'taille': 20, 'espacement': 2, 'opacite': 0.7},
            {'pos': [2.06, -9.4], 'texte': 'DROITE', 'taille': 20, 'espacement': 2, 'opacite': 0.7}],
    joueurs=[J('A', 0, 11.3), J('B', 0, -11.3), F('A', 1.3, 10.2), F('A', -1.3, 10.2)],
    balles=[B([0, 11.3], [2.6, -7.6], courbe=-0.03, numero=1, posNumero=0.8, ecartFin=10),
            B([0, 11.3], [-2.6, -7.6], courbe=0.03, numero=2, posNumero=0.8, ecartFin=10)],
    deplacements=[B([0, 11.3], [1.3, 10.2], courbe=0.35, numero=1, posNumero=0.5, ecartDebut=22, ecartFin=22),
                  B([0, 11.3], [-1.3, 10.2], courbe=-0.35, numero=2, posNumero=0.5, ecartDebut=22, ecartFin=22)],
    etapes=['Balle dans la zone droite : replacement un peu plus à droite',
            'Balle dans la zone gauche : replacement un peu plus à gauche'],
    notes=['Actif entre les frappes', 'Même règle pour B'],
)

specs[(3, 'Jeu de jambes au sceau')] = dict(
    masques=COULOIRS, tailleSymboles=0.85,
    pastilles=[[0, 8.6]],
    joueurs=[E(0, -2.0), J('A', 0, 8.6), J('B', -1.2, 12.6), J('C', 1.2, 12.6), J('R', -3.0, -9.5),
             F('A', 2.0, 8.0), F('A', -2.0, 8.0)],
    balles=[B([0, -2.0], [2.0, 7.4], courbe=0.04, numero=1, posNumero=0.5, ecartFin=12),
            B([0, -2.0], [-2.0, 7.4], courbe=-0.04, numero=2, posNumero=0.5, ecartFin=12)],
    deplacements=[B([0, 8.6], [2.0, 8.0], courbe=-0.3, ecartDebut=24, ecartFin=24),
                  B([0, 8.6], [-2.0, 8.0], courbe=0.3, ecartDebut=24, ecartFin=24)],
    etapes=['L’entraîneur lance à la main côté coup droit',
            'Puis côté revers (il alterne)'],
    notes=['Replacement sur la pastille et jeu de jambes entre chaque frappe',
           '5 frappes par joueur, puis on tourne (B, C attendent)',
           'R ramasse les balles'],
)

specs[(12, 'Lancer de balle service')] = dict(
    masques=COULOIRS, tailleSymboles=0.9,
    pastilles=[[1.3, 11.3]], joueurs=[J('A', 0.9, 12.3)],
    textes=[{'pos': [2.2, 9.6], 'texte': 'La balle retombe ici', 'taille': 15, 'espacement': 1, 'opacite': 0.9}],
    balles=[B([0.9, 12.3], [-2.0, -4.0], courbe=0.03, numero=2, posNumero=0.4)],
    etapes=['Lancer de balle : +1 point si elle retombe sur la pastille',
            'Au bout de 10 points, le joueur peut servir'],
)

specs[(24, 'Placement/Replacement')] = dict(
    masques=carres_seulement(), tailleSymboles=0.9,
    pastilles=[[0, 4.8]], joueurs=[J('A', 0, 4.8), E(0, -2.2)],
    balles=[B([0, -2.2], [2.1, 3.6], courbe=0.05, numero=1, posNumero=0.5, ecartFin=12)],
    deplacements=[B([0, 4.8], [1.9, 4.0], courbe=-0.45, numero=2, posNumero=0.5),
                  B([1.9, 4.0], [0, 4.8], courbe=-0.45, numero=3, posNumero=0.5, ecartDebut=18, ecartFin=34)],
    etapes=['L’adulte lance la balle à la main',
            'Le joueur se déplace et frappe',
            'Il revient sur la pastille'],
    notes=['Semaine 1 : frappe à l’arrêt', 'Semaine 2 : replacement après la frappe',
           'Semaine 3 : jeu de jambes + saut d’allégement entre les frappes'],
)

couleurs = ['rouge', 'bleu', 'jaune', 'vert', 'bleu', 'vert', 'rouge', 'jaune', 'jaune', 'rouge', 'vert', 'bleu']
plots39, posees39 = [], []
for i, (x, y) in enumerate([(x, y) for y in (-1.8, -3.7, -5.6) for x in (-3.3, -1.2, 1.2, 3.3)]):
    plots39.append([x, y, couleurs[i]])
    if i in (0, 2, 5, 7, 8, 11):
        posees39.append([x, y])
specs[(39, 'Plots couleurs')] = dict(
    tailleSymboles=0.85,
    masques=[[[-EX, 0], [EX, EY]], [[-EX, -EY], [-SX, 0]], [[SX, -EY], [EX, 0]]],
    plots=plots39, ballesPosees=posees39,
    joueurs=[J('A', -2.0, -8.6), J('B', 0, -8.6), J('C', 2.0, -8.6), E(-5.6, -4.0)],
    deplacements=[B([-2.0, -8.6], [-3.3, -1.9], courbe=0.15, numero=1, posNumero=0.5, ecartFin=18),
                  B([-3.3, -1.9], [-1.2, -3.5], courbe=0.3, numero=2, posNumero=0.5, ecartDebut=18, ecartFin=18)],
    etapes=['Courir sur un plot de la 1ʳᵉ couleur annoncée qui a une balle',
            'Puis sur un plot de la 2ᵉ couleur qui n’a pas de balle'],
    notes=['L’adulte annonce 2 couleurs (ex. « rouge, bleu »)',
           '3 plots de chaque couleur dans les carrés de service'],
)

def lignes_plots(balles):
    plots, posees, joueurs = [], [], []
    for x, nom in ((-2.8, 'A'), (0, 'B'), (2.8, 'C')):
        for y in (11.3, 9.8, 7.3, 3.3):
            plots.append([x, y])
            if balles and y != 11.3:
                posees.append([x, y])
        joueurs.append(J(nom, x, 12.7))
    return plots, posees, joueurs

p11, b11, j11 = lignes_plots(True)
specs[(11, 'Relais par équipe')] = dict(
    tailleSymboles=0.85, plots=p11, ballesPosees=b11, joueurs=j11,
    textes=[{'pos': [-1.4, 10.55], 'texte': 'court', 'taille': 13, 'espacement': 1, 'opacite': 0.8},
            {'pos': [-1.4, 8.55], 'texte': 'moyen', 'taille': 13, 'espacement': 1, 'opacite': 0.8},
            {'pos': [-1.4, 5.3], 'texte': 'long', 'taille': 13, 'espacement': 1, 'opacite': 0.8}],
    deplacements=[B([-2.8, 12.7], [-2.8, 3.8], courbe=-0.08, numero=1, posNumero=0.6, ecartFin=18),
                  B([-2.8, 3.8], [-2.8, 11.7], courbe=-0.08, numero=2, posNumero=0.4, ecartDebut=18, ecartFin=18)],
    etapes=['Aller chercher une balle sur un plot',
            'La ramener au départ, puis la suivante'],
    notes=['Une fois fini, taper dans la main de l’équipier : il replace les balles une par une',
           'Une ligne de 4 plots par équipe'],
)

p13, _, j13 = lignes_plots(False)
specs[(13, 'Renfo physique')] = dict(
    tailleSymboles=0.85, plots=p13, joueurs=j13,
    deplacements=[B([-2.8, 12.7], [-2.8, 7.8], courbe=-0.12, numero=1, posNumero=0.5, ecartFin=18),
                  B([-2.8, 7.8], [-2.8, 12.2], courbe=-0.25, numero=2, posNumero=0.5, ecartDebut=18, ecartFin=18)],
    etapes=['Sprint jusqu’au plot, le contourner',
            'Revenir au départ en marche arrière'],
    notes=['Un plot plus loin à chaque passage',
           'Une fois fini, taper dans la main de l’équipier, qui part'],
)

specs[(27, 'Reprise')] = dict(
    masques=COULOIRS, tailleSymboles=0.85,
    lignes=[{'de': [-SX, 0.3], 'a': [SX, 0.3], 'couleur': '#E53935', 'legende': 'Fil à 1 m'}],
    joueurs=[J('A', 2.4, 11.0), J('B', -2.4, -11.0)],
    balles=[B([2.4, 11.0], [-2.4, -10.4], courbe=0.06, numero=1, posNumero=0.75)],
    etapes=['Échanges en diagonale au-dessus du fil (1 m au-dessus du filet)',
            'Après 5 à 8 échanges selon le niveau, on joue le point'],
    notes=['Changer de diagonale au bout de 10 min'],
)

specs[(29, 'Reprise')] = dict(
    masques=COULOIRS, tailleSymboles=0.85,
    joueurs=[E(0, -2.0), J('A', 0, 9.0), F('A', 2.1, 8.4), F('A', -2.1, 8.4)],
    balles=[B([0, -2.0], [2.2, 7.5], courbe=0.04, numero=1, posNumero=0.5, ecartFin=14),
            B([0, -2.0], [-2.2, 7.5], courbe=-0.04, numero=2, posNumero=0.5, ecartFin=14)],
    deplacements=[B([0, 9.0], [2.1, 8.4], courbe=-0.3, ecartDebut=22, ecartFin=22),
                  B([2.1, 8.4], [-2.1, 8.4], courbe=-0.25, ecartDebut=22, ecartFin=22)],
    etapes=['L’entraîneur lance côté coup droit',
            'Tout de suite après, côté revers'],
    notes=['Se déplacer vite et faire un saut d’allégement en arrivant'],
)

specs[(43, 'Retour de service')] = dict(
    masques=COULOIRS, tailleSymboles=0.85,
    zones=[{'de': [-1.4, -8.8], 'a': [1.4, -11.8], 'texte': '1ʳᵉ'},
           {'de': [-SX, -4.5], 'a': [-2.9, -9.5], 'texte': '2ᵉ'},
           {'de': [2.9, -4.5], 'a': [SX, -9.5], 'texte': '2ᵉ'}],
    joueurs=[J('B', -0.6, -12.3), J('A', 3.2, 11.8)],
    balles=[B([-0.6, -12.3], [2.3, 4.8], courbe=0.02, ecartFin=10),
            B([3.2, 11.8], [0, -10.3], courbe=0.03, numero=1, posNumero=0.5),
            B([3.2, 11.8], [-3.5, -7.0], courbe=0.05, numero=2, posNumero=0.6, ecartFin=10)],
    etapes=['1ʳᵉ balle de service : retour profond au centre',
            '2ᵉ balle : le retourneur attaque vers une zone extérieure'],
    notes=['B sert, A retourne'],
)

specs[(44, 'Revers - main gauche')] = dict(
    masques=COULOIRS, tailleSymboles=0.8,
    portes=[[2.0, -11.6, 0], [3.9, -9.1, 90], [3.9, -3.2, 90]],
    textes=[{'pos': [2.0, -10.6], 'texte': '1', 'taille': 22, 'opacite': 0.95},
            {'pos': [3.0, -9.1], 'texte': '2', 'taille': 22, 'opacite': 0.95},
            {'pos': [3.0, -3.2], 'texte': '3', 'taille': 22, 'opacite': 0.95}],
    joueurs=[E(-1.5, -9.5), J('A', -2.2, 10.8), F('A', -2.4, 8.3), F('A', -2.6, 4.6)],
    balles=[B([-1.5, -9.5], [-2.1, 10.0], courbe=-0.02, epaisseur=3, ecartFin=18),
            B([-1.5, -9.5], [-2.3, 7.6], courbe=-0.04, epaisseur=3, ecartFin=18),
            B([-1.5, -9.5], [-2.5, 3.9], courbe=-0.06, epaisseur=3, ecartFin=18),
            B([-2.2, 10.8], [1.9, -11.0], courbe=0.03, numero=1, posNumero=0.55, ecartFin=16),
            B([-2.4, 8.3], [3.7, -9.1], courbe=0.03, numero=2, posNumero=0.45, ecartFin=16),
            B([-2.6, 4.6], [3.7, -3.6], courbe=0.04, numero=3, posNumero=0.4, ecartFin=16)],
    etapes=['Balle en fond de court : viser la porte 1 (ligne de fond)',
            'Balle au milieu du terrain : viser la porte 2 (couloir, fond)',
            'Balle dans les carrés de service : viser la porte 3 (couloir, carré)'],
    notes=['Plus le joueur avance dans le terrain, plus la main gauche est importante'],
)

specs[(38, 'Réaction')] = dict(
    masques=carres_seulement(), tailleSymboles=0.9,
    joueurs=[J('A', 0, 3.8), E(0, 5.8)],
    balles=[B([0, 5.8], [-1.5, 3.0], courbe=0.15, numero=1, posNumero=0.5, ecartFin=10),
            B([0, 5.8], [1.5, 3.0], courbe=-0.15, ecartFin=10),
            B([-1.4, 2.8], [-0.5, -4.5], courbe=0.04, numero=2, posNumero=0.5, ecartDebut=14)],
    etapes=['Derrière le joueur, l’adulte envoie la balle au sol à gauche ou à droite',
            'Le joueur arrête la balle au plus vite et l’envoie de l’autre côté'],
    notes=['Joueur en position d’attention, face au terrain',
           'Trop facile : l’adulte envoie avec rebond'],
)

specs[(41, 'Sceau + jeu volée')] = dict(
    masques=COULOIRS, tailleSymboles=0.8,
    zones=[{'de': [0.2, -1.0], 'a': [1.6, -5.4]}, {'de': [2.6, -1.0], 'a': [4.0, -5.4]}],
    textes=[{'pos': [-2.06, -9.5], 'texte': 'VOLÉE', 'taille': 18, 'espacement': 2, 'opacite': 0.7},
            {'pos': [2.06, -9.5], 'texte': 'JEU', 'taille': 18, 'espacement': 2, 'opacite': 0.7}],
    joueurs=[E(-2.06, -6.8), J('A', -2.06, 2.2), J('B', 2.06, 11.0), J('C', 2.06, -11.0)],
    balles=[B([-2.06, -6.8], [-2.06, 1.6], courbe=0.03, ecartFin=16),
            B([2.06, -11.0], [2.4, 4.2], courbe=0.02, numero=1, posNumero=0.6, ecartFin=10),
            B([2.4, 3.0], [3.3, -3.4], courbe=0.1, numero=3, posNumero=0.5, ecartDebut=18, ecartFin=10)],
    deplacements=[B([2.06, 11.0], [2.4, 3.4], courbe=0.1, numero=2, posNumero=0.5, ecartFin=18)],
    etapes=['C joue court : la balle tombe dans le carré de service',
            'B monte à la volée',
            'B vise une zone à gauche ou à droite dans le carré'],
    notes=['Demi-terrain gauche : l’entraîneur envoie à la raquette à A et corrige sa volée',
           'Volée : bas du corps en mouvement, haut du corps gainé, pas de préparation'],
)

specs[(30, 'Sceau - prise phase montante')] = dict(
    masques=COULOIRS, tailleSymboles=0.85, legendeZone='Zone sortante',
    zones=[{'de': [-SX, -1.2], 'a': [-2.8, -5.6]}, {'de': [2.8, -1.2], 'a': [SX, -5.6]}],
    joueurs=[E(0.5, -2.2), J('A', 0.6, 9.0)],
    balles=[B([0.5, -2.2], [1.0, 7.0], courbe=0.04, numero=1, posNumero=0.5, ecartFin=10),
            B([1.0, 7.4], [-3.4, -3.6], courbe=0.04, numero=3, posNumero=0.4, ecartDebut=18, ecartFin=10)],
    deplacements=[B([0.6, 9.0], [1.0, 7.9], courbe=0.4, numero=2, posNumero=0.5, ecartFin=16)],
    etapes=['L’entraîneur lance la balle à la main',
            'Le joueur avance et prend la balle en phase montante',
            'Il vise une zone sortante'],
)

ring = []
for k in range(10):
    a = 2 * math.pi * k / 10 - math.pi / 2
    ring.append([round(2.4 * math.cos(a), 2), round(3.6 + 2.4 * math.sin(a), 2)])
specs[(35, 'Tour du monde')] = dict(
    masques=carres_seulement(), tailleSymboles=0.75,
    pastilles=ring, joueurs=[J('A', 0, 3.6), J('B', ring[3][0], ring[3][1])],
    balles=[B([0, 3.6], [ring[3][0], ring[3][1]], courbe=0.15, numero=1, posNumero=0.5, ecartFin=20)],
    deplacements=[B([ring[3][0], ring[3][1]], [ring[4][0], ring[4][1]], courbe=-0.3, numero=2, posNumero=0.5, ecartDebut=20, ecartFin=24)],
    etapes=['A, au centre, renvoie le ballon violet à la raquette',
            'B se déplace d’une seule pastille, à gauche ou à droite'],
    notes=['8 à 10 pastilles en rond autour de A'],
)

specs[(15, 'Volée')] = dict(
    masques=COULOIRS, legendeZone='Zone « filet »', tailleSymboles=0.9,
    zones=[{'de': [-SX, -0.15], 'a': [SX, -3.2]}, {'de': [-SX, 0.15], 'a': [SX, 3.2]}],
    joueurs=[J('A', 0.8, 11.0), J('B', -0.8, -11.0)],
    balles=[B([-0.8, -11.0], [1.6, 2.0], courbe=0.03, numero=1, posNumero=0.35, ecartFin=10),
            B([1.4, 2.6], [-2.5, -8.0], courbe=-0.05, numero=3, posNumero=0.5, ecartDebut=22)],
    deplacements=[B([0.8, 11.0], [1.4, 3.2], courbe=0.1, numero=2, posNumero=0.55)],
    etapes=['La balle tombe entre le filet et le milieu des carrés de service',
            'Le joueur de ce côté doit monter à la volée',
            'Il joue la volée'],
)

specs[(25, 'Volée écureuil')] = dict(
    masques=carres_seulement(), tailleSymboles=0.9,
    joueurs=[J('A', 0, 1.8), J('B', 0, -1.8)],
    balles=[B([0, 1.8], [0, -1.8], courbe=0.6, numero=1, posNumero=0.5, ecartDebut=22, ecartFin=22),
            B([0, -1.8], [0, 1.8], courbe=0.6, ecartDebut=22, ecartFin=22)],
    etapes=['Échanges face à face près du filet, sans faire tomber la balle'],
    notes=['Semaine 1 : lancer à la main, l’autre rattrape dans un plot',
           'Semaine 2 : échanges au ballon violet',
           'Semaine 3 : échanges en balle rouge'],
)

os.makedirs(OUT, exist_ok=True)
for (id_, nom), spec in specs.items():
    data = {'exercice': {'id': id_, 'nom': nom}, **spec}
    path = os.path.join(OUT, f'{id_:02d}-{slug(nom)}.json')
    with open(path, 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
print(len(specs), 'fichiers')
