# 📜 Journal des Modifications — Application Mobile (`/jlg_mobile`)

Toutes les modifications notables apportées à l'**Application Mobile JLG System** (Flutter 3.x / Dart - Android & iOS) sont documentées dans ce fichier.

---

## [2.1.0] - 2026-09-16

### 📱 Documentation & Mises à Jour Métier
- **Documentation Complète de l'App :** Remplacement du fichier `README.md` générique par la documentation officielle de l'application mobile de piste et distribution JL Green.
- **Sécurisation des Sessions & Changement de Mot de Passe :** Intégration de la propriété `doit_changer_mot_de_passe` et redirection automatique vers l'écran d'initialisation du mot de passe.
- **Domaine Email Officiel :** Harmonisation des identifiants par défaut sur le domaine `jlgpowerservicessupplies.com`.

---

## [2.0.0] - 2026-09-05

### 🚀 Application Piste & Distribution Terrain
- **Configuration Dynamique de Station :** Synchronisation automatique avec l'endpoint `/api/v1/station/company-config` pour récupérer les tarifs au forfait et les horaires de station.
- **Filtres d'Historique Responsives :** Adaptation ergonomique des filtres de transactions et du détail des remplissages de camions.
- **Internationalisation (i18n) & Thème Sombre :** Support multilingue et basculement automatique mode sombre / mode clair.
- **File d'Attente de Piste :** Gestion en temps réel de la file d'attente des camions au portique d'eau brute.

---

## [1.0.0] - 2026-08-10

### 🏗️ Socle Mobile Initial
- **Stack Technologique :** Flutter 3.x, Dart, Provider / State Management, Dio / HTTP.
- **Authentification Sécurisée :** Connexion JWT avec stockage local sécurisé des tokens (`FlutterSecureStorage`).
- **Interfaces Mobile-First :** Développé spécifiquement pour les terminaux mobiles et tablettes de piste des opérateurs et chauffeurs-livreurs.
