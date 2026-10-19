import 'package:flutter/material.dart';
import '../theme/rescue_theme.dart';
import 'relay_badge.dart';

enum ChatDeliveryState { pending, delivered, failed }

/// One visual shell and one status for text, SOS, and media messages.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.isMine,
    required this.time,
    required this.child,
    required this.status,
    this.route,
    this.peers = const {},
    this.onRetry,
    this.onLongPress,
  });
  final bool isMine;
  final String time;
  final Widget child;
  final ChatDeliveryState status;
  final List<String>? route;
  final Map<String, String> peers;
  final VoidCallback? onRetry, onLongPress;

  // White text, including the translucent relay badge, meets AA on this orange.
  static const outgoing = Color(0xFF9A3412);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = isMine ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final secondary = isMine ? Colors.white : RescueTheme.mutedFor(context);
    final hasRelay = route != null && route!.length > 2;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .75,
        ),
        child: IntrinsicWidth(
          child: GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMine
                    ? outgoing
                    : (dark ? RescueTheme.darkSurface : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isMine
                      ? outgoing
                      : (dark ? RescueTheme.darkBorder : RescueTheme.border),
                ),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(fontSize: 15, height: 1.35, color: ink),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    child,
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          time,
                          style: TextStyle(fontSize: 12, color: secondary),
                        ),
                        if (hasRelay) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: RelayBadge(
                              route: route,
                              peers: peers,
                              isMine: isMine,
                            ),
                          ),
                        ],
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          if (status == ChatDeliveryState.failed)
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: IconButton(
                                tooltip: 'ส่งใหม่',
                                onPressed: onRetry,
                                style: IconButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                icon: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: RescueTheme.orangeInk,
                                  ),
                                ),
                              ),
                            )
                          else
                            Tooltip(
                              message: status == ChatDeliveryState.delivered
                                  ? 'ส่งสำเร็จ'
                                  : 'รอส่งหรือกำลังลองใหม่',
                              child: Icon(
                                status == ChatDeliveryState.delivered
                                    ? Icons.done_all_rounded
                                    : Icons.schedule_rounded,
                                size: 14,
                                color: secondary,
                              ),
                            ),
                        ],
                      ],
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
