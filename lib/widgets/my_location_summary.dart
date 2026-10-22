import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sos_alert.dart';

class MyLocationSummary extends StatefulWidget {
  const MyLocationSummary({super.key, required this.location});
  final SosLocation? location;

  @override
  State<MyLocationSummary> createState() => _MyLocationSummaryState();
}

class _MyLocationSummaryState extends State<MyLocationSummary> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final theme = Theme.of(context);
    final coordinates = location == null
        ? ''
        : '${location.latitude}, ${location.longitude}';
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ตำแหน่งของฉัน',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                tooltip: 'คัดลอกพิกัด',
                icon: const Icon(Icons.copy_outlined, size: 18),
                onPressed: location == null
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: coordinates),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('คัดลอกพิกัดแล้ว')),
                        );
                      },
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                tooltip: 'เกี่ยวกับพิกัดที่บันทึก',
                icon: const Icon(Icons.info_outline, size: 18),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('เกี่ยวกับพิกัด'),
                    content: const Text(
                      'พิกัดเป็นจุดที่บันทึก ไม่ใช่การติดตามสด • อุปกรณ์ที่ไม่ส่งพิกัดจะไม่มีหมุด',
                    ),
                    actions: [
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('ปิด'),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                tooltip: _expanded
                    ? 'ย่อรายละเอียดตำแหน่ง'
                    : 'ขยายรายละเอียดตำแหน่ง',
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: location == null
                    ? null
                    : () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
          if (_expanded && location != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: SelectableText(
                '$coordinates\nบันทึกเมื่อ ${location.capturedAt.toLocal().toIso8601String()} (เวลาท้องถิ่น)',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
