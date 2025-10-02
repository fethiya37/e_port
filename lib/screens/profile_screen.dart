// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import '../utils/auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _gradA = Color(0xFF0ea5e9);
  static const _gradB = Color(0xFF0284c7);
  static const _gradC = Color(0xFF0c4a6e);

  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();

  bool _showOld = false;
  bool _showNew = false;
  bool _loading = false;
  String? _error;

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
      _newCtrl.text.length >= 4; // ✅ minimum 4 chars

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('የአሁኑን የይለፍ ቃል እና አዲስ በትክክል ያስገቡ (ከ 4 አሃዝ በላይ)።'),
        ),
      );
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final res = await changePassword(_oldCtrl.text, _newCtrl.text);
      if (res.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('የይለፍ ቃል ተሻሽሏል')),
          );
        }
        _oldCtrl.clear();
        _newCtrl.clear();
        setState(() {
          _showOld = false;
          _showNew = false;
        });
      } else {
        setState(() => _error = res.error ?? 'የይለፍ ቃል መቀየር አልተሳካም');
      }
    } catch (_) {
      setState(() => _error = 'የኔትዎርክ ችግኝ። እባክዎ ደግመው ይሞክሩ።');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _logout() async {
    await logout();
    widget.onLogout();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ወጥተዋል')),
      );
    }
  }

  InputDecoration _underlineDecoration({
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _gradA, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    final safeTop = mq.padding.top;
    final headerH = (h * 0.15).clamp(140.0, 180.0);

    final assocLabel =
        (user.associationName != null && user.associationName!.isNotEmpty)
            ? user.associationName!
            : (user.associationId != null
                ? 'ማህበር #${user.associationId}'
                : 'ማህበር አልተገለጸም');

    return Scaffold(
      body: Container(
        height: h,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.topRight,
            colors: [_gradA, _gradB, _gradC],
          ),
        ),
        child: Column(
          children: [
            // ===== Gradient header =====
            Container(
              height: headerH,
              padding: EdgeInsets.fromLTRB(20, safeTop + 12, 20, 20),
              alignment: Alignment.topLeft,
              child: const Row(
                children: [
                  Icon(Icons.person_outline, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'መገለጫ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Identity block
            Transform.translate(
              offset: Offset(0, -(headerH - (safeTop + 64))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _IdentityHeaderBlock(
                  name: (user.name == null || user.name!.trim().isEmpty)
                      ? user.phoneNumber
                      : user.name!,
                  phone: user.phoneNumber,
                  association: assocLabel,
                ),
              ),
            ),

            // ===== White sheet =====
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(26)),
                child: Container(
                  color: Colors.white,
                  width: double.infinity,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade400, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                        color: Colors.red.shade700,
                                        height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const Text(
                          'የአሁኑ የይለፍ ቃል',
                          style: TextStyle(
                            color: _gradA,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        TextField(
                          controller: _oldCtrl,
                          enabled: !_loading,
                          obscureText: !_showOld,
                          decoration: _underlineDecoration(
                            hintText: 'የአሁኑን የይለፍ ቃል ያስገቡ',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_showOld
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _showOld = !_showOld),
                            ),
                          ),
                          onSubmitted: (_) => _changePassword(),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),

                        const Text(
                          'አዲስ የይለፍ ቃል',
                          style: TextStyle(
                            color: _gradA,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        TextField(
                          controller: _newCtrl,
                          enabled: !_loading,
                          obscureText: !_showNew,
                          decoration: _underlineDecoration(
                            hintText: 'ቢያንስ 4 አሃዝ',
                            prefixIcon: const Icon(Icons.key_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(_showNew
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _showNew = !_showNew),
                            ),
                          ),
                          onSubmitted: (_) => _changePassword(),
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 28),

                        // UPDATE PASSWORD
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [_gradA, _gradB],
                              ),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: ElevatedButton(
                              onPressed: _loading ? null : _changePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                foregroundColor: Colors.white,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'የይለፍ ቃል ያስተካክሉ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Center(
                          child: InkWell(
                            onTap: _loading ? null : _logout,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.logout,
                                      color: Colors.red, size: 20),
                                  SizedBox(width: 6),
                                  Text(
                                    'ዘግተው ይውጡ',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Header identity =====
class _IdentityHeaderBlock extends StatelessWidget {
  const _IdentityHeaderBlock({
    required this.name,
    required this.phone,
    required this.association,
  });

  final String name;
  final String phone;
  final String association;

  @override
  Widget build(BuildContext context) {
    const primary = Colors.white;
    const secondary = Colors.white70;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black26)],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: secondary,
                        shadows: [
                          Shadow(
                              blurRadius: 4,
                              color: Colors.black26,
                              offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.apartment_outlined,
                      size: 14, color: secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      association,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: secondary,
                        shadows: [
                          Shadow(
                              blurRadius: 4,
                              color: Colors.black26,
                              offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
