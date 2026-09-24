import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/chat_screen.dart';
import 'package:rescuelink/screens/sos_screen.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:rescuelink/services/nearby_service.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class NativeFake extends Fake implements Nearby {}

class UiTransport extends NearbyService {
  UiTransport() : super(nearby: NativeFake());
  @override
  Future<void> stopAll() async {}
}

class UiMessages extends MessageService {
  UiMessages()
    : super(
        nearbyService: UiTransport(),
        database: LocalDatabaseService(factory: databaseFactoryFfi),
      ) {
    myId = 'me';
    peers = {'peer': 'Phone B', 'other': 'Phone C'};
  }
  Set<String>? sentTo;
  @override
  Future<void> publishSos({
    required String name,
    required int people,
    required EmergencyType category,
    required String details,
    required Set<String> recipients,
    SosLocation? location,
    bool active = true,
  }) async {
    sentTo = recipients;
  }
}

void main() {
  testWidgets('SOS requires a recipient and confirmation before sending', (
    tester,
  ) async {
    final service = UiMessages();
    addTearDown(() {
      service.dispose();
      service.nearbyService.dispose();
    });
    await tester.pumpWidget(MaterialApp(home: SosScreen(service: service)));
    final send = find.text('ตรวจข้อมูลและส่ง SOS');
    await tester.scrollUntilVisible(
      send,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(service.sentTo, isNull);
    await tester.ensureVisible(find.text('Phone B'));
    await tester.tap(find.text('Phone B'));
    await tester.pump();
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('ยืนยันข้อมูล SOS'), findsOneWidget);
    expect(service.sentTo, isNull);
    await tester.tap(find.text('ยืนยันส่ง SOS'));
    await tester.pumpAndSettle();
    expect(service.sentTo, {'peer'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rescue card displays SOS details and opens sender chat', (
    tester,
  ) async {
    final service = UiMessages()..rescueMode = true;
    addTearDown(() {
      service.dispose();
      service.nearbyService.dispose();
    });
    service.messages = [
      MessageModel(
        id: 'alert',
        senderId: 'peer',
        senderName: 'B',
        receiverId: 'me',
        timestamp: DateTime.utc(2026),
        type: MessageType.sos,
        text: SosAlert(
          incidentId: 'incident',
          revision: 1,
          active: true,
          name: 'B',
          people: 3,
          category: EmergencyType.supplies,
          details: 'น้ำดื่ม',
          updatedAt: DateTime.utc(2026),
        ).toJson(),
      ),
    ];
    await tester.pumpWidget(MaterialApp(home: SosScreen(service: service)));
    expect(find.textContaining('3 คน'), findsOneWidget);
    final chat = find.text('แชตกับผู้ขอความช่วยเหลือ');
    await tester.scrollUntilVisible(
      chat,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(chat);
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Phone B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
