import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../widgets/overlays/app_modal_sheet.dart';
import '../../../widgets/overlays/app_notifications.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Operational & Alert Preferences
  bool _queueNotifications = true;
  bool _shiftReportEmail = true;
  bool _urgentSmsAlerts = true;
  bool _promoAlerts = false;
  bool _twoFactorEnabled = false;

  void _showPasswordChangeModal() {
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();

    AppModalSheet.showCustomBottomSheet(
      context: context,
      title: "Modifier le mot de passe",
      titleIcon: Icons.lock_reset_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: oldPasswordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Ancien mot de passe",
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: newPasswordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Nouveau mot de passe",
              prefixIcon: const Icon(Icons.key_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmPasswordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Confirmer le nouveau mot de passe",
              prefixIcon: const Icon(Icons.check_circle_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.primaryEmerald,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (newPasswordCtrl.text.isEmpty || confirmPasswordCtrl.text.isEmpty) {
                AppNotifications.showError(context, "Veuillez remplir tous les champs.");
                return;
              }
              if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
                AppNotifications.showError(context, "Les nouveaux mots de passe ne correspondent pas.");
                return;
              }
              Navigator.pop(context);
              AppNotifications.showSuccess(context, "Mot de passe mis à jour avec succès !");
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text("Mettre à jour le mot de passe", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showThemeSelector(ThemeProvider themeProvider) {
    final current = themeProvider.selectedThemeLabel;

    AppModalSheet.showCustomBottomSheet(
      context: context,
      title: "Apparence & Thème",
      titleIcon: Icons.palette_outlined,
      child: Column(
        children: [
          _buildSelectionTile(
            title: "Automatique (Système)",
            subtitle: "S'adapte aux préférences du téléphone",
            isSelected: current == "Systeme",
            onTap: () {
              themeProvider.setTheme("Systeme");
              Navigator.pop(context);
              AppNotifications.showSuccess(context, "Thème Système activé !");
            },
          ),
          _buildSelectionTile(
            title: "Thème Clair",
            subtitle: "Interface lumineuse standard",
            isSelected: current == "Clair",
            onTap: () {
              themeProvider.setTheme("Clair");
              Navigator.pop(context);
              AppNotifications.showSuccess(context, "Thème Clair activé !");
            },
          ),
          _buildSelectionTile(
            title: "Thème Sombre",
            subtitle: "Économe en énergie et reposant",
            isSelected: current == "Sombre",
            onTap: () {
              themeProvider.setTheme("Sombre");
              Navigator.pop(context);
              AppNotifications.showSuccess(context, "Thème Sombre activé !");
            },
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector(ThemeProvider themeProvider) {
    final current = themeProvider.selectedLanguage;

    AppModalSheet.showCustomBottomSheet(
      context: context,
      title: "Langue de l'application",
      titleIcon: Icons.language_outlined,
      child: Column(
        children: [
          _buildSelectionTile(
            title: "Français",
            subtitle: "Français (Haïti / France)",
            isSelected: current == "Français",
            onTap: () {
              themeProvider.setLanguage("Français");
              Navigator.pop(context);
              AppNotifications.showSuccess(context, "Langue activée : Français");
            },
          ),
          _buildSelectionTile(
            title: "Kreyòl Ayisyen",
            subtitle: "Langue créole haïtienne",
            isSelected: current == "Kreyòl",
            onTap: () {
              themeProvider.setLanguage("Kreyòl");
              Navigator.pop(context);
              AppNotifications.showSuccess(context, "Lang chwazi: Kreyòl Ayisyen");
            },
          ),
          _buildSelectionTile(
            title: "English",
            subtitle: "English (US)",
            isSelected: current == "English",
            onTap: () {
              themeProvider.setLanguage("English");
              Navigator.pop(context);
              AppNotifications.showSuccess(context, "Language set to English");
            },
          ),
          _buildSelectionTile(
            title: "Español",
            subtitle: "Español (República Dominicana / España)",
            isSelected: current == "Español",
            onTap: () {
              themeProvider.setLanguage("Español");
              Navigator.pop(context);
              AppNotifications.showSuccess(context, "Idioma seleccionado: Español");
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accentMint.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? AppTheme.accentMint : Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.accentMint) : null,
        onTap: onTap,
      ),
    );
  }

  void _showInternalSupportModal() {
    AppModalSheet.showCustomBottomSheet(
      context: context,
      title: "Assistance Interne & Supervision",
      titleIcon: Icons.headset_mic_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primaryEmerald.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.phone_in_talk_outlined, color: AppTheme.primaryEmerald),
            ),
            title: const Text("Ligne Directe Superviseur Station", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("+509 3700-0001 (Poste interne 104)"),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primaryEmerald.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.support_agent_outlined, color: AppTheme.primaryEmerald),
            ),
            title: const Text("Support Technique Antigravity / IT", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("it-support@jlgpowerservicessupplies.com"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppTheme.primaryEmerald,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.currentUser;
    final bool isInternal = user?.isInternal ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Paramètres"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // USER PROFILE HERO CARD
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: isInternal
                      ? [AppTheme.primaryEmerald, AppTheme.primaryDark]
                      : [const Color(0xFF0284C7), const Color(0xFF0369A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Icon(
                          isInternal ? Icons.badge_outlined : Icons.person_outline,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.nom ?? (isInternal ? "Agent Station" : "Client Aquafresh"),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? "station@aquafresh.com",
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isInternal ? AppTheme.accentMint : Colors.orangeAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isInternal ? "PERSONNEL INTERNE — ${user?.role ?? 'AGENT_STATION'}" : "COMPTE CLIENT PUBLIC",
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // INTERNAL DEDICATED SECTION
          if (isInternal) ...[
            _buildSectionHeader("INFORMATIONS DE RACCORDEMENT STATION"),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: const [
                  ListTile(
                    leading: Icon(Icons.store_outlined, color: AppTheme.primaryEmerald),
                    title: Text("Station de Remplissage"),
                    subtitle: Text("Station Aquafresh #01 — Port-au-Prince"),
                    trailing: Icon(Icons.verified, color: AppTheme.accentMint, size: 20),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.point_of_sale_outlined, color: AppTheme.primaryEmerald),
                    title: Text("Identifiant Terminal Mobile"),
                    subtitle: Text("TERM-STATION-APK-2026-V1"),
                    trailing: Text("ACTIF", style: TextStyle(color: AppTheme.accentMint, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // SECTION 1: SÉCURITÉ & COMPTE
          _buildSectionHeader("SÉCURITÉ & COMPTE"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: AppTheme.primaryEmerald),
                  title: const Text("Modifier le mot de passe"),
                  subtitle: Text(isInternal ? "Sécurité du compte opérateur station" : "Sécurité de votre compte client"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showPasswordChangeModal,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.shield_outlined, color: AppTheme.primaryEmerald),
                  title: const Text("Authentification 2FA"),
                  subtitle: const Text("Validation obligatoire par code OTP"),
                  value: _twoFactorEnabled,
                  onChanged: (val) => setState(() => _twoFactorEnabled = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECTION 2: PRÉFÉRENCES ÉCRANS & ALERTES
          _buildSectionHeader(isInternal ? "PRÉFÉRENCES DE POSTE & ALERTES" : "PRÉFÉRENCES & NOTIFICATIONS"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryEmerald),
                  title: Text(isInternal ? "Alertes File d'Attente Camions" : "Notifications de Commandes"),
                  subtitle: Text(isInternal ? "Notification lors de l'arrivée d'un nouveau camion" : "Suivi en temps réel de vos livraisons"),
                  value: _queueNotifications,
                  onChanged: (val) => setState(() => _queueNotifications = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.email_outlined, color: AppTheme.primaryEmerald),
                  title: Text(isInternal ? "Rapport de Fin de Poste par E-mail" : "Factures & Reçus par E-mail"),
                  subtitle: Text(isInternal ? "Envoi du récapitulatif quotidien des tickets émis" : "Envoi des reçus de paiement"),
                  value: _shiftReportEmail,
                  onChanged: (val) => setState(() => _shiftReportEmail = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.sms_outlined, color: AppTheme.primaryEmerald),
                  title: const Text("Alertes SMS"),
                  subtitle: Text(isInternal ? "Alertes système urgentes et incidents" : "Notifications SMS de confirmation"),
                  value: _urgentSmsAlerts,
                  onChanged: (val) => setState(() => _urgentSmsAlerts = val),
                ),
                if (!isInternal) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.campaign_outlined, color: AppTheme.primaryEmerald),
                    title: const Text("Offres & Promotions"),
                    subtitle: const Text("Nouveautés et offres spéciales"),
                    value: _promoAlerts,
                    onChanged: (val) => setState(() => _promoAlerts = val),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECTION 3: APPARENCE ET LANGUE (LIVE SWITCHING WITH ESPAÑOL ADDED)
          _buildSectionHeader("APPARENCE & LANGUE"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined, color: AppTheme.primaryEmerald),
                  title: const Text("Apparence & Thème"),
                  subtitle: Text(themeProvider.selectedThemeLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeSelector(themeProvider),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined, color: AppTheme.primaryEmerald),
                  title: const Text("Langue de l'application"),
                  subtitle: Text(themeProvider.selectedLanguage),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLanguageSelector(themeProvider),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECTION 4: SUPPORT ET ASSISTANCE
          _buildSectionHeader(isInternal ? "ASSISTANCE INTERNE & GUIDES" : "INFORMATIONS LÉGALES & SUPPORT"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.headset_mic_outlined, color: AppTheme.primaryEmerald),
                  title: Text(isInternal ? "Support Technique & Supervision" : "Aide & Support Client"),
                  subtitle: Text(isInternal ? "Assistance IT et ligne directe d'urgence" : "FAQ & Coordonnées d'assistance"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showInternalSupportModal,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined, color: AppTheme.primaryEmerald),
                  title: const Text("Conditions Générales (CGU)"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    AppModalSheet.showCustomBottomSheet(
                      context: context,
                      title: "Conditions Générales d'Utilisation",
                      titleIcon: Icons.gavel_outlined,
                      child: Text(
                        isInternal
                            ? "JL Green Power Services & Supplies — Règlement Interne Station v1.0.\n\n"
                              "L'utilisation de cette application mobile de station est strictly réservée au personnel "
                              "opérateur autorisé de JL Green Aquafresh. Toute saisie de camion ou validation de vanne est horodatée "
                              "et liée à votre identifiant d'agent."
                            : "JL Green Power Services & Supplies — CGU Client v1.0.\n\n"
                              "Conditions d'utilisation du service de vente et livraison d'eau JL Green Aquafresh.",
                        style: const TextStyle(height: 1.5),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppTheme.primaryEmerald),
                  title: const Text("À propos"),
                  subtitle: Text("${AppConfig.appName} — v${AppConfig.appVersion} (${isInternal ? 'Module Interne Station' : 'Module Public'})"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: AppConfig.appName,
                      applicationVersion: AppConfig.appVersion,
                      applicationIcon: const Icon(Icons.water_drop_rounded, size: 48, color: AppTheme.primaryEmerald),
                      children: const [
                        Text("Éditeur : JL Green Power Services & Supplies"),
                        Text("Portail Opérationnel Station de Remplissage"),
                        Text("Site Web : https://jlgpowerservicessupplies.com"),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // LOGOUT CARD BUTTON
          Card(
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.red.shade200),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "Se Déconnecter",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text("Fermer la session opérateur sur cet appareil", style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red, size: 16),
              onTap: () => authProvider.logout(context),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
