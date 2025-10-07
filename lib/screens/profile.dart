import 'package:flutter/material.dart';
import '../main.dart'; // Importamos para usar los colores globales

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Estado para el switch de notificaciones
  bool _notificationsEnabled = true;
  void showSosConfirmationDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            '¿Eliminar cuenta?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Esta acción es permanente y no se puede deshacer. Perderás todos tus datos, contactos y configuración.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Eliminar Cuenta'),
                  onPressed: () {
                    // Aquí iría la lógica para eliminar la cuenta
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          children: [
            // --- SECCIÓN SUPERIOR: AVATAR Y EMAIL ---
            const Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: cardColor,
                  child: Icon(Icons.person, size: 40, color: Colors.white70),
                ),
                SizedBox(height: 12),
                Text(
                  'usuario@chita.app',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // --- SECCIÓN: INFORMACIÓN PERSONAL ---
            const _SectionTitle(title: 'Información Personal'),
            const SizedBox(height: 16),
            const _InfoTile(
              label: 'Nombre Completo',
              value: 'Juan Pérez',
            ),
            const SizedBox(height: 16),
            const _InfoTile(
              label: 'Email',
              value: 'usuario@chita.app',
            ),
            const SizedBox(height: 16),
            const _InfoTile(
              label: 'Número de Teléfono',
              value: '+1 234 567 8900',
            ),
            const SizedBox(height: 30),

            // // --- SECCIÓN: CONFIGURACIÓN ---
            // const _SectionTitle(title: 'Configuración'),
            // const SizedBox(height: 8),
            // _SettingsTile(
            //   title: 'Notificaciones Push',
            //   subtitle: 'Recibir alertas y actualizaciones',
            //   trailing: Switch(
            //     value: _notificationsEnabled,
            //     onChanged: (value) {
            //       setState(() {
            //         _notificationsEnabled = value;
            //       });
            //     },
            //     activeColor: primaryColor,
            //     activeTrackColor: primaryColor.withOpacity(0.5),
            //   ),
            // ),
            // const _SettingsTile(
            //   title: 'Cambiar Contraseña',
            //   subtitle: 'Actualiza tu contraseña de seguridad',
            //   trailing: Icon(Icons.chevron_right, color: Colors.grey),
            // ),
            // const _SettingsTile(
            //   title: 'Acerca de',
            //   subtitle: 'Versión de la app e información',
            //   trailing: Icon(Icons.chevron_right, color: Colors.grey),
            // ),
            // const SizedBox(height: 30),

            // --- SECCIÓN: CUENTA ---
            const _SectionTitle(title: 'Cuenta'),
            const SizedBox(height: 16),
            _AccountActionButton(
              text: 'Cerrar Sesión',
              icon: Icons.logout,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _AccountActionButton(
              text: 'Eliminar Cuenta',
              icon: Icons.delete_outline,
              textColor: accentColor, // Color rojo para acción destructiva
              onTap: () => showSosConfirmationDeleteAccountDialog(context),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Widget reutilizable para los títulos de sección
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// Widget reutilizable para mostrar información estática
class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

// Widget reutilizable para las opciones de configuración
class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      trailing: trailing,
    );
  }
}

// Widget reutilizable para los botones de la sección "Cuenta"
class _AccountActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final Color textColor;

  const _AccountActionButton({
    required this.text,
    required this.icon,
    required this.onTap,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: textColor != Colors.white ? Border.all(color: cardColor) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}