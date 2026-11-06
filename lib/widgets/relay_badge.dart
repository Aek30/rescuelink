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
    final firstName = peers[path[1]]?.trim();
    final name = firstName == null || firstName.isEmpty ? 'ผู้ใช้' : firstName;
    final ink = isMine
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 200,
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
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isMine
                ? Colors.white.withValues(alpha: .14)
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alt_route_rounded, size: 13, color: ink),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  relays > 1 ? 'ผ่าน $name · +${relays - 1}' : 'ผ่าน $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) {
            final colors = Theme.of(context).colorScheme;
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'เส้นทางข้อความ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'ปิด',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    Text(
                      'ข้อความนี้ส่งผ่าน $relays เครื่องก่อนถึงผู้รับ',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < path.length; i++) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: colors.secondaryContainer,
                              foregroundColor: colors.onSecondaryContainer,
                              child: Icon(
                                i == 0
                                    ? Icons.send_rounded
                                    : i == path.length - 1
                                    ? Icons.mark_chat_read_outlined
                                    : Icons.alt_route_rounded,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    i == 0
                                        ? 'ผู้ส่ง'
                                        : i == path.length - 1
                                        ? 'ผู้รับ'
                                        : 'เครื่องส่งต่อที่ $i',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    peers[path[i]]?.trim().isNotEmpty == true
                                        ? peers[path[i]]!.trim()
                                        : 'เครื่องที่ไม่ทราบชื่อ',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < path.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 24),
                          child: Icon(
                            Icons.south_rounded,
                            size: 24,
                            color: colors.outline,
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'แสดงเส้นทางที่ข้อความเดินทางมาถึงครั้งแรก',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
