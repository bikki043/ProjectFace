import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/profile_info_item.dart';
import '../widgets/change_password_dialog.dart';

class ProfileTab extends StatefulWidget {
  final UserProfile profile;
  final ApiService apiService;
  final ValueChanged<UserProfile> onProfileUpdated;
  final VoidCallback onLogout;

  const ProfileTab({
    super.key,
    required this.profile,
    required this.apiService,
    required this.onProfileUpdated,
    required this.onLogout,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isUploadingAvatar = false;
  bool _isSavingProfile = false;

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final newUrl = await widget.apiService.uploadAvatar(File(picked.path));
      widget.onProfileUpdated(widget.profile.copyWith(avatarUrl: newUrl));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปลี่ยนรูปโปรไฟล์ไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _editProfile() async {
    final edited = await showEditProfileDialog(context: context, profile: widget.profile);
    if (edited == null) return;

    setState(() => _isSavingProfile = true);
    try {
      final saved = await widget.apiService.updateProfile(edited);
      widget.onProfileUpdated(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกข้อมูลไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;

    return Container(
      color: AppColors.bg,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.primarySoft,
                  backgroundImage: profile.avatarUrl.isNotEmpty ? NetworkImage(profile.avatarUrl) : null,
                  child: profile.avatarUrl.isEmpty
                      ? Icon(Icons.person_rounded, size: 52, color: AppColors.primary)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isUploadingAvatar ? null : _changeAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bg, width: 3),
                      ),
                      child: _isUploadingAvatar
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Center(child: Text(profile.name, style: AppText.displayLg)),
          const SizedBox(height: 2),
          Center(child: Text(profile.position, style: AppText.bodyDim)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: AppColors.ink.withOpacity(0.03), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                ProfileInfoItem(label: 'รหัสพนักงาน', value: profile.employeeId, icon: Icons.badge_outlined),
                Divider(color: AppColors.divider, height: 1),
                ProfileInfoItem(label: 'เบอร์โทรศัพท์', value: profile.phone, icon: Icons.phone_android_outlined),
                Divider(color: AppColors.divider, height: 1),
                ProfileInfoItem(label: 'แผนก / ตำแหน่ง', value: profile.position, icon: Icons.work_outline_rounded),
                Divider(color: AppColors.divider, height: 1),
                ProfileInfoItem(
                  label: 'สถานะการทำงาน',
                  value: profile.employmentStatus,
                  icon: Icons.verified_user_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _isSavingProfile ? null : _editProfile,
              icon: _isSavingProfile
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.edit_rounded, size: 18),
              label: Text('แก้ไขข้อมูลส่วนตัว', style: AppText.button.copyWith(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => showChangePasswordDialog(
                context: context,
                apiService: widget.apiService,
              ),
              icon: const Icon(Icons.lock_outline_rounded, size: 18),
              label: Text('เปลี่ยนรหัสผ่าน', style: AppText.button.copyWith(color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.coral,
                side: BorderSide(color: AppColors.coral),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text('ออกจากระบบ', style: AppText.button.copyWith(color: AppColors.coral)),
            ),
          ),
        ],
      ),
    );
  }
}