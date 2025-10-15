import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoginSuccess});
  final VoidCallback onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  static const _gradA = Color(0xFF0ea5e9);
  static const _gradB = Color(0xFF0284c7);
  static const _gradC = Color(0xFF0c4a6e);

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() {
      if (_phoneFocus.hasFocus && _phoneCtrl.text.isEmpty) {
        _phoneCtrl.text = '+251';
        _phoneCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _phoneCtrl.text.length),
        );
      }
    });
  }

  void _onPhoneChanged(String value) {
    if (!value.startsWith('+251') || value.length < 4) {
      _phoneCtrl.text = '+251';
      _phoneCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _phoneCtrl.text.length),
      );
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_loading) return;

    final phoneForApi = _phoneCtrl.text.trim();
    final password = _passCtrl.text;

    if (phoneForApi.length != 13) {
      setState(() => _error = 'ስልክ ቁጥርዎ 13 አሃዝ መሆን አለት');
      return;
    }
    if (password.length < 4) {
      setState(() => _error = 'የይለፍ ቃል ቢያንስ 4 አሃዝ መሆን አለት');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final resp = await login(phoneForApi, password);
      if (resp.success) {
        widget.onLoginSuccess();
      } else {
        setState(() => _error = resp.error ?? 'መግባት አልተሳካም');
      }
    } catch (_) {
      setState(() => _error = 'የኔትዎርክ ችግር። እባክዎን ደግመው ይሞክሩ።');
    } finally {
      if (mounted) setState(() => _loading = false);
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
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _phoneFocus.dispose();
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
            end: Alignment.topRight,
            colors: [_gradA, _gradB, _gradC],
          ),
        ),
        child: Column(
          children: [
            // ===== HEADER =====
            Container(
              height: headerH,
              padding: EdgeInsets.fromLTRB(20, safeTop, 20, 0),
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('E-PORT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      )),
                  Text('ግባ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      )),
                ],
              ),
            ),

            // ===== FORM SHEET =====
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
                        if (_error != null)
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

                        // ===== PHONE INPUT =====
                        const Text('ስልክ ቁጥር',
                            style: TextStyle(
                                color: _gradA,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 2),
                        TextField(
                          controller: _phoneCtrl,
                          focusNode: _phoneFocus,
                          keyboardType: TextInputType.phone,
                          enabled: !_loading,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(13),
                          ],
                          decoration: _underlineDecoration(
                            hintText: 'ስልክ ቁጥር ያስገቡ',
                            prefixIcon: const Icon(Icons.phone_iphone),
                          ),
                          onChanged: _onPhoneChanged,
                          onSubmitted: (_) => _submit(),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),

                        // ===== PASSWORD INPUT =====
                        const Text('የይለፍ ቃል',
                            style: TextStyle(
                                color: _gradA,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        const SizedBox(height: 2),
                        TextField(
                          controller: _passCtrl,
                          enabled: !_loading,
                          obscureText: !_showPassword,
                          decoration: _underlineDecoration(
                            hintText: 'የይለፍ ቃል ያስገቡ',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => _showPassword = !_showPassword),
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 40),

                        // ===== SIGN-IN BUTTON =====
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
                              onPressed: _loading ? null : _submit,
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
                                  : const Text('ግባ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5)),
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
