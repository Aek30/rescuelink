import 'package:flutter/material.dart';
import '../models/incoming_notice.dart';
import '../theme/rescue_theme.dart';

/// A compact floating notification; the underlying page keeps its position.
class InAppMessageBanner extends StatelessWidget {
  const InAppMessageBanner({
    super.key,
    required this.notice,
    required this.onOpen,
    required this.onClose,
  });
  final IncomingNotice notice;
  final VoidCallback onOpen, onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final sos = notice.sos != null;
    const red = Color(0xFFDC2638);
    final name = notice.name.trim().isEmpty ? 'ผู้ใช้ RescueLink' : notice.name;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, -36 * (1 - value)),
          child: child,
        ),
      ),
      child: Dismissible(
        key: ValueKey(notice.id),
        direction: DismissDirection.up,
        onDismissed: (_) => onClose(),
        child: Semantics(
          liveRegion: true,
          label: sos ? notice.title : 'ข้อความใหม่จาก $name',
          child: Material(
            color: dark ? const Color(0xFF202B38) : Colors.white,
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: sos
                                ? red.withValues(alpha: .12)
                                : RescueTheme.peach,
                            foregroundColor: sos ? red : RescueTheme.orangeInk,
                            child: sos
                                ? const Icon(Icons.sos_rounded, size: 30)
                                : Text(
                                    name.characters.first,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22,
                                    ),
                                  ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: sos ? red : const Color(0xFF168267),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: dark
                                      ? const Color(0xFF202B38)
                                      : Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                sos
                                    ? Icons.priority_high_rounded
                                    : Icons.chat_bubble_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sos ? notice.title : name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: sos
                                        ? red
                                        : theme.colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ตอนนี้',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notice.preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          if (sos)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: TextButton.icon(
                                onPressed: onOpen,
                                style: TextButton.styleFrom(
                                  foregroundColor: red,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: const Size(48, 40),
                                ),
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 17,
                                ),
                                label: const Text('ดู SOS'),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        tooltip: sos
                            ? 'ปิดแจ้งเตือน SOS'
                            : 'ปิดแจ้งเตือนข้อความ',
                        onPressed: onClose,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
