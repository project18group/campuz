import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/services/secure_token_storage.dart';
import 'package:mobile/core/services/auth_api_service.dart';
import 'package:animate_do/animate_do.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _data = {
    'total_hubs_joined': 0,
    'total_messages_sent': 0,
    'total_peers_reached': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await SecureTokenStorage.getAccessToken();
      // We extract the baseUrl from AuthApiService to avoid hardcoding
      final baseUrl = AuthApiService.wsBaseUrl.replaceFirst('ws', 'http').replaceAll(RegExp(r'/api$'), '') + '/api';
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          _data = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load analytics: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = 'Could not fetch data. Are you offline?';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Your Analytics',
          style: AppTextStyles.h2.copyWith(fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _fetchAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.signal_wifi_off_rounded, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text(_error!, style: AppTextStyles.body),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchAnalytics,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                )
              : FadeInUp(
                  child: RefreshIndicator(
                    onRefresh: _fetchAnalytics,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        _buildMetricCard(
                          title: 'Hubs Joined',
                          value: _data['total_hubs_joined'].toString(),
                          icon: Icons.hub_rounded,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(height: 20),
                        _buildMetricCard(
                          title: 'Messages Sent',
                          value: _data['total_messages_sent'].toString(),
                          icon: Icons.message_rounded,
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(height: 20),
                        _buildMetricCard(
                          title: 'Peers Reached',
                          value: _data['total_peers_reached'].toString(),
                          icon: Icons.people_alt_rounded,
                          color: Colors.greenAccent,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.h1.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
