import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';

class TopUpScreen extends StatefulWidget {
  final int hubId;
  const TopUpScreen({super.key, required this.hubId});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  bool _isLoading = false;
  String? _checkoutUrl;
  String? _reference;
  late final WebViewController _controller;

  final List<Map<String, dynamic>> _bundles = [
    {'size': '100', 'price': 5, 'desc': 'Good for small classes'},
    {'size': '500', 'price': 25, 'desc': 'Most popular'},
    {'size': '1000', 'price': 50, 'desc': 'Best value for departments'},
  ];

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://campuz-api.onrender.com/payment/callback/')) {
              _verifyPayment();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  Future<void> _verifyPayment() async {
    if (_reference == null) {
      Navigator.of(context).pop(true);
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await AuthApiService.verifySmsTopUp(
        hubId: widget.hubId,
        reference: _reference!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified and credits added successfully!')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verifying payment: $e')),
        );
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _initializeTopUp(String bundle) async {
    setState(() => _isLoading = true);
    try {
      final response = await AuthApiService.initializeSmsTopUp(
        hubId: widget.hubId,
        bundle: bundle,
      );
      final url = response['authorization_url'];
      final reference = response['reference'];
      if (url != null) {
        setState(() {
          _checkoutUrl = url;
          _reference = reference;
          _isLoading = false;
        });
        _controller.loadRequest(Uri.parse(url));
      } else {
        throw Exception("Failed to get checkout URL");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing payment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkoutUrl != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Complete Payment',
            style: AppTextStyles.heading.copyWith(fontSize: 20),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ),
        body: WebViewWidget(controller: _controller),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Top Up SMS Balance',
          style: AppTextStyles.heading.copyWith(fontSize: 20),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _bundles.length,
              itemBuilder: (context, index) {
                final bundle = _bundles[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 0,
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.border, width: 1),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    title: Text(
                      '${bundle['size']} SMS',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      bundle['desc'],
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: FilledButton(
                      onPressed: () => _initializeTopUp(bundle['size']),
                      child: Text('GHS ${bundle['price']}'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
