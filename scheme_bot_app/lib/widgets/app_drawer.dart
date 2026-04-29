import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/vault_screen.dart';
import '../screens/profile_form_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to log out?', style: GoogleFonts.inter()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Yes, Log Out', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (context.mounted) Navigator.pop(context); // Close the drawer first
      await Supabase.instance.client.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String? ?? 'User Profile';
    final email = user?.email ?? 'Not logged in';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            accountName: Text(
              fullName,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            accountEmail: Text(
              email,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.indigo),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark, color: Colors.indigo),
            title: Text('Saved Schemes', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder, color: Colors.indigo),
            title: Text('Document Vault', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts, color: Colors.indigo),
            title: Text('Edit Details', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileFormScreen()));
            },
          ),
          const Divider(),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.redAccent)),
            onTap: () => _handleLogout(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
