import 'package:flutter/material.dart';
import '../services/nearby_service.dart';
import '../widgets/device_tile.dart';

class NearbyTestScreen extends StatefulWidget {
  const NearbyTestScreen({super.key});
  @override
  State<NearbyTestScreen> createState() => _NearbyTestScreenState();
}

class _NearbyTestScreenState extends State<NearbyTestScreen>
    with WidgetsBindingObserver {
  final _service = NearbyService();
  late final TextEditingController _name;
  final _message = TextEditingController(text: 'Hello from RescueLink');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _service.deviceName);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ignore inactive: permission dialogs cause it. No background service in POC.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _service.setForeground(false);
    } else if (state == AppLifecycleState.resumed) {
      _service.setForeground(true);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _service.setName(_name.text);
      await action();
    } catch (e) {
      _service.reportError('Operation failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    _name.dispose();
    _message.dispose();
    super.dispose();
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('RescueLink')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: _service,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Off-Grid Connection Test',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text(
              'Phase 1 • Physical Android phones • No internet required',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              enabled: !_busy && !_service.hasActivity,
              maxLength: 32,
              decoration: InputDecoration(
                labelText: 'Device Name',
                hintText: _service.deviceName,
              ),
            ),
            _heading('Permissions'),
            for (final item in _service.permissions.statuses.entries)
              Text('${item.key}: ${item.value}'),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await _service.checkPermissions();
                        }),
                  child: const Text('CHECK / REQUEST'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          if (!await _service.permissions.openSettings()) {
                            _service.reportError(
                              'Unable to open settings. Open Android Settings → Apps → RescueLink.',
                            );
                          }
                        }),
                  child: const Text('APP SETTINGS'),
                ),
              ],
            ),
            const Text(
              'Turn on Bluetooth, Wi-Fi radio and Location. Disable mobile data and disconnect Wi-Fi from internet networks for the offline test.',
            ),
            _heading('Connection Mode'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy || _service.isAdvertising
                      ? null
                      : () => _run(_service.startAdvertising),
                  child: const Text('START ADVERTISING'),
                ),
                FilledButton.tonal(
                  onPressed: _busy || _service.isDiscovering
                      ? null
                      : () => _run(_service.startDiscovery),
                  child: const Text('START DISCOVERY'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _run(_service.stopAll),
                  child: const Text('STOP'),
                ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            Text(
              'Advertising: ${_service.isAdvertising ? 'On' : 'Off'} • Discovery: ${_service.isDiscovering ? 'On' : 'Off'}',
            ),
            Text(_service.connectionStatus),
            if (_service.lastError != null)
              Text(
                _service.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const Text(
              'POC: connections auto-accept on both phones. Use only with your test devices. STOP disconnects all devices.',
            ),
            _heading('Nearby Devices'),
            if (_service.discoveredDevices.isEmpty)
              const Text(
                'No devices found. Start Advertising on the other phone.',
              ),
            for (final device in _service.discoveredDevices)
              DeviceTile(
                device: device,
                onPressed: _busy || !device.isAvailable
                    ? null
                    : () => _run(
                        () => _service.requestConnection(device.endpointId),
                      ),
              ),
            _heading('Connected Devices'),
            if (_service.connectedDevices.isEmpty)
              const Text('No connected devices'),
            for (final device in _service.connectedDevices)
              DeviceTile(
                device: device,
                onPressed: _busy
                    ? null
                    : () => _run(() => _service.disconnect(device.endpointId)),
              ),
            _heading('Offline Chat'),
            TextField(
              controller: _message,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      if (await _service.sendTextMessage(_message.text) &&
                          mounted) {
                        _message.clear();
                      }
                    }),
              icon: const Icon(Icons.send),
              label: const Text('SEND TO CONNECTED DEVICES'),
            ),
            _heading('Messages'),
            if (_service.messages.isEmpty) const Text('No messages yet'),
            for (final message in _service.messages.reversed)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(message),
                ),
              ),
            _heading('System Log'),
            const Text(
              'Latest first • Last 200 entries • Cleared when app closes',
            ),
            for (final log in _service.logs.reversed)
              SelectableText(log, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}
