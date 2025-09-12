import 'package:flutter/material.dart';
import '../utils/auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key, required this.onLoginSuccess}) : super(key: key);
  final VoidCallback onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _showPassword = false;

  // Blue gradient
  static const _gradA = Color(0xFF3B82F6); // blue-500
  static const _gradB = Color(0xFF1E3A8A); // blue-900

  String _defaultCountryCode = '+251';

  bool get _canSubmit =>
      !_loading && _phoneCtrl.text.trim().isNotEmpty && _passCtrl.text.isNotEmpty;

  String _normalizeEtPhone(String raw) {
    String p = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (p.startsWith('+')) return p;
    if (p.startsWith('0')) p = p.substring(1);
    if (p.startsWith('251')) return '+$p';
    if (p.length == 9 && p.startsWith('9')) return '$_defaultCountryCode$p';
    return '$_defaultCountryCode$p';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_canSubmit) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final phoneForApi = _normalizeEtPhone(_phoneCtrl.text.trim());
      final resp = await login(phoneForApi, _passCtrl.text);
      if (resp.success) {
        widget.onLoginSuccess();
      } else {
        setState(() => _error = resp.error ?? 'Login failed');
      }
    } catch (_) {
      setState(() => _error = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _underlineDecoration(
    String label, {
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
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
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    final safeTop = mq.padding.top;
    final headerH = (h * 0.24).clamp(160.0, 280.0);

    return Scaffold(
      body: Container(
        height: h,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradA, _gradB],
          ),
        ),
        child: Column(
          children: [
            // ===== Blue header =====
            Container(
              height: headerH,
              padding: EdgeInsets.fromLTRB(20, safeTop + 12, 20, 12),
              alignment: Alignment.topLeft,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 6),
                  Text(
                    'Hello',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Sign in!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),

            // ===== White sheet (rounded top only), fills to bottom =====
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
                                Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(color: Colors.red.shade700, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Phone (underline + icon)
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          enabled: !_loading,
                          decoration: _underlineDecoration(
                            'Phone Number',
                            prefixIcon: const Icon(Icons.phone_iphone),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _canSubmit ? _submit() : null,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),

                        // Password (underline + icon + show/hide)
                        TextField(
                          controller: _passCtrl,
                          enabled: !_loading,
                          obscureText: !_showPassword,
                          decoration: _underlineDecoration(
                            'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _canSubmit ? _submit() : null,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 24),

                        // SIGN IN gradient pill button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: _canSubmit
                                  ? const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [_gradA, _gradB],
                                    )
                                  : LinearGradient(
                                      colors: [Colors.grey.shade300, Colors.grey.shade400],
                                    ),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: ElevatedButton(
                              onPressed: _canSubmit ? _submit : null,
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
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'SIGN IN',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ),
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