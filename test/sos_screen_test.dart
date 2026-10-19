import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:rescuelink/models/message_model.dart';
import 'package:rescuelink/models/sos_alert.dart';
import 'package:rescuelink/screens/chat_screen.dart';
import 'package:rescuelink/screens/sos_screen.dart';
import 'package:rescuelink/screens/responder_screen.dart';
import 'package:rescuelink/services/message_service.dart';
import 'package:rescuelink/services/nearby_service.dart';
import 'package:rescuelink/services/local_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class UiSettings extends LocalDatabaseService {
  UiSettings(this.cachedLocation) : super(factory: databaseFactoryFfi);
  final SosLocation? cachedLocation;
  @override
  Future<String?> getSetting(String key) async =>
      key == 'sos.lastKnownLocation.v1' && cachedLocation != null
      ? jsonEncode(cachedLocation!.toMap())
      : null;
}

class NativeFake extends Fake implements Nearby {}

class UiTransport extends NearbyService {
  UiTransport() : super(nearby: NativeFake());
  @override
  Future<void> stopAll() async {}
}

class UiMessages extends MessageService {
  UiMessages({SosLocation? cachedLocation})
    : super(
        nearbyService: UiTransport(),
        database: UiSettings(cachedLocation),
      ) {
    myId = 'me';
    peers = {'peer': 'Phone B', 'other': 'Phone C'};
  }
  Set<String>? sentTo;
  SosLocation? sentLocation;
  List<EmergencyType>? sentCategories;
  String? sentDetails;
  @override
  Future<void> publishSos({
    required String name,
    required int people,
    required EmergencyType category,
    List<EmergencyType>? categories,
    required String details,
    required Set<String> recipients,
    SosLocation? location,
    bool active = true,
  }) async {
    sentTo = recipients;
    sentLocation = location;
    sentCategories = categories ?? [category];
    sentDetails = details;
  }
}

void main() {
  testWidgets(
    'cached coordinates are disclosed before confirmation and preserved on send',
    (tester) async {
      final cached = SosLocation(
        latitude: 14,
        longitude: 100,
        accuracy: 20,
        capturedAt: DateTime.utc(2026, 1, 1),
      );
      final service = UiMessages(cachedLocation: cached);
      addTearDown(() {
        service.dispose();
        service.nearbyService.dispose();
      });
      await tester.pumpWidget(MaterialApp(home: SosScreen(service: service)));
      await tester.tap(find.text('น้ำท่วม'));
      await tester.pumpAndSettle();
      final send = find.text('ส่ง SOS');
      await tester.scrollUntilVisible(
        send,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('ตำแหน่งเก่า'), findsWidgets);
      expect(service.sentTo, isNull);
      await tester.tap(find.text('ยืนยันส่ง SOS'));
      await tester.pumpAndSettle();
      expect(service.sentLocation?.capturedAt, cached.capturedAt);
      expect(service.sentLocation?.latitude, cached.latitude);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SOS can broadcast without recipients but requires confirmation',
    (tester) async {
      final service = UiMessages();
      addTearDown(() {
        service.dispose();
        service.nearbyService.dispose();
      });
      await tester.pumpWidget(MaterialApp(home: SosScreen(service: service)));
      await tester.tap(find.text('น้ำท่วม'));
      await tester.pumpAndSettle();
      final send = find.text('ส่ง SOS');
      await tester.scrollUntilVisible(
        send,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(service.sentTo, isNull);
      expect(find.text('ยืนยันข้อมูล SOS'), findsOneWidget);
      expect(service.sentTo, isNull);
      await tester.tap(find.text('ยืนยันส่ง SOS'));
      await tester.pumpAndSettle();
      expect(service.sentTo, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

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
    await tester.pumpWidget(
      MaterialApp(home: ResponderScreen(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('น้ำดื่ม'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.textContaining('3 คน'),
      ),
      findsOneWidget,
    );
    final chat = find.text('ติดต่อผู้แจ้งเหตุ');
    await tester.ensureVisible(chat);
    await tester.pumpAndSettle();
    await tester.tap(chat);
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Phone B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
