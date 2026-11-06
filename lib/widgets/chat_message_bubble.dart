import 'package:flutter/material.dart';
import 'relay_badge.dart';
import '../theme/rescue_theme.dart';

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
    this.isMedia = false,
  });
  final bool isMine;
  final bool isMedia;
  final String time;
  final Widget child;
  final ChatDeliveryState status;
  final List<String>? route;
  final Map<String, String> peers;
  final VoidCallback? onRetry, onLongPress;

  static const outgoing = Color(0xFF9A3412);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = isMine ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final secondary = RescueTheme.mutedFor(context);
    final hasRelay = route != null && route!.length > 2;
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .75,
      ),
      child: IntrinsicWidth(
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            padding: isMedia
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: isMedia
                ? null
                : BoxDecoration(
                    color: isMine
                        ? outgoing
                        : (dark ? RescueTheme.darkSurface : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isMine
                          ? outgoing
                          : (dark
                                ? RescueTheme.darkBorder
                                : RescueTheme.border),
                    ),
                  ),
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 16, height: 1.35, color: ink),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  child,
                  if (hasRelay) ...[
                    const SizedBox(height: 4),
                    RelayBadge(
                      route: route,
                      peers: peers,
                      isMine: isMine && !isMedia,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final metadata = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMine)
            if (status == ChatDeliveryState.failed)
              IconButton(
                tooltip: 'ส่งใหม่',
                onPressed: onRetry,
                icon: Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
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
          Text(time, style: TextStyle(fontSize: 11, color: secondary)),
        ],
      ),
    );
    return Row(
      mainAxisAlignment: isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isMine) metadata,
        Flexible(child: bubble),
        if (!isMine) metadata,
      ],
    );
  }
}
