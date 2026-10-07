import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _notifyCheckInKey = 'settings.notify_checkin';
  static const _notifyLateKey = 'settings.notify_late';

  bool _notifyCheckIn = true;
  bool _notifyLate = true;
  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifyCheckIn = prefs.getBool(_notifyCheckInKey) ?? true;
      _notifyLate = prefs.getBool(_notifyLateKey) ?? true;
      _loadingPrefs = false;
    });
  }

  Future<void> _setNotifyCheckIn(bool value) async {
    setState(() => _notifyCheckIn = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifyCheckInKey, value);
  }

  Future<void> _setNotifyLate(bool value) async {
    setState(() => _notifyLate = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifyLateKey, value);
  }

  @override
  Widget build(BuildContext context) {
    // Listens directly so this screen updates instantly as the person taps
    // around, instead of waiting until they navigate back.
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            title: Text('ตั้งค่า', style: AppText.displayMd),
          ),
          body: _loadingPrefs
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _SectionLabel('ธีมสี'),
                    const SizedBox(height: 12),
                    const _AccentPicker(),
                    const SizedBox(height: 28),
                    _SectionLabel('โหมดการแสดงผล'),
                    const SizedBox(height: 8),
                    _ModeTile(
                      title: 'อัตโนมัติตามระบบ',
                      subtitle: 'ใช้โหมดสว่าง/มืดตามการตั้งค่าของเครื่อง',
                      icon: Icons.brightness_auto_rounded,
                      selected: ThemeController.instance.mode == ThemeMode.system,
                      onTap: () => ThemeController.instance.setMode(ThemeMode.system),
                    ),
                    _ModeTile(
                      title: 'โหมดสว่าง',
                      subtitle: 'พื้นหลังสีอ่อน เหมาะกับกลางวัน',
                      icon: Icons.light_mode_rounded,
                      selected: ThemeController.instance.mode == ThemeMode.light,
                      onTap: () => ThemeController.instance.setMode(ThemeMode.light),
                    ),
                    _ModeTile(
                      title: 'โหมดมืด',
                      subtitle: 'พื้นหลังสีเข้ม ถนอมสายตาตอนกลางคืน',
                      icon: Icons.dark_mode_rounded,
                      selected: ThemeController.instance.mode == ThemeMode.dark,
                      onTap: () => ThemeController.instance.setMode(ThemeMode.dark),
                    ),
                    const SizedBox(height: 28),
                    _SectionLabel('การแจ้งเตือน'),
                    const SizedBox(height: 10),
                    _buildSwitchCard(
                      title: 'แจ้งเตือนก่อนถึงเวลาเข้างาน',
                      subtitle: 'เตือนล่วงหน้า 15 นาทีก่อนกะเริ่ม',
                      value: _notifyCheckIn,
                      onChanged: _setNotifyCheckIn,
                    ),
                    const SizedBox(height: 10),
                    _buildSwitchCard(
                      title: 'แจ้งเตือนเมื่อมาสาย',
                      subtitle: 'แจ้งเตือนทันทีที่ระบบตรวจพบว่ามาสาย',
                      value: _notifyLate,
                      onChanged: _setNotifyLate,
                    ),
                    const SizedBox(height: 28),
                    _SectionLabel('เกี่ยวกับแอป'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.face_retouching_natural_rounded, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Face Attendance System',
                                    style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('เวอร์ชัน 1.0.0', style: AppText.bodyDim),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeColor: AppColors.primary,
        title: Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: AppText.bodyDim),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppText.label.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3));
  }
}

class _ModeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: selected ? AppColors.primary : AppColors.inkDim),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
                      Text(subtitle, style: AppText.bodyDim),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AppAccent.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final accent = AppAccent.values[index];
          final selected = ThemeController.instance.accent == accent;
          return GestureDetector(
            onTap: () => ThemeController.instance.setAccent(accent),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.seed,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.ink : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(color: accent.seed.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
