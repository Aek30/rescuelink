import 'package:flutter/material.dart';
import '../models/sos_alert.dart';
import '../services/sos_location_service.dart';
import '../widgets/bundled_offline_map.dart';
import '../widgets/emergency_type_chip.dart';
import '../theme/rescue_theme.dart';

class ChatLocationPickerScreen extends StatefulWidget {
  const ChatLocationPickerScreen({super.key, required this.locationService});
  final SosLocationService locationService;
  @override
  State<ChatLocationPickerScreen> createState() =>
      _ChatLocationPickerScreenState();
}

class _ChatLocationPickerScreenState extends State<ChatLocationPickerScreen> {
  SosLocation? _selected;
  bool _reading = false, _pickedManually = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final cached = await widget.locationService.lastKnown();
    if (!mounted) return;
    if (!_pickedManually && cached != null) setState(() => _selected = cached);
    await _readGps();
  }

  Future<void> _readGps() async {
    if (_reading) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final fix = await widget.locationService.capture();
      if (mounted && !_pickedManually) setState(() => _selected = fix);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'อ่าน GPS ไม่สำเร็จ ลองใหม่หรือแตะเลือกจุดบนแผนที่ได้',
        );
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ส่งตำแหน่ง')),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text('แตะเลือกจุดบนแผนที่ หรือใช้ตำแหน่งปัจจุบันของคุณ'),
          ),
          Expanded(
            child: BundledOfflineMap(
              fullScreen: true,
              focus: _selected,
              onPickLocation: (location) => setState(() {
                _pickedManually = true;
                _selected = location;
                _error = null;
              }),
              markers: [
                if (_selected != null)
                  OfflineMapMarker(
                    id: 'selected',
                    label: 'ตำแหน่งที่จะส่ง',
                    location: _selected!,
                    color: RescueTheme.orangeInk,
                    isMe: true,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selected case final location?) ...[
                  Text(
                    sosCoordinates(location),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SosLocationStatusChip(location: location),
                  if (sosLocationStale(location)) const SosStaleWarning(),
                ] else
                  const Text('ยังไม่มีตำแหน่งที่เลือก'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _reading
                      ? null
                      : () {
                          _pickedManually = false;
                          _readGps();
                        },
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    _reading ? 'กำลังอ่าน GPS…' : 'ใช้ตำแหน่งปัจจุบัน',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.pop(context, _selected),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('ส่งตำแหน่งนี้'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
