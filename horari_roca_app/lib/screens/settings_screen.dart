import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(darkModeProvider);
    final user = ref.watch(currentUserProvider);
    final roleAsync = ref.watch(userRoleProvider);

    final email = user?.email ?? '';
    final name = user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'] ?? email.split('@').first;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Perfil d'usuari
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(height: 4),
                        roleAsync.when(
                          loading: () => const SizedBox(height: 16, width: 80, child: LinearProgressIndicator()),
                          error: (_, __) => const Text('Rol desconegut', style: TextStyle(fontSize: 12)),
                          data: (role) => _RoleBadge(role: role?.role ?? 'desconegut'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Preferències
          _SectionHeader('Preferències'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Mode fosc'),
                  subtitle: const Text('Canviar aparença de l\'app'),
                  secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: AppTheme.primaryColor),
                  value: isDark,
                  onChanged: (_) => ref.read(darkModeProvider.notifier).toggle(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Informació
          _SectionHeader('Informació'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                  title: const Text('Versió'),
                  trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.business, color: AppTheme.primaryColor),
                  title: const Text('Empresa'),
                  trailing: const Text('Roca & Rambla', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tancar sessió
          _SectionHeader('Compte'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Tancar sessió', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
              onTap: () => _confirmSignOut(context, ref),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tancar sessió'),
        content: const Text('Estàs segur que vols sortir?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel·lar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(googleSignInProvider.notifier).signOut();
            },
            child: const Text('Sortir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 0.5)),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (role) {
      case 'admin':
        color = Colors.purple;
        label = 'Administrador';
        break;
      case 'encarregat':
        color = Colors.orange;
        label = 'Encarregat';
        break;
      default:
        color = Colors.green;
        label = 'Treballador';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
