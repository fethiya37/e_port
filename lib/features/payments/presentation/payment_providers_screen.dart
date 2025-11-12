import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../layout/feature_layout.dart';
import '../../../widgets/common_row.dart';
import '../data/payments_api.dart';

class PaymentProvidersScreen extends StatefulWidget {
  final String plateNumber;
  final String feePlan; // 'WEEKLY' | 'MONTHLY'
  final int prepayQty;
  final DateTime coveredStart;
  final DateTime coveredEnd;
  final num amount;

  const PaymentProvidersScreen({
    super.key,
    required this.plateNumber,
    required this.feePlan,
    required this.prepayQty,
    required this.coveredStart,
    required this.coveredEnd,
    required this.amount,
  });

  @override
  State<PaymentProvidersScreen> createState() => _PaymentProvidersScreenState();
}

class _PaymentProvidersScreenState extends State<PaymentProvidersScreen> {
  bool loading = false;
  String? error;

  Future<void> _startChapa() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await initiateChapaPayment(
        plateNumber: widget.plateNumber,
        feePlan: widget.feePlan,
        prepayQty: widget.prepayQty,
        coveredStart: widget.coveredStart,
        coveredEnd: widget.coveredEnd,
        amount: widget.amount,
      );

      final checkoutUrl = result['checkout_url'] as String?;
      final txRef = result['tx_ref'] as String?;

      if (checkoutUrl == null || txRef == null) {
        throw Exception('Checkout URL not returned from server.');
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChapaCheckoutScreen(checkoutUrl: checkoutUrl, txRef: txRef),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Returned from payment page')),
      );
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _headerSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ታርጋ: ${widget.plateNumber} • ${widget.feePlan == 'WEEKLY' ? 'ሳምንታዊ' : 'ወርሃዊ'}',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'መጠን: ${widget.amount} ETB  •  ቅድመ ክፍያ: ${widget.prepayQty}',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _providersBody() {
    final providers = [
      {
        'name': 'Chapa',
        'icon': 'assets/icons/chapa.png',
        'available': true,
        'onTap': _startChapa,
      },
      {
        'name': 'Telebirr',
        'icon': 'assets/icons/telebirr.png',
        'available': false,
        'onTap': null,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: GoogleFonts.poppins(color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 10),

        // Providers (shorter height + no trailing arrow)
        ...providers.map((p) {
          final available = p['available'] as bool;
          final iconPath = p['icon'] as String;
          final name = p['name'] as String;
          final onTap = p['onTap'] as VoidCallback?;
          return InkWell(
            onTap: available ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ), // ↓ shorter height
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: available ? Colors.transparent : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Image.asset(
                    iconPath,
                    height: 48, // ↓ smaller icon
                    width: 48,
                    fit: BoxFit.contain,
                    color: available ? null : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 16, // ↓ slightly smaller text to match height
                        fontWeight: FontWeight.w600,
                        color: available ? Colors.black87 : Colors.black54,
                      ),
                    ),
                  ),
                  // (no chevron)
                  if (!available)
                    Text(
                      'Coming soon',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 12),
        rowBold('ጠቅላላ ክፍያ', '${widget.amount} ETB'),
        const SizedBox(height: 6),

        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FeatureLayout(
      title: 'ክፍያ ይፈፅሙ',
      icon: Icons.payments_outlined,
      headerChild: _headerSummary(),
      body: _providersBody(),
    );
  }
}

class ChapaCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;
  final String txRef;

  const ChapaCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.txRef,
  });

  @override
  State<ChapaCheckoutScreen> createState() => _ChapaCheckoutScreenState();
}

class _ChapaCheckoutScreenState extends State<ChapaCheckoutScreen> {
  static const _primary = Color(0xFF0284c7);
  WebViewController? _ctrl;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (url.contains('chapa.co')) _startPolling();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (t) async {
      try {
        final ok = await verifyChapaPayment(widget.txRef);
        if (ok) {
          t.cancel();
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Payment successful!')),
          );
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chapa Payment'),
        backgroundColor: _primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _ctrl?.reload(),
          ),
        ],
      ),
      body: _ctrl == null
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _ctrl!),
    );
  }
}
