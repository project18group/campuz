import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:mobile/core/services/auth_api_service.dart';

class TopUpScreen extends StatefulWidget {
  final int hubId;
  const TopUpScreen({super.key, required this.hubId});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  bool _isLoading = false;
  String? _checkoutUrl;
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
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  Future<void> _initializeTopUp(String bundle) async {
    setState(() => _isLoading = true);
    try {
      final response = await AuthApiService.initializeSmsTopUp(
        hubId: widget.hubId,
        bundle: bundle,
      );
      final url = response['authorization_url'];
      if (url != null) {
        setState(() {
          _checkoutUrl = url;
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
          title: const Text('Complete Payment'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).pop(true); // Return true to trigger refresh
            },
          ),
        ),
        body: WebViewWidget(controller: _controller),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Up SMS Balance'),
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
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    title: Text(
                      '${bundle['size']} SMS',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text(bundle['desc']),
                    trailing: ElevatedButton(
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
