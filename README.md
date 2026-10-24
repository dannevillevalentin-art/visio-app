# Visio

App iOS de magie : lance un faux appel vidéo (style WhatsApp, Instagram ou FaceTime)
à partir d'une vidéo préparée à l'avance, avec le vrai retour de la caméra frontale.

## Utilisation

**Galerie** – l'écran d'accueil ressemble à une grille de vidéos dans Photos.
Toucher une vidéo lance l'appel.

**« Sélectionner »** – passe en mode index :
- chaque case affiche son numéro (1 à 12) et une note privée (« Dame de cœur »…) ;
- toucher une case pour l'éditer : vidéo (importée de Photos ou filmée), miniature,
  position dans l'index, style d'appel, nom et photo du contact ;
- la roue dentée ouvre les réglages généraux.

**Pendant l'appel**
1. Sonnerie : la caméra frontale occupe l'écran, tonalité d'appel.
   Toucher l'écran fait décrocher tout de suite.
2. Connecté : la vidéo s'affiche, la caméra frontale passe dans un coin
   (déplaçable au doigt). Les icônes disparaissent après quelques secondes
   et réapparaissent au toucher.
3. Le bouton rouge raccroche → écran d'accueil (animation iOS normale),
   capture d'un faux écran d'accueil, ou retour à la galerie.

Les vidéos sont **copiées dans l'app** : elles restent disponibles même si on les
supprime de Photos, et sont incluses dans les sauvegardes iCloud de l'iPhone.

## Compilation

Aucun Mac nécessaire : tout passe par GitHub Actions (même principe que Sonore).

| Workflow | Rôle | Compte Apple requis |
|---|---|---|
| **Vérifier la compilation** | Compile sans signer, à chaque modification | Non |
| **Compiler et envoyer sur TestFlight** | Compile, signe, envoie sur TestFlight (lancement manuel) | Oui |

### Secrets à créer (Settings → Secrets and variables → Actions)

Les mêmes valeurs que pour Sonore :

| Secret | Valeur |
|---|---|
| `APPLE_TEAM_ID` | Team ID |
| `ASC_KEY_ID` | Key ID de la clé API App Store Connect |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8` | Contenu complet du fichier `.p8` |

Identifiant de l'app par défaut : `com.vdanneville.visio`
(variable `BUNDLE_ID` pour en changer). L'app doit exister dans App Store Connect
avec cet identifiant avant le premier envoi.

## Structure

- `Visio/Call/CallView.swift` – écran d'appel (sonnerie, connexion, retour caméra, fin)
- `Visio/Call/CallChrome.swift` – icônes et textes de chaque style
- `Visio/Call/CallEngine.swift` – lecture vidéo, caméra frontale, tonalité, retour à l'accueil
- `Visio/Views/` – galerie, édition d'un emplacement, réglages
- `Visio/Store/` – index (library.json) et fichiers (Application Support/Media)
- `project.yml` – description du projet (XcodeGen)

Usage privé uniquement : l'app reproduit des interfaces d'appel et utilise un
retour à l'accueil non autorisé sur l'App Store.
