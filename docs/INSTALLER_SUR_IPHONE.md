# Installer TennisTrack sur un iPhone gratuitement

Sans compte développeur Apple payant, et sans Mac.

- **GitHub** fabrique l'appli sur un Mac dans le cloud et produit un fichier
  `TennisTrack.ipa`.
- **Sideloadly**, sur ton PC, signe ce fichier avec ton identifiant Apple
  gratuit et l'installe sur l'iPhone.

## Une seule fois au départ

1. Sur le PC Windows, installe **iTunes** et **iCloud** depuis le site d'Apple
   (pas depuis le Microsoft Store) :
   - https://www.apple.com/fr/itunes/download/win64
   - https://support.apple.com/fr-fr/103232
2. Installe **Sideloadly** : https://sideloadly.io
3. Sur l'iPhone, active le **mode développeur** : Réglages → Confidentialité
   et sécurité → Mode développeur → activer. L'iPhone redémarre.

   L'option n'apparaît parfois qu'après une première tentative
   d'installation avec Sideloadly.

## Récupérer le fichier .ipa

1. Sur github.com, ouvre le projet **TennisTrack**, puis l'onglet **Actions**.
2. À gauche, clique sur **Construire l'appli iPhone**.
3. Clique sur **Run workflow**, puis à nouveau sur **Run workflow**.
   Ce bouton n'existe que lorsque le workflow est sur la branche `main`.
4. Attends environ 10 à 15 minutes, jusqu'à la coche verte ✅.
5. Clique sur l'exécution terminée. En bas, dans **Artifacts**, télécharge
   **TennisTrack-iPhone**.
6. Tu obtiens un `.zip` : **décompresse-le** pour récupérer
   `TennisTrack.ipa`.

L'appli est aussi reconstruite automatiquement à chaque modification du code
envoyée sur GitHub.

## Installer sur l'iPhone

1. Branche l'iPhone au PC avec un câble USB. Déverrouille-le et réponds
   **Se fier à cet ordinateur** s'il te le demande.
2. Ouvre **Sideloadly**.
3. Glisse `TennisTrack.ipa` dans la fenêtre.
4. Saisis ton **identifiant Apple** (adresse e-mail), puis clique sur
   **Start**. Sideloadly demande ensuite le mot de passe, et parfois un
   code de vérification reçu sur l'iPhone.
5. Sur l'iPhone, autorise l'appli : Réglages → Général → **VPN et gestion de
   l'appareil** → ton identifiant Apple → **Faire confiance**.
6. L'icône **Tennistrack** est sur l'écran d'accueil.

## Tous les 7 jours

Avec un identifiant Apple gratuit, la signature expire au bout de **7
jours** : l'appli ne s'ouvre plus. Pour la remettre en service, refais
simplement la partie « Installer sur l'iPhone » avec le même fichier `.ipa`.

**Les séances enregistrées ne sont pas perdues** tant que tu ne supprimes pas
l'appli de l'iPhone.

## Bon à savoir

- Un identifiant Apple gratuit permet d'avoir au maximum **3 applis**
  installées de cette façon en même temps.
- Sideloadly n'est pas un logiciel Apple. Par prudence, tu peux créer un
  **identifiant Apple secondaire** gratuit, réservé à cet usage.
- L'identifiant de l'appli est `com.ngendry601.tennistrack`. Apple refuse le
  préfixe `com.example` utilisé par défaut par Flutter.
