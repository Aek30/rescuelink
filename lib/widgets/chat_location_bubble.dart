import 'package:flutter/material.dart';
import '../models/offline_map_data.dart';
import '../models/sos_alert.dart';
import '../theme/rescue_theme.dart';
import 'bundled_offline_map.dart';
import 'location_button.dart';

class ChatLocationBubble extends StatelessWidget {
  const ChatLocationBubble({
    super.key,
    required this.location,
    required this.isMine,
  });
  final SosLocation location;
  final bool isMine;

  void _open(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ตำแหน่งที่แชร์',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              LocationButton(location: location),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ink =
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: MediaQuery.sizeOf(context).width * .65,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: ink, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ตำแหน่งที่แชร์',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: FutureBuilder<OfflineMapData>(
                  future: OfflineMapData.load(),
                  builder: (context, snapshot) =>
                      snapshot.hasData &&
                          snapshot.requireData.contains(location)
                      ? IgnorePointer(
                          child: BundledOfflineMap(
                            fullScreen: true,
                            compact: true,
                            showControls: false,
                            showOfflineBadge: false,
                            focus: location,
                            markers: [
                              OfflineMapMarker(
                                id: 'chat-location',
                                label: 'ตำแหน่งที่แชร์',
                                location: location,
                                color: RescueTheme.orangeInk,
                              ),
                            ],
                          ),
                        )
                      : ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          child: const Center(
                            child: Icon(
                              Icons.map_outlined,
                              size: 40,
                              color: RescueTheme.orangeInk,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
              style: TextStyle(fontSize: 12, color: ink),
            ),
            const SizedBox(height: 4),
            Text(
              'แตะเพื่อดูแผนที่และรายละเอียด',
              style: TextStyle(fontSize: 11, color: ink),
            ),
          ],
        ),
      ),
    );
  }
}
