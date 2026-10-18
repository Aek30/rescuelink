import 'package:flutter/material.dart';
import '../models/sos_alert.dart';
import '../services/message_service.dart';
import '../services/sos_location_service.dart';
import '../screens/incident_detail_screen.dart';
import 'bundled_offline_map.dart';

class NearbyMiniMap extends StatefulWidget {
  const NearbyMiniMap({super.key, required this.service, this.capture});
  final MessageService service;
  final Future<SosLocation> Function()? capture;
  @override
  State<NearbyMiniMap> createState() => _NearbyMiniMapState();
}

class _NearbyMiniMapState extends State<NearbyMiniMap> {
  SosLocation? _me;
  bool _loading = false;
  String? _error;

  Future<void> _locate({bool share = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fix =
          await (widget.capture?.call() ??
              SosLocationService(database: widget.service.database).capture());
      if (!mounted) return;
      setState(() => _me = fix);
      if (share) await widget.service.shareRescueLocation(fix);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'อ่านหรือแชร์ตำแหน่งไม่ได้ ตรวจสิทธิ์/GPS และโหมดกู้ภัย แล้วลองใหม่',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(String id) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => IncidentDetailScreen(service: widget.service, peerId: id),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final points = widget.service.presence.entries
          .where((e) => e.value.mapLocation != null)
          .toList();
      final now = DateTime.now().toUtc();
      final me =
          _me ??
          widget.service.rescueLocation ??
          widget.service.mySos?.location;
      return Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'แผนที่รอบตัว',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text('มีพิกัด ${points.length} เครื่อง • ใช้ได้ออฟไลน์'),
                ],
              ),
            ),
            BundledOfflineMap(
              focus: me,
              markers: [
                for (final e in points)
                  OfflineMapMarker(
                    id: e.key,
                    label:
                        '${widget.service.peers[e.key] ?? 'ไม่ทราบชื่อ'} • แตะดูรายละเอียด',
                    location: e.value.mapLocation!,
                    color: !e.value.isFresh(now)
                        ? Colors.grey
                        : e.value.sos?.isActiveAt(now) == true
                        ? const Color(0xFFC83D32)
                        : e.value.rescue
                        ? Colors.blue
                        : Colors.grey,
                    onTap: () => _open(e.key),
                  ),
                if (me != null)
                  OfflineMapMarker(
                    id: 'self',
                    label: 'ฉัน • พิกัดที่อ่านล่าสุด',
                    location: me,
                    color: const Color(0xFF167A65),
                    isMe: true,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'เขียว: ฉัน  •  แดง: SOS  •  น้ำเงิน: กู้ภัย\nเทา: สถานะเก่า/ปิดแล้ว',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'อุปกรณ์ที่ไม่ส่งพิกัดจะไม่มีหมุด • พิกัดเป็นจุดที่บันทึก ไม่ใช่การติดตามสด',
                    style: TextStyle(fontSize: 11),
                  ),
                  if (me == null)
                    const Text(
                      'ยังไม่มีพิกัดของคุณ • กด “ตำแหน่งของฉัน” เพื่ออ่าน GPS',
                    ),
                  if (me != null)
                    Text(
                      'ฉัน: ${me.latitude.toStringAsFixed(5)}, ${me.longitude.toStringAsFixed(5)}\n±${me.accuracy.round()} ม. • บันทึก ${me.capturedAt.toLocal()}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => _locate(),
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      _loading
                          ? 'กำลังอ่าน GPS…'
                          : me == null
                          ? 'ตำแหน่งของฉัน'
                          : 'อัปเดตตำแหน่งของฉัน',
                    ),
                  ),
                  if (widget.service.rescueMode) ...[
                    const Text(
                      'แชร์พิกัดกู้ภัยให้เครื่องในเครือข่ายเห็นเป็นหมุดสีน้ำเงิน',
                      style: TextStyle(fontSize: 12),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : () => _locate(share: true),
                      icon: const Icon(Icons.share_location),
                      label: const Text('อ่าน GPS และแชร์พิกัดกู้ภัย'),
                    ),
                    if (widget.service.rescueLocation != null)
                      TextButton(
                        onPressed: widget.service.clearRescueLocation,
                        child: const Text('หยุดแชร์พิกัดกู้ภัย'),
                      ),
                  ],
                  for (final e in points)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(
                        widget.service.peers[e.key] ?? 'เครื่องที่ไม่ทราบชื่อ',
                      ),
                      subtitle: Text(
                        '${e.value.isFresh(now) ? 'สถานะล่าสุด' : 'สถานะหมดอายุ'} • พิกัดบันทึก ${e.value.mapLocation!.capturedAt.toLocal()}\n${e.value.mapLocation!.latitude.toStringAsFixed(6)}, ${e.value.mapLocation!.longitude.toStringAsFixed(6)}',
                      ),
                      onTap: () => _open(e.key),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
