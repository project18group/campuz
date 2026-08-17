import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_text_styles.dart';
import 'package:mobile/main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _keyShowSessionBadges = 'settings_show_session_badges';
  static const _keyShowMessagePreviews = 'settings_show_message_previews';
  static const _keyCompactCards = 'settings_compact_cards';
  static const _keyAutoRefreshSeconds = 'settings_auto_refresh_seconds';
  static const _keyEnablePushHints = 'settings_enable_push_hints';

  bool _showSessionBadges = true;
  bool _showMessagePreviews = true;
  bool _compactCards = false;
  bool _enablePushHints = true;
  double _autoRefreshSeconds = 20;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showSessionBadges = prefs.getBool(_keyShowSessionBadges) ?? true;
      _showMessagePreviews = prefs.getBool(_keyShowMessagePreviews) ?? true;
      _compactCards = prefs.getBool(_keyCompactCards) ?? false;
      _enablePushHints = prefs.getBool(_keyEnablePushHints) ?? true;
      _autoRefreshSeconds =
          (prefs.getInt(_keyAutoRefreshSeconds) ?? 20).toDouble().clamp(5, 60);
      _isLoading = false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveSeconds(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAutoRefreshSeconds, value.round());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                // Removed "App behaviour" badge here
                _settingCard(
                  title: 'Dark Mode',
                  subtitle: 'Switch between light and dark themes.',
                  value: themeNotifier.value == ThemeMode.dark,
                  onChanged: (value) async {
                    final newMode = value ? ThemeMode.dark : ThemeMode.light;
                    themeNotifier.value = newMode;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('settings_dark_mode', value);
                  },
                ),
                const SizedBox(height: 12),
                _settingCard(
                  title: 'Show session badges',
                  subtitle: 'Display session badges on Profile and the Sessions tab.',
                  value: _showSessionBadges,
                  onChanged: (value) async {
                    setState(() => _showSessionBadges = value);
                    await _saveBool(_keyShowSessionBadges, value);
                  },
                ),
                const SizedBox(height: 12),
                _settingCard(
                  title: 'Show message previews',
                  subtitle: 'Preview recent chat content in home summaries.',
                  value: _showMessagePreviews,
                  onChanged: (value) async {
                    setState(() => _showMessagePreviews = value);
                    await _saveBool(_keyShowMessagePreviews, value);
                  },
                ),
                const SizedBox(height: 12),
                _settingCard(
                  title: 'Compact cards',
                  subtitle: 'Use tighter spacing across list cards and sections.',
                  value: _compactCards,
                  onChanged: (value) async {
                    setState(() => _compactCards = value);
                    await _saveBool(_keyCompactCards, value);
                  },
                ),
                const SizedBox(height: 12),
                _settingCard(
                  title: 'Push hint banners',
                  subtitle: 'Show gentle hints for reminders and important updates.',
                  value: _enablePushHints,
                  onChanged: (value) async {
                    setState(() => _enablePushHints = value);
                    await _saveBool(_keyEnablePushHints, value);
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Auto-refresh interval',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${_autoRefreshSeconds.round()}s',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.primaryForeground,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Controls how often the home feed checks for fresh content.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Slider(
                        value: _autoRefreshSeconds,
                        min: 5,
                        max: 60,
                        divisions: 11,
                        label: '${_autoRefreshSeconds.round()}s',
                        onChanged: (value) {
                          setState(() => _autoRefreshSeconds = value);
                        },
                        onChangeEnd: _saveSeconds,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _settingCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        title: Text(
          title,
          style: AppTextStyles.label.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        activeThumbColor: AppColors.primary,
      ),
    );
  }
}
