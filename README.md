<p align="center"><img src="assets/logo_round.png" width="140" alt="Statuvault"></p>

<h1 align="center">Statuvault</h1>
<p align="center">Enregistre les statuts WhatsApp (photos et vidéos) en un geste — Android & iOS, Flutter.</p>

## Télécharger

Chaque push sur `main` compile automatiquement l'appli : va dans **Releases** et prends le dernier fichier.

| Plateforme | Fichier | Installation |
|---|---|---|
| Android 5 → 15 | `Statuvault.apk` | Ouvre le fichier sur le téléphone, autorise « sources inconnues ». |
| iPhone | `Statuvault-unsigned.ipa` | Avec [AltStore](https://altstore.io) ou [Sideloadly](https://sideloadly.io) (pas de signature Apple). |

## Fonctionnalités

**Android**
- Lit les statuts de **WhatsApp** et **WhatsApp Business** (onglets Photos / Vidéos).
- Accès par le Storage Access Framework : l'utilisateur autorise une seule fois le dossier `.Statuses`, sans la permission « Gérer tous les fichiers » (compatible Play Store).
- Bouton de téléchargement rapide sur chaque vignette, visionneuse plein écran (zoom, lecture vidéo, glisser entre statuts).
- Enregistrement dans la galerie, album **Statuvault**, + onglet « Enregistrés ».
- Partage vers n'importe quelle appli.
- Enregistrement automatique des nouveaux statuts (option).

**iOS**
- Apple n'autorise aucune appli à lire les fichiers de WhatsApp. Sur iPhone, Statuvault importe les statuts capturés (capture ou enregistrement d'écran) depuis Photos, puis les range, les partage et les enregistre dans l'album Statuvault.

## Comment ça marche

```
Android/media/com.whatsapp/WhatsApp/Media/.Statuses              ← WhatsApp
Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses ← WA Business
```
WhatsApp stocke les statuts vus dans ces dossiers cachés. Statuvault ouvre le sélecteur Android directement sur le bon dossier (`EXTRA_INITIAL_URI`), garde l'autorisation (`takePersistableUriPermission`), liste les fichiers et copie ceux que tu choisis.

## Structure

```
lib/
  main.dart                 point d'entrée
  theme.dart                couleurs du logo
  status_service.dart       accès aux statuts, galerie, import, réglages
  screens/home_screen.dart  accueil (onglets, accès, réglages)
  screens/viewer_screen.dart visionneuse
  widgets/media_grid.dart   grille de vignettes
native/android/MainActivity.kt  canal natif SAF (liste, copie, miniatures vidéo)
tool/patch_platforms.py     règle android/ et ios/ générés (nom, permissions, MainActivity)
.github/workflows/build.yml compile APK + IPA et publie la Release
```

Les dossiers `android/` et `ios/` sont générés à la compilation par `flutter create`, puis réglés par `tool/patch_platforms.py`.

## Compiler en local

```bash
flutter create --org com.statuvault --project-name statuvault --platforms=android,ios .
python3 tool/patch_platforms.py
flutter pub get
dart run flutter_launcher_icons
flutter run            # ou : flutter build apk --release
```

## Bon usage

Les statuts appartiennent à tes contacts : garde-les pour toi et demande leur accord avant de les republier. Statuvault n'est pas affilié à WhatsApp ni à Meta.
