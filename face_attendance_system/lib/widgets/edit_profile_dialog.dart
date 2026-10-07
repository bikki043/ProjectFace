import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';

/// Returns the edited UserProfile if the user saved, or null if cancelled.
Future<UserProfile?> showEditProfileDialog({
  required BuildContext context,
  required UserProfile profile,
}) {
  final nameController = TextEditingController(text: profile.name);
  final phoneController = TextEditingController(text: profile.phone);
  final formKey = GlobalKey<FormState>();

  return showDialog<UserProfile>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('แก้ไขข้อมูลส่วนตัว', style: TextStyle(color: AppColors.ink)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                style: TextStyle(color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'ชื่อ-นามสกุล',
                  labelStyle: TextStyle(color: AppColors.inkDim),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.panelLine)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'เบอร์โทรศัพท์',
                  labelStyle: TextStyle(color: AppColors.inkDim),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.panelLine)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกเบอร์โทรศัพท์' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก', style: TextStyle(color: AppColors.inkDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                profile.copyWith(
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                ),
              );
            },
            child: Text('บันทึก', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
  );
}
