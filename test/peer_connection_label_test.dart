import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuelink/models/peer_presence.dart';
import 'package:rescuelink/theme/rescue_theme.dart';
import 'package:rescuelink/widgets/presence_peer_card.dart';
import 'sos_screen_test.dart' show UiMessages;

class _RouteMessages extends UiMessages {
  List<String> path = ['me', 'peer'];
  @override
  bool isReachable(String peerId) => true;
  @override
  String? relayViaName(String peerId) => path.length > 2 ? 'นนท์' : null;
  @override
  List<String>? relayPathForPeer(String peerId) => path;
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('route is readable on a narrow card, dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _RouteMessages();
      addTearDown(() {
        service.dispose();
        service.nearbyService.dispose();
      });
      final state = PeerPresence(
        sequence: 1,
        rescue: false,
        receivedAt: DateTime.now().toUtc(),
      );
      for (final hops in [0, 1, 2]) {
        service.path = ['me', for (var i = 0; i < hops; i++) 'relay$i', 'peer'];
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? RescueTheme.dark : RescueTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: PresencePeerCard(
                  service: service,
                  peerId: 'peer',
                  state: state,
                  showRole: true,
                  grouped: true,
                ),
              ),
            ),
          ),
        );
        expect(
          find.text(switch (hops) {
            0 => 'เชื่อมต่อโดยตรง',
            1 => 'เชื่อมต่อผ่าน นนท์',
            _ => 'เชื่อมต่อผ่าน นนท์ · รวม 2 เครื่องกลาง',
          }),
          findsOneWidget,
        );
        expect(find.byTooltip('ส่งข้อความ'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
