import 'package:flutter/material.dart';
import '../theme/rescue_theme.dart';

class CancelReasonTile extends StatelessWidget {
  const CancelReasonTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = RescueTheme.accentFor(context);
    return Material(
      color: accent.withValues(alpha: selected ? .12 : .05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withValues(alpha: selected ? .5 : .18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Returns the selected reason; cancellation and persistence stay in SosScreen.
class SosCancelDialog extends StatefulWidget {
  const SosCancelDialog({super.key});

  @override
  State<SosCancelDialog> createState() => _SosCancelDialogState();
}

class _SosCancelDialogState extends State<SosCancelDialog> {
  final _reason = TextEditingController();
  bool _other = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(
      'ยกเลิก SOS?',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    ),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'แตะเหตุผลเพื่อยกเลิก SOS ทันที',
              style: TextStyle(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 16),
            CancelReasonTile(
              label: 'ได้รับความช่วยเหลือแล้ว',
              icon: Icons.volunteer_activism_outlined,
              onTap: () => Navigator.pop(context, 'ได้รับความช่วยเหลือแล้ว'),
            ),
            const SizedBox(height: 8),
            CancelReasonTile(
              label: 'ปลอดภัยแล้ว',
              icon: Icons.verified_user_outlined,
              onTap: () => Navigator.pop(context, 'ปลอดภัยแล้ว'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            CancelReasonTile(
              label: 'แจ้งผิด',
              icon: Icons.error_outline,
              onTap: () => Navigator.pop(context, 'แจ้งผิด'),
            ),
            const SizedBox(height: 8),
            CancelReasonTile(
              label: 'อื่น ๆ',
              icon: Icons.more_horiz,
              selected: _other,
              onTap: () => setState(() => _other = true),
            ),
            if (_other) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                autofocus: true,
                minLines: 1,
                maxLines: 3,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'เหตุผลเพิ่มเติม',
                  hintText: 'ระบุเหตุผลที่ต้องการยกเลิก',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _reason.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(
                        context,
                        'อื่น ๆ: ${_reason.text.trim()}',
                      ),
                child: const Text('ยืนยันยกเลิก SOS'),
              ),
            ],
          ],
        ),
      ),
    ),
    actionsAlignment: MainAxisAlignment.end,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('กลับ'),
      ),
    ],
  );
}
