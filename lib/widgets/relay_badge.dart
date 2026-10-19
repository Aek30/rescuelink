import 'package:flutter/material.dart';

class RelayBadge extends StatelessWidget {
  const RelayBadge({
    super.key,
    required this.route,
    required this.peers,
    this.isMine = false,
  });
  final bool isMine;
  final List<String>? route;
  final Map<String, String> peers;

  @override
  Widget build(BuildContext context) {
    final path = route;
    final known = path != null && path.length >= 2;
    final relays = known ? path.length - 2 : 0;
    if (!known || relays == 0) return const SizedBox.shrink();
    final relayNames = known
        ? path
              .sublist(1, path.length - 1)
              .map((id) {
                final name = peers[id]?.trim();
                return name == null || name.isEmpty
                    ? 'เครื่องที่ไม่ทราบชื่อ'
                    : name;
              })
              .join(' → ')
        : '';
    final firstName = peers[path[1]]?.trim();
    final name = firstName == null || firstName.isEmpty ? 'ผู้ใช้' : firstName;
    final shortName = name.characters.length > 10
        ? '${name.characters.take(10)}…'
        : name;
    final ink = isMine
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 112,
        minHeight: 48,
        minWidth: 48,
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 48),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: isMine
                ? Colors.white.withValues(alpha: .2)
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.route_outlined, size: 13, color: ink),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  'ผ่าน $shortName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: ink),
                ),
              ),
            ],
          ),
        ),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'เส้นทางข้อความ',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (!known)
                    const Text(
                      'ยังไม่มีข้อมูลเส้นทางที่เครื่องนี้ได้รับ ระบบยังไม่ส่งข้อมูลเส้นทางกลับให้ผู้ส่ง',
                    ),
                  if (known) ...[
                    const Text(
                      'เส้นทางแรกที่ได้รับตามข้อมูลในแพ็กเก็ต ไม่ใช่ตำแหน่ง GPS หรือการยืนยันรับช่วยเหลือ',
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < path.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text(peers[path[i]] ?? 'เครื่องที่ไม่ทราบชื่อ'),
                        subtitle: Text(
                          '${i == 0
                              ? 'ต้นทาง'
                              : i == path.length - 1
                              ? 'ปลายทาง'
                              : 'เครื่องส่งต่อ'}\n${path[i]}',
                        ),
                      ),
                    Text(
                      relays == 0
                          ? 'ข้อความส่งจากต้นทางถึงปลายทางโดยตรง'
                          : 'ส่งผ่าน $relayNames ก่อนถึงปลายทาง',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
