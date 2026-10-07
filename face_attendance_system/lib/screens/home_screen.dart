import 'package:flutter/material.dart';
import '../models/attendance_record.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_controller.dart';
import 'calendar_tab.dart';
import 'dashboard_tab.dart';
import 'payroll_tab.dart';
import 'profile_tab.dart';
import 'settings_screen.dart';

class _HomeData {
  final UserProfile profile;
  final List<AttendanceRecord> history;
  const _HomeData({required this.profile, required this.history});

  _HomeData copyWith({UserProfile? profile, List<AttendanceRecord>? history}) {
    return _HomeData(profile: profile ?? this.profile, history: history ?? this.history);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();
  final _payrollTabKey = GlobalKey<PayrollTabState>();

  late Future<_HomeData> _dataFuture;
  _HomeData? _data; // cached once loaded, so tab switches/edits don't need a refetch
  int _currentIndex = 0;
  bool _isRefreshing = false;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  static const _titles = ['ภาพรวม', 'ปฏิทินประวัติ', 'เงินเดือน', 'โปรไฟล์'];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    setState(() {
      _dataFuture = _fetchAll();
    });
  }

  Future<void> _refreshCurrentTab() async {
    if (_currentIndex == 2) {
      await _payrollTabKey.currentState?.refresh();
      return;
    }
    if (mounted) setState(() => _isRefreshing = true);
    _loadAll();
    try {
      await _dataFuture;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('รีเฟรชไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<_HomeData> _fetchAll() async {
    final profile = await _apiService.getProfile();
    final history = await _apiService.getAttendanceHistory(
      month: _selectedMonth.month,
      year: _selectedMonth.year,
    );
    final data = _HomeData(profile: profile, history: history);
    _data = data;
    return data;
  }

  Future<void> _changeMonth(DateTime newMonth) async {
    setState(() => _selectedMonth = DateTime(newMonth.year, newMonth.month, 1));
    final history = await _apiService.getAttendanceHistory(
      month: _selectedMonth.month,
      year: _selectedMonth.year,
    );
    if (!mounted || _data == null) return;
    setState(() {
      _data = _data!.copyWith(history: history);
      _dataFuture = Future.value(_data!);
    });
  }

  void _onProfileUpdated(UserProfile updated) {
    if (_data == null) return;
    setState(() {
      _data = _data!.copyWith(profile: updated);
      _dataFuture = Future.value(_data!);
    });
  }

  Future<void> _handleLogout() async {
    await _apiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder forces this whole screen (and every tab it builds
    // below) to rebuild whenever the person changes theme/accent in
    // Settings, so the new AppColors values actually show up without
    // losing the navigation stack or refetching data.
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            title: Text(_titles[_currentIndex], style: AppText.displayMd),
            actions: [
              IconButton(
                icon: _isRefreshing
                    ? SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                      )
                    : Icon(Icons.refresh_rounded, color: AppColors.ink),
                onPressed: _refreshCurrentTab,
              ),
              IconButton(
                icon: Icon(Icons.settings_outlined, color: AppColors.ink),
                onPressed: _openSettings,
              ),
            ],
          ),
          body: FutureBuilder<_HomeData>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _data == null) {
                return Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError && _data == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'โหลดข้อมูลไม่สำเร็จ: ${snapshot.error}',
                      style: AppText.body.copyWith(color: AppColors.coral),
                    ),
                  ),
                );
              }

              final data = snapshot.data ?? _data!;
              switch (_currentIndex) {
                case 0:
                  return DashboardTab(profile: data.profile, history: data.history);
                case 1:
                  return CalendarTab(
                    history: data.history,
                    selectedMonth: _selectedMonth,
                    onMonthChanged: _changeMonth,
                  );
                case 2:
                  return PayrollTab(key: _payrollTabKey, apiService: _apiService);
                case 3:
                  return ProfileTab(
                    profile: data.profile,
                    apiService: _apiService,
                    onProfileUpdated: _onProfileUpdated,
                    onLogout: _handleLogout,
                  );
                default:
                  return DashboardTab(profile: data.profile, history: data.history);
              }
            },
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: AppColors.primary,
                  unselectedItemColor: AppColors.inkDim,
                  selectedLabelStyle: AppText.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: AppText.label,
                  onTap: (index) => setState(() => _currentIndex = index),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard_outlined),
                      activeIcon: Icon(Icons.dashboard_rounded),
                      label: 'ภาพรวม',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.calendar_month_outlined),
                      activeIcon: Icon(Icons.calendar_month_rounded),
                      label: 'ปฏิทิน',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.payments_outlined),
                      activeIcon: Icon(Icons.payments_rounded),
                      label: 'เงินเดือน',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline_rounded),
                      activeIcon: Icon(Icons.person_rounded),
                      label: 'โปรไฟล์',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
