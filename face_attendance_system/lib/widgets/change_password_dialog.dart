import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Shows a dialog for the logged-in employee to change their own password.
/// Handles its own loading state, validation, and error/success messages
/// via SnackBar. The caller doesn't need to do anything with the result.
Future<void> showChangePasswordDialog({
  required BuildContext context,
  required ApiService apiService,
}) {
  return showDialog(
    context: context,
    builder: (context) => _ChangePasswordDialog(apiService: apiService),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  final ApiService apiService;
  const _ChangePasswordDialog({required this.apiService});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.apiService.changePassword(
        _currentController.text,
        _newController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปลี่ยนรหัสผ่านสำเร็จ')),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เปลี่ยนรหัสผ่าน'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'รหัสผ่านเดิม'),
              validator: (v) => (v == null || v.isEmpty) ? 'กรุณากรอกรหัสผ่านเดิม' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'รหัสผ่านใหม่'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่านใหม่';
                if (v.length < 6) return 'ต้องมีอย่างน้อย 6 ตัวอักษร';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'ยืนยันรหัสผ่านใหม่'),
              validator: (v) {
                if (v != _newController.text) return 'รหัสผ่านไม่ตรงกัน';
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('บันทึก'),
        ),
      ],
    );
  }
}