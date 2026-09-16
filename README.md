# 📱 JLG System — Application Mobile (`jlg_mobile`)

Ce sous-projet contient l'application mobile multiplateforme de **JLG System**, développée avec **Flutter** (Dart) pour les smartphones et tablettes **Android** et **iOS**.

---

## 🎯 Rôle de l'Application Mobile

L'application mobile est destinée aux équipes sur le terrain (opérateurs de station, chauffeurs et livreurs) pour permettre :
- L'authentification sécurisée avec gestion de session persistante.
- La consultation en direct des courses et tournées assignées.
- La validation des livraisons et des bons de livraison sur le terrain.
- La gestion rapide des opérations de station et des paramètres de connexion.

---

## 📂 Organisation du Code (`lib/`)

```text
jlg_mobile/
├── android/                 # Configuration et manifestes natifs Android
├── ios/                     # Configuration et runner natif iOS
├── lib/
│   ├── core/                # Thème visuel, configuration réseau, constantes d'API
│   │   ├── constants/       # Couleurs, styles, endpoints API
│   │   ├── network/         # Client HTTP (Dio / Http) avec gestion des tokens JWT
│   │   └── theme/           # Charte graphique (Palette JLG System)
│   ├── modules/             # Écrans et flux fonctionnels
│   │   ├── auth/            # Écran de connexion (Login) et récupération
│   │   ├── splash/          # Écran de démarrage & vérification de session
│   │   ├── station/         # Opérations de station et suivi des opérations
│   │   └── settings/        # Paramètres utilisateur et déconnexion
│   ├── widgets/             # Composants d'interface réutilisables (Boutons, Cartes, Inputs)
│   └── main.dart            # Point d'entrée de l'application Flutter
├── pubspec.yaml             # Dépendances Flutter et assets
└── analysis_options.yaml    # Règles de linter Dart
```

---

## ⚙️ Prérequis & Installation

### 1. Prérequis
- **Flutter SDK** (version 3.19+ ou supérieure)
- **Dart SDK** (inclus avec Flutter)
- **Android Studio** / **Xcode** pour les émulateurs et builds natifs

### 2. Récupération des Dépendances
```bash
cd jlg_mobile
flutter pub get
```

### 3. Lancement en Mode Développement
```bash
# Vérifier les appareils / émulateurs connectés
flutter devices

# Lancer sur l'appareil connecté
flutter run
```

---

## 📦 Génération des Builds de Production

### Android (APK & App Bundle)
```bash
# Générer l'APK de production
flutter build apk --release

# Générer l'App Bundle (.aab) pour Google Play Store
flutter build appbundle --release
```
Le fichier généré se trouvera dans : `build/app/outputs/flutter-apk/app-release.apk`

### iOS (IPA)
```bash
flutter build ipa --release
```
*(Nécessite un environnement macOS avec Xcode configuré avec un profil de provisionnement Apple Developer).*
