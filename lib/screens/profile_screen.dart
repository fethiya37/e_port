import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _showOld = false;
  bool _showNew = false;
  bool _loading = false;
  String? _error;

  // Rebuild UI whenever a field changes so the button can enable/disable.
  @override
  void initState() {
    super.initState();
    _oldCtrl.addListener(_rebuild);
    _newCtrl.addListener(_rebuild);
  }

  @override
  void dispose() {
    _oldCtrl.removeListener(_rebuild);
    _newCtrl.removeListener(_rebuild);
    _oldCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  bool get _canSubmit =>
      !_loading &&
      _oldCtrl.text.isNotEmpty &&
      _newCtrl.text.isNotEmpty &&
      _newCtrl.text.length >= 6;

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    if (!_canSubmit) return;

    if (_newCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() { _error = null; _loading = true; });
    try {
      final res = await changePassword(_oldCtrl.text, _newCtrl.text);
      if (res.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated')),
          );
        }
        _oldCtrl.clear();
        _newCtrl.clear();
        setState(() {
          _showOld = false;
          _showNew = false;
        });
      } else {
        setState(() => _error = res.error ?? 'Failed to change password');
      }
    } catch (_) {
      setState(() => _error = 'Network error. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _logout() async {
    await logout(); // clears token locally (and best-effort server revoke)
    widget.onLogout();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final headerTitleStyle =
        GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600);
    final titleStyle = GoogleFonts.poppins(
      fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A),
    );

    final assocLabel = user.associationId != null
        ? 'Association #${user.associationId}'
        : 'Association N/A';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('Profile', style: headerTitleStyle),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _BlueTopCardCompact(
                    name: (user.name == null || user.name!.trim().isEmpty)
                        ? user.phoneNumber
                        : user.name!,
                    phone: user.phoneNumber,
                    role: user.userType,
                  ),
                  const SizedBox(height: 12),

                  _WhiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Account', style: titleStyle),
                        const SizedBox(height: 12),
                        _infoTile(Icons.phone, 'Phone', user.phoneNumber),
                        const SizedBox(height: 8),
                        _infoTile(Icons.shield_outlined, 'Role', user.userType),
                        const SizedBox(height: 8),
                        _infoTile(Icons.apartment_outlined, 'Association', assocLabel),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Change Password
                  _WhiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Change password', style: titleStyle),
                        const SizedBox(height: 12),

                        if (_error != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                          ),

                        _LabeledObscuredInput(
                          label: 'Current password',
                          hint: 'Enter current password',
                          controller: _oldCtrl,
                          showing: _showOld,
                          onToggle: () => setState(() => _showOld = !_showOld),
                          enabled: !_loading,
                        ),
                        const SizedBox(height: 12),
                        _LabeledObscuredInput(
                          label: 'New password',
                          hint: 'Minimum 6 characters',
                          controller: _newCtrl,
                          showing: _showNew,
                          onToggle: () => setState(() => _showNew = !_showNew),
                          enabled: !_loading,
                        ),
                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                            ),
                            onPressed: _canSubmit ? _changePassword : null,
                            child: _loading
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Update'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Logout
                  _WhiteCard(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: _logout,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout),
                            SizedBox(width: 8),
                            Text('Logout'),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    'Transportation Route Management System',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const Text(
                    'Version 1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Flexible(
                  child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.black54), textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child, this.borderColor, this.bgColor});
  final Widget child;
  final Color? borderColor;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _BlueTopCardCompact extends StatelessWidget {
  const _BlueTopCardCompact({ required this.name, required this.phone, required this.role });
  final String name;
  final String phone;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(phone, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(role.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

/// Labeled obscured input (keeps parent simple)
class _LabeledObscuredInput extends StatelessWidget {
  const _LabeledObscuredInput({
    required this.label,
    required this.hint,
    required this.controller,
    required this.showing,
    required this.onToggle,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool showing;
  final VoidCallback onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final field = Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: !showing,
              enabled: enabled,
              onChanged: (_) {}, // controller listeners handle setState
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: onToggle,
            icon: Icon(showing ? Icons.visibility_off : Icons.visibility, color: Colors.black54),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        field,
      ],
    );
  }
}
