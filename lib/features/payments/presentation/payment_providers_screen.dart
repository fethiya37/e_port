import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/payments_api.dart';

class PaymentProvidersScreen extends StatefulWidget {
  final String plateNumber;
  final String feePlan;
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
  String? checkoutUrl;
  String? txRef;
  Timer? _pollTimer;
  late WebViewController webViewController;

  /// Start Chapa payment
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

      setState(() {
        checkoutUrl = result['checkout_url'];
        txRef = result['tx_ref'];
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  /// Poll payment verification (backend confirms after webhook)
  void _startPolling() {
    if (txRef == null) return;

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final ok = await verifyChapaPayment(txRef!);
        if (ok) {
          timer.cancel();
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Payment successful!')),
            );
          }
        }
      } catch (_) {
        // ignore intermittent errors
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 WebView payment page
    if (checkoutUrl != null) {
      webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              // start polling after checkout page is loaded
              if (url.contains('chapa.co')) _startPolling();
            },
          ),
        )
        ..loadRequest(Uri.parse(checkoutUrl!));

      return Scaffold(
        appBar: AppBar(
          title: const Text('Chapa Payment'),
          backgroundColor: const Color(0xFF0284c7),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => webViewController.reload(),
            )
          ],
        ),
        body: WebViewWidget(controller: webViewController),
      );
    }

    // 🔹 Error view
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose Payment Method')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
              const SizedBox(height: 12),
              Text(
                error!,
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _startChapa,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284c7),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // 🔹 Loading
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose Payment Method')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 🔹 List of payment providers
    final providers = [
      {'name': 'Chapa', 'icon': Icons.payment, 'available': true},
      {'name': 'Telebirr', 'icon': Icons.phone_android, 'available': false},
      {'name': 'CBE', 'icon': Icons.account_balance, 'available': false},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Payment Method'),
        backgroundColor: const Color(0xFF0284c7),
      ),
      body: ListView.builder(
        itemCount: providers.length,
        itemBuilder: (context, i) {
          final p = providers[i];
          final bool available = p['available'] as bool;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(
                p['icon'] as IconData,
                color: available ? const Color(0xFF0284c7) : Colors.grey,
              ),
              title: Text(
                p['name'] as String,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: available ? Colors.black87 : Colors.black54,
                ),
              ),
              trailing: available
                  ? const Icon(Icons.arrow_forward_ios, size: 18)
                  : Text(
                      'Coming soon',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                    ),
              onTap: available && p['name'] == 'Chapa'
                  ? _startChapa
                  : null,
            ),
          );
        },
      ),
    );
  }
}
