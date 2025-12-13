import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Playback Settings
              _buildSectionHeader('Playback'),
              _buildSettingsCard([
                _buildSwitchTile(
                  context,
                  title: 'Auto-play',
                  subtitle: 'Automatically start playback when selecting a channel',
                  icon: Icons.play_circle_outline_rounded,
                  value: settings.autoPlay,
                  onChanged: (value) => settings.setAutoPlay(value),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  context,
                  title: 'Hardware Decoding',
                  subtitle: 'Use hardware acceleration for video playback',
                  icon: Icons.memory_rounded,
                  value: settings.hardwareDecoding,
                  onChanged: (value) => settings.setHardwareDecoding(value),
                ),
                _buildDivider(),
                _buildSelectTile(
                  context,
                  title: 'Buffer Size',
                  subtitle: '${settings.bufferSize} seconds',
                  icon: Icons.storage_rounded,
                  onTap: () => _showBufferSizeDialog(context, settings),
                ),
              ]),
              
              const SizedBox(height: 24),
              
              // Playlist Settings
              _buildSectionHeader('Playlists'),
              _buildSettingsCard([
                _buildSwitchTile(
                  context,
                  title: 'Auto-refresh',
                  subtitle: 'Automatically update playlists periodically',
                  icon: Icons.refresh_rounded,
                  value: settings.autoRefresh,
                  onChanged: (value) => settings.setAutoRefresh(value),
                ),
                if (settings.autoRefresh) ...[
                  _buildDivider(),
                  _buildSelectTile(
                    context,
                    title: 'Refresh Interval',
                    subtitle: 'Every ${settings.refreshInterval} hours',
                    icon: Icons.schedule_rounded,
                    onTap: () => _showRefreshIntervalDialog(context, settings),
                  ),
                ],
                _buildDivider(),
                _buildSwitchTile(
                  context,
                  title: 'Remember Last Channel',
                  subtitle: 'Resume playback from last watched channel',
                  icon: Icons.history_rounded,
                  value: settings.rememberLastChannel,
                  onChanged: (value) => settings.setRememberLastChannel(value),
                ),
              ]),
              
              const SizedBox(height: 24),
              
              // EPG Settings
              _buildSectionHeader('EPG (Electronic Program Guide)'),
              _buildSettingsCard([
                _buildSwitchTile(
                  context,
                  title: 'Enable EPG',
                  subtitle: 'Show program information for channels',
                  icon: Icons.event_note_rounded,
                  value: settings.enableEpg,
                  onChanged: (value) => settings.setEnableEpg(value),
                ),
                if (settings.enableEpg) ...[
                  _buildDivider(),
                  _buildInputTile(
                    context,
                    title: 'EPG URL',
                    subtitle: settings.epgUrl ?? 'Not configured',
                    icon: Icons.link_rounded,
                    onTap: () => _showEpgUrlDialog(context, settings),
                  ),
                ],
              ]),
              
              const SizedBox(height: 24),
              
              // Parental Control
              _buildSectionHeader('Parental Control'),
              _buildSettingsCard([
                _buildSwitchTile(
                  context,
                  title: 'Enable Parental Control',
                  subtitle: 'Require PIN to access certain content',
                  icon: Icons.lock_outline_rounded,
                  value: settings.parentalControl,
                  onChanged: (value) => settings.setParentalControl(value),
                ),
                if (settings.parentalControl) ...[
                  _buildDivider(),
                  _buildActionTile(
                    context,
                    title: 'Change PIN',
                    subtitle: 'Update your parental control PIN',
                    icon: Icons.pin_rounded,
                    onTap: () => _showChangePinDialog(context, settings),
                  ),
                ],
              ]),
              
              const SizedBox(height: 24),
              
              // About Section
              _buildSectionHeader('About'),
              _buildSettingsCard([
                _buildInfoTile(
                  context,
                  title: 'Version',
                  value: '1.0.0',
                  icon: Icons.info_outline_rounded,
                ),
                _buildDivider(),
                _buildInfoTile(
                  context,
                  title: 'Platform',
                  value: _getPlatformName(),
                  icon: Icons.devices_rounded,
                ),
              ]),
              
              const SizedBox(height: 24),
              
              // Reset Section
              _buildSettingsCard([
                _buildActionTile(
                  context,
                  title: 'Reset All Settings',
                  subtitle: 'Restore all settings to default values',
                  icon: Icons.restore_rounded,
                  isDestructive: true,
                  onTap: () => _confirmResetSettings(context, settings),
                ),
              ]),
              
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
  
  String _getPlatformName() {
    if (PlatformDetector.isTV) return 'Android TV';
    if (PlatformDetector.isAndroid) return 'Android';
    if (PlatformDetector.isWindows) return 'Windows';
    return 'Unknown';
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
  
  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }
  
  Widget _buildDivider() {
    return const Divider(
      color: AppTheme.cardColor,
      height: 1,
      indent: 56,
    );
  }
  
  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return TVFocusable(
      onSelect: () => onChanged(!value),
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          decoration: BoxDecoration(
            color: isFocused ? AppTheme.cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSelectTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return TVFocusable(
      onSelect: onTap,
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          decoration: BoxDecoration(
            color: isFocused ? AppTheme.cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        );
      },
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInputTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return _buildSelectTile(
      context,
      title: title,
      subtitle: subtitle,
      icon: icon,
      onTap: onTap,
    );
  }
  
  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return TVFocusable(
      onSelect: onTap,
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          decoration: BoxDecoration(
            color: isFocused
                ? (isDestructive
                    ? AppTheme.errorColor.withOpacity(0.1)
                    : AppTheme.cardColor)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        );
      },
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDestructive ? AppTheme.errorColor : AppTheme.primaryColor)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? AppTheme.errorColor : AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive
                            ? AppTheme.errorColor
                            : AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.textMuted.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.textMuted, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showBufferSizeDialog(BuildContext context, SettingsProvider settings) {
    final options = [10, 20, 30, 45, 60];
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text(
            'Buffer Size',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((seconds) {
              return RadioListTile<int>(
                title: Text(
                  '$seconds seconds',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                value: seconds,
                groupValue: settings.bufferSize,
                onChanged: (value) {
                  if (value != null) {
                    settings.setBufferSize(value);
                    Navigator.pop(context);
                  }
                },
                activeColor: AppTheme.primaryColor,
              );
            }).toList(),
          ),
        );
      },
    );
  }
  
  void _showRefreshIntervalDialog(BuildContext context, SettingsProvider settings) {
    final options = [6, 12, 24, 48, 72];
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text(
            'Refresh Interval',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((hours) {
              return RadioListTile<int>(
                title: Text(
                  hours < 24 ? '$hours hours' : '${hours ~/ 24} day${hours > 24 ? 's' : ''}',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                value: hours,
                groupValue: settings.refreshInterval,
                onChanged: (value) {
                  if (value != null) {
                    settings.setRefreshInterval(value);
                    Navigator.pop(context);
                  }
                },
                activeColor: AppTheme.primaryColor,
              );
            }).toList(),
          ),
        );
      },
    );
  }
  
  void _showEpgUrlDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.epgUrl);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text(
            'EPG URL',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Enter EPG XMLTV URL',
              hintStyle: TextStyle(color: AppTheme.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                settings.setEpgUrl(controller.text.trim().isEmpty
                    ? null
                    : controller.text.trim());
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
  
  void _showChangePinDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text(
            'Set PIN',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Enter 4-digit PIN',
              hintStyle: TextStyle(color: AppTheme.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.length == 4) {
                  settings.setParentalPin(controller.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
  
  void _confirmResetSettings(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text(
            'Reset Settings',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: const Text(
            'Are you sure you want to reset all settings to their default values?',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                settings.resetSettings();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}
