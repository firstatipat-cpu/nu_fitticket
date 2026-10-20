import 'package:flutter/material.dart';

/// ช่องกรอกรหัสตั๋วสำรอง (ใช้ร่วมกันทุกหน้าที่สแกนตั๋ว)
/// เจ้าของ: <67314858>
class ManualCodeField extends StatelessWidget {
  const ManualCodeField({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.enabled = true,
    this.hint = 'กรอกรหัสตั๋วสำรอง (6 ตัว)',
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final bool enabled;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onSubmitted: enabled ? onSubmit : null,
          decoration: InputDecoration(
            labelText: hint,
            prefixIcon: const Icon(Icons.keyboard),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: enabled ? () => onSubmit(controller.text) : null,
          child: const Text('ตรวจรหัสตั๋ว'),
        ),
      ],
    );
  }
}
