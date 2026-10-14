# RescueLink — สารบัญไฟล์และการเชื่อมต่อ

วันที่ตรวจ: 10 ตุลาคม 2026. อ่าน [คำอธิบายระบบและฐานข้อมูล](APP_SYSTEM_EXPLAINED_TH.md) ก่อนเพื่อเข้าใจ flow.

ครอบคลุมไฟล์ source/config/test/docs/assets/platform ที่ Git ติดตามหรือยังไม่ถูก ignore ณ รอบตรวจ ไม่ไล่ไฟล์ cache/build/.git/dependency/tmp ทีละไฟล์ เพราะเป็นผลสร้าง/เครื่องมือ ไม่ใช่ฟีเจอร์เพิ่มของแอพ. ไฟล์ config เฉพาะเครื่องกล่าวถึงท้ายเอกสารโดยไม่แสดง key.

## ไฟล์ Dart ทุกไฟล์ (62 ไฟล์)

ชื่อเมธอดด้านล่างเป็นดัชนีจาก declaration ที่ตรวจพบ พร้อมเลขบรรทัดสำหรับเปิดโค้ด (เมธอดหลายบรรทัด/constructor อาจไม่ติดดัชนี) คำอธิบายหน้าที่ครอบคลุมระดับไฟล์และฟีเจอร์; build สร้าง UI, initState เริ่ม lifecycle, dispose คืนทรัพยากร ส่วน _build... เป็นส่วนย่อยของหน้าจอ.

### [lib/l10n/app_strings.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/l10n/app_strings.dart)

แผนที่คำไทย→อังกฤษที่ AppPreferences.text ใช้ มี fallback เป็นไทย

- คลาส/enum: ไม่มี (ใช้ฟังก์ชันหรือค่าระดับไฟล์)
- เชื่อมไฟล์ในแอพ: ไม่มี relative import
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/services/app_preferences.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/app_preferences.dart)

### [lib/main.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/main.dart)

จุดเริ่มแอพ ตั้งฐานข้อมูล กู้บัญชี โหลดธีม เริ่ม SOS/Chat sync แล้วเลือก Onboarding หรือหน้าหลัก

- คลาส/enum: `RescueLinkApp`, `_StartupScreen`, `_StartupScreenState`
- เชื่อมไฟล์ในแอพ: [lib/screens/onboarding_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/onboarding_screen.dart), [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart), [lib/services/app_preferences.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/app_preferences.dart), [lib/services/platform_database.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/platform_database.dart), [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/services/sos_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_sync_service.dart), [lib/services/chat_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/chat_sync_service.dart), [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/screens/login_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/login_screen.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: ไม่มีภายใน lib (อาจเป็น entrypoint/conditional target/ไฟล์ที่ยังไม่เชื่อม)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `main` (บรรทัด 12), `build` (บรรทัด 23), `initState` (บรรทัด 49), `build` (บรรทัด 59)

### [lib/models/incoming_notice.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/incoming_notice.dart)

ข้อมูล notification ข้อความหรือ SOS พร้อม peerId และแปลง map สำหรับ native channel

- คลาส/enum: `IncomingNotice`
- เชื่อมไฟล์ในแอพ: [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/services/connection_session.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/connection_session.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `toMap` (บรรทัด 14)

### [lib/models/media_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/media_model.dart)

MediaFile metadata/status/progress/hash/path, mediaInit และ MediaAck

- คลาส/enum: `MediaStatus`, `MediaFile`, `MediaAck`
- เชื่อมไฟล์ในแอพ: ไม่มี relative import
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/services/media_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_service.dart), [lib/services/media_upload_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_upload_service.dart), [lib/widgets/media_bubble.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/media_bubble.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `toMap` (บรรทัด 86), `toInitJson` (บรรทัด 124), `toJson` (บรรทัด 175)

### [lib/models/message_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/message_model.dart)

envelope MessageModel; ประเภท message/ack/sos/deviceInfo/presence/media; สถานะ pending/sent/delivered/synced; encode/decode/validation

- คลาส/enum: `MessageStatus`, `MessageType`, `MessageModel`
- เชื่อมไฟล์ในแอพ: ไม่มี relative import
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/models/relay_packet.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/relay_packet.dart), [lib/screens/chat_history_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_history_screen.dart), [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart), [lib/screens/messages_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/messages_screen.dart), [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/screens/sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sos_screen.dart), [lib/services/chat_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/chat_store.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/services/media_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_service.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart), [lib/widgets/outbox_queue.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/outbox_queue.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `toMap` (บรรทัด 49), `toJson` (บรรทัด 83)

### [lib/models/nearby_device.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/nearby_device.dart)

ข้อมูลเครื่องที่ค้นพบ endpointId ชื่อ connected/connecting/available

- คลาส/enum: `NearbyDevice`
- เชื่อมไฟล์ในแอพ: ไม่มี relative import
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/services/nearby_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/nearby_service.dart), [lib/widgets/device_tile.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/device_tile.dart)

### [lib/models/peer_advertisement.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/peer_advertisement.dart)

directory entry พร้อม path และอายุสะสม เก็บได้ 48 ชั่วโมง ตรวจ route/sequence ป้องกัน replay ต่ออายุ

- คลาส/enum: `PeerAdvertisement`
- เชื่อมไฟล์ในแอพ: [lib/models/peer_presence.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/peer_presence.dart), [lib/models/relay_packet.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/relay_packet.dart), [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `toWire` (บรรทัด 21), `toStored` (บรรทัด 81)

### [lib/models/peer_presence.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/peer_presence.dart)

สถานะ rescue/SOS และ sequence เวลาได้รับ; ความสด 30 วินาที

- คลาส/enum: `PeerPresence`
- เชื่อมไฟล์ในแอพ: [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/models/peer_advertisement.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/peer_advertisement.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart), [lib/widgets/device_tile.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/device_tile.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `isFresh` (บรรทัด 15), `encode` (บรรทัด 17)

### [lib/models/relay_packet.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/relay_packet.dart)

ห่อ MessageModel ด้วย relayVersion/path/ACK return route ตรวจ loop และ maxHops=8

- คลาส/enum: `RelayPacket`
- เชื่อมไฟล์ในแอพ: [lib/models/message_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/message_model.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/models/peer_advertisement.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/peer_advertisement.dart), [lib/services/media_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_service.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `toJson` (บรรทัด 15)

### [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart)

EmergencyType, SosLocation, SosAlert ตรวจจำนวนคน/พิกัด/ความยาว อายุ SOS 24 ชั่วโมง และ JSON

- คลาส/enum: `EmergencyType`, `SosLocation`, `SosAlert`
- เชื่อมไฟล์ในแอพ: ไม่มี relative import
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/models/incoming_notice.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/incoming_notice.dart), [lib/models/peer_advertisement.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/peer_advertisement.dart), [lib/models/peer_presence.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/peer_presence.dart), [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart), [lib/screens/messages_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/messages_screen.dart), [lib/screens/my_sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/my_sos_screen.dart), [lib/screens/responder_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/responder_screen.dart), [lib/screens/sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sos_screen.dart), [lib/screens/sync_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sync_screen.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart), [lib/services/responder_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/responder_store.dart), [lib/services/sos_location_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_location_service.dart), [lib/services/sos_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_store.dart), [lib/widgets/location_button.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/location_button.dart), [lib/widgets/nearby_mini_map.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/nearby_mini_map.dart), [lib/widgets/offline_location_map.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/offline_location_map.dart), [lib/widgets/outbox_queue.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/outbox_queue.dart), [lib/widgets/sos_radar.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/sos_radar.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `toMap` (บรรทัด 31), `isExpired` (บรรทัด 80), `isActiveAt` (บรรทัด 81), `toJson` (บรรทัด 82)

### [lib/screens/chat_history_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_history_screen.dart)

ประวัติข้อความส่วนตัวสำหรับ Cloud อ่าน แก้ ลบ ซิงก์ และเลือกแก้ conflict โดยไม่เปลี่ยน packet ที่ส่งไปแล้ว

- คลาส/enum: `ChatHistoryScreen`, `_ChatHistoryScreenState`
- เชื่อมไฟล์ในแอพ: [lib/models/message_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/message_model.dart), [lib/services/chat_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/chat_sync_service.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/member_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/member_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `_action` (บรรทัด 16), `_edit` (บรรทัด 30), `_delete` (บรรทัด 57), `build` (บรรทัด 83)

### [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart)

ห้องแชต ส่งข้อความ/ภาพ/วิดีโอ แสดงสถานะ ACK พิกัด relay และคำสั่ง Upload/ดูสื่อ Cloud

- คลาส/enum: `ChatScreen`, `_ChatScreenState`
- เชื่อมไฟล์ในแอพ: [lib/services/media_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_service.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart), [lib/services/connection_session.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/connection_session.dart), [lib/models/message_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/message_model.dart), [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/widgets/location_button.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/location_button.dart), [lib/widgets/media_bubble.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/media_bubble.dart), [lib/services/media_upload_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_upload_service.dart), [lib/models/media_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/media_model.dart), [lib/widgets/relay_badge.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/relay_badge.dart), [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/incident_detail_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/incident_detail_screen.dart), [lib/screens/messages_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/messages_screen.dart), [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/screens/responder_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/responder_screen.dart), [lib/widgets/presence_list.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/presence_list.dart), [lib/widgets/sos_radar.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/sos_radar.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `initState` (บรรทัด 36), `didChangeAppLifecycleState` (บรรทัด 42), `dispose` (บรรทัด 47), `_send` (บรรทัด 53), `_sendMedia` (บรรทัด 74), `_mediaAction` (บรรทัด 96), `_buildStatusIndicator` (บรรทัด 108), `_mediaActions` (บรรทัด 174), `build` (บรรทัด 246)

### [lib/screens/demo_features_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/demo_features_screen.dart)

หน้าจำลอง account/sync/media ใช้ state ใน RAM ไม่ส่งข้อมูลจริง ไม่พบ route เปิดจากหน้าหลักปัจจุบัน

- คลาส/enum: `DemoFeaturesScreen`, `_DemoFeaturesScreenState`
- เชื่อมไฟล์ในแอพ: [lib/widgets/brand_header.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/brand_header.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: ไม่มีภายใน lib (อาจเป็น entrypoint/conditional target/ไฟล์ที่ยังไม่เชื่อม)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `_sync` (บรรทัด 21), `build` (บรรทัด 39)

### [lib/screens/emergency_profile_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/emergency_profile_screen.dart)

ฟอร์มข้อมูลส่วนตัวและสุขภาพ อ่าน/บันทึก offline pending และถอนความยินยอม

- คลาส/enum: `EmergencyProfileScreen`, `_EmergencyProfileScreenState`
- เชื่อมไฟล์ในแอพ: [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/services/emergency_profile_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/emergency_profile_service.dart), [lib/services/emergency_profile_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/emergency_profile_store.dart), [lib/widgets/privacy_notice.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/privacy_notice.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/member_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/member_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `initState` (บรรทัด 44), `dispose` (บรรทัด 53), `_apply` (บรรทัด 60), `_run` (บรรทัด 80), `_save` (บรรทัด 101), `_delete` (บรรทัด 120), `_field` (บรรทัด 146), `build` (บรรทัด 177)

### [lib/screens/forgot_password_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/forgot_password_screen.dart)

ส่ง recovery email ตรวจรหัส/token ตั้งรหัสผ่านใหม่ แล้วคืนอีเมลให้ Login

- คลาส/enum: `_ResetStep`, `ForgotPasswordScreen`, `_ForgotPasswordScreenState`
- เชื่อมไฟล์ในแอพ: [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/login_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/login_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `t` (บรรทัด 40), `initState` (บรรทัด 43), `dispose` (บรรทัด 51), `_handleSendOtp` (บรรทัด 59), `_handleResetPassword` (บรรทัด 121), `_validatePassword` (บรรทัด 205), `build` (บรรทัด 225), `_buildRequestOtpForm` (บรรทัด 375), `_buildVerifyAndResetForm` (บรรทัด 457)

### [lib/screens/incident_detail_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/incident_detail_screen.dart)

อ่านข้อมูลเหตุจาก peer/presence แสดงรายละเอียด/พิกัดและเปิดแชตกับเจ้าของเหตุ

- คลาส/enum: `IncidentDetailScreen`
- เชื่อมไฟล์ในแอพ: [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart), [lib/widgets/location_button.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/location_button.dart), [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart), [lib/widgets/brand_header.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/brand_header.dart), [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/widgets/nearby_mini_map.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/nearby_mini_map.dart), [lib/widgets/presence_list.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/presence_list.dart), [lib/widgets/sos_radar.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/sos_radar.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `build` (บรรทัด 18)

### [lib/screens/login_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/login_screen.dart)

ฟอร์มเข้าสู่ระบบ เปิดสมัคร/ลืมรหัสผ่าน และพาเข้าหน้าหลักเมื่อสำเร็จ

- คลาส/enum: `LoginScreen`, `_LoginScreenState`
- เชื่อมไฟล์ในแอพ: [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/screens/forgot_password_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/forgot_password_screen.dart), [lib/screens/register_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/register_screen.dart), [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/main.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/main.dart), [lib/screens/member_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/member_screen.dart), [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/screens/onboarding_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/onboarding_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `t` (บรรทัด 25), `initState` (บรรทัด 28), `dispose` (บรรทัด 34), `submit` (บรรทัด 40), `_openForgotPassword` (บรรทัด 82), `_openRegister` (บรรทัด 104), `_emailField` (บรรทัด 119), `_passwordField` (บรรทัด 183), `build` (บรรทัด 249)

### [lib/screens/member_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/member_screen.dart)

ข้อมูลบัญชี ชื่อ cache/ร่าง/ชื่อ Cloud แก้ชื่อ เปิดสุขภาพ/ประวัติ/ซิงก์ ออกจากระบบและยืนยันลบบัญชี

- คลาส/enum: `MemberScreen`, `_MemberScreenState`
- เชื่อมไฟล์ในแอพ: [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/services/member_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/member_service.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/services/app_preferences.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/app_preferences.dart), [lib/services/sos_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_sync_service.dart), [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart), [lib/widgets/rescue_ui.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/rescue_ui.dart), [lib/screens/login_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/login_screen.dart), [lib/screens/chat_history_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_history_screen.dart), [lib/screens/emergency_profile_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/emergency_profile_screen.dart), [lib/screens/sync_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sync_screen.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/settings_panel.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/settings_panel.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `t` (บรรทัด 24), `initState` (บรรทัด 33), `dispose` (บรรทัด 41), `_run` (บรรทัด 46), `_load` (บรรทัด 62), `_save` (บรรทัด 101), `_login` (บรรทัด 123), `_signOut` (บรรทัด 131), `_delete` (บรรทัด 165), `build` (บรรทัด 219), `_buildSecurityGroup` (บรรทัด 549), `_syncTile` (บรรทัด 572)

### [lib/screens/messages_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/messages_screen.dart)

รวมบทสนทนา เรียงล่าสุด ค้นหา กรองยังไม่อ่าน แสดง preview และเปิดห้องแชต

- คลาส/enum: `MessagesScreen`, `_MessagesScreenState`
- เชื่อมไฟล์ในแอพ: [lib/models/message_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/message_model.dart), [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart), [lib/services/app_preferences.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/app_preferences.dart), [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `_formatTime` (บรรทัด 24), `_messagePreview` (บรรทัด 45), `build` (บรรทัด 64)

### [lib/screens/my_sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/my_sos_screen.dart)

รายการ SOS ของตนเองจาก SosStore แก้ไข/ลบประวัติที่ยุติแล้ว และเปิดหน้าซิงก์

- คลาส/enum: `MySosScreen`, `_MySosScreenState`
- เชื่อมไฟล์ในแอพ: [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/services/sos_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_store.dart), [lib/services/sos_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_sync_service.dart), [lib/screens/sync_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sync_screen.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sos_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `initState` (บรรทัด 20), `_load` (บรรทัด 25), `_edit` (บรรทัด 41), `build` (บรรทัด 173)

### [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart)

หน้าหลักจริงของแอพ ประกอบบริการ Nearby/ข้อความ/สื่อ เมนู 5 แท็บ รายชื่อเครื่อง การแจ้งเตือน และการกลับเข้าแอพ

- คลาส/enum: `NearbyTestScreen`, `_NearbyTestScreenState`, `_Palette`, `_RescueLogo`, `_SectionCard`, `_SectionTitle`, `_StatusChip`, `_PermissionRow`, `_ModeCard`, `_InfoState`
- เชื่อมไฟล์ในแอพ: [lib/screens/messages_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/messages_screen.dart), [lib/screens/responder_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/responder_screen.dart), [lib/services/app_preferences.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/app_preferences.dart), [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/models/message_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/message_model.dart), [lib/models/incoming_notice.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/incoming_notice.dart), [lib/widgets/location_button.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/location_button.dart), [lib/screens/settings_panel.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/settings_panel.dart), [lib/screens/login_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/login_screen.dart), [lib/services/nearby_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/nearby_service.dart), [lib/services/media_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_service.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/services/permission_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/permission_service.dart), [lib/widgets/presence_list.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/presence_list.dart), [lib/widgets/nearby_mini_map.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/nearby_mini_map.dart), [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart), [lib/screens/sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sos_screen.dart), [lib/widgets/outbox_queue.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/outbox_queue.dart), [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart), [lib/services/member_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/member_service.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/main.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/main.dart), [lib/screens/login_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/login_screen.dart), [lib/screens/register_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/register_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `initState` (บรรทัด 62), `_profileNameChanged` (บรรทัด 127), `_accountChanged` (บรรทัด 135), `_receiveNotice` (บรรทัด 155), `_showNextNotice` (บรรทัด 169), `_dismissNotice` (บรรทัด 206), `_openChat` (บรรทัด 214), `_openNotice` (บรรทัด 227), `didChangeAppLifecycleState` (บรรทัด 275), `_run` (บรรทัด 292), `_openSettings` (บรรทัด 322), `_permissionIsReady` (บรรทัด 338), `_permissionNameThai` (บรรทัด 352), `_permissionStatusThai` (บรรทัด 378), `dispose` (บรรทัด 451), `build` (บรรทัด 471), `_buildSettingsTab` (บรรทัด 564), `_buildHomeTab` (บรรทัด 620), `_buildHeroCard` (บรรทัด 662), `_openConnectionSettings` (บรรทัด 1023), `_buildQueue` (บรรทัด 1052), `_buildDeviceName` (บรรทัด 1063), `_buildPermissionCard` (บรรทัด 1108), `_buildConnectionMode` (บรรทัด 1198), `_buildOfflineInfo` (บรรทัด 1277), `_buildErrorCard` (บรรทัด 1320), `build` (บรรทัด 1384), `build` (บรรทัด 1407), `build` (บรรทัด 1432), `build` (บรรทัด 1478), `build` (บรรทัด 1509), `build` (บรรทัด 1556), `build` (บรรทัด 1641)

### [lib/screens/onboarding_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/onboarding_screen.dart)

หน้าต้อนรับ/แนะนำ Nearby และ SOS แล้วพาไป Login

- คลาส/enum: `OnboardingScreen`, `_OnboardingScreenState`
- เชื่อมไฟล์ในแอพ: [lib/screens/login_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/login_screen.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/main.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/main.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `dispose` (บรรทัด 21), `_login` (บรรทัด 26), `_next` (บรรทัด 30), `_button` (บรรทัด 41), `_dots` (บรรทัด 76), `_feature` (บรรทัด 114), `_welcome` (บรรทัด 132), `_explanation` (บรรทัด 263), `build` (บรรทัด 516)

### [lib/screens/register_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/register_screen.dart)

สมัครสมาชิกหลายขั้น เก็บข้อมูลทั่วไป/ความยินยอมและสุขภาพ แสดง dialog ยืนยันอีเมล/ส่งซ้ำ

- คลาส/enum: `EmailVerificationDialog`, `_EmailVerificationDialogState`, `RegisterScreen`, `_RegisterScreenState`
- เชื่อมไฟล์ในแอพ: [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/services/emergency_profile_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/emergency_profile_store.dart), [lib/widgets/privacy_notice.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/privacy_notice.dart), [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/login_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/login_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `_maskEmail` (บรรทัด 16), `show` (บรรทัด 41), `dispose` (บรรทัด 65), `_startCooldown` (บรรทัด 70), `_resend` (บรรทัด 84), `build` (บรรทัด 121), `dispose` (บรรทัด 350), `_next` (บรรทัด 367), `_back` (บรรทัด 380), `_submit` (บรรทัด 388), `_pickDob` (บรรทัด 470), `_sectionLabel` (บรรทัด 519), `_buildStep0` (บรรทัด 543), `_buildStep1` (บรรทัด 640), `_buildDobPicker` (บรรทัด 692), `_buildStep2` (บรรทัด 745), `_buildBloodGroupChips` (บรรทัด 871), `_buildRhChips` (บรรทัด 883), `_chipGroup` (บรรทัด 895), `_buildConsentSection` (บรรทัด 945), `_consentRow` (บรรทัด 1000), `_progressBar` (บรรทัด 1034), `build` (บรรทัด 1088)

### [lib/screens/responder_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/responder_screen.dart)

รายการเหตุสำหรับผู้ช่วยเหลือ กรองสถานะ รับเคส บันทึกกำลังช่วย/เสร็จสิ้นผ่าน ResponderStore ในเครื่อง

- คลาส/enum: `ResponderScreen`, `_RescuePalette`, `_StageAppearance`, `_ResponderScreenState`, `_SurfaceCard`, `_StageChip`, `_DetailRow`, `_SectionCaption`, `_MetricCard`, `_FilterChip`, `_IncidentCard`, `_EmptyIncidents`, `_ErrorBanner`
- เชื่อมไฟล์ในแอพ: [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/services/app_preferences.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/app_preferences.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart), [lib/services/responder_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/responder_store.dart), [lib/widgets/location_button.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/location_button.dart), [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `t` (บรรทัด 60), `tr` (บรรทัด 62), `initState` (บรรทัด 91), `dispose` (บรรทัด 99), `_localeChanged` (บรรทัด 105), `_refresh` (บรรทัด 109), `_run` (บรรทัด 141), `_toggleRescueMode` (บรรทัด 157), `_stageFor` (บรรทัด 174), `_filterLabel` (บรรทัด 212), `_formatDate` (บรรทัด 221), `_locationLabel` (บรรทัด 228), `_detail` (บรรทัด 231), `build` (บรรทัด 532), `_buildRescueToggle` (บรรทัด 751), `build` (บรรทัด 900), `build` (บรรทัด 916), `build` (บรรทัด 951), `build` (บรรทัด 988), `build` (บรรทัด 1018), `build` (บรรทัด 1067), `build` (บรรทัด 1114), `build` (บรรทัด 1258), `build` (บรรทัด 1312)

### [lib/screens/settings_panel.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/settings_panel.dart)

หน้าฉัน เมนูสมาชิก/ผู้ช่วยเหลือ ตั้งภาษา ธีม แจ้งเตือน ชื่อเครื่อง การเชื่อมต่อและออกจากระบบ

- คลาส/enum: `SettingsPanel`
- เชื่อมไฟล์ในแอพ: [lib/services/app_preferences.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/app_preferences.dart), [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/screens/member_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/member_screen.dart), [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `build` (บรรทัด 29)

### [lib/screens/sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sos_screen.dart)

สร้าง/แก้ไข/ยกเลิก SOS ขอ GPS เลือกประเภทเหตุ จำนวนคน รายละเอียด และเปิดประวัติ SOS

- คลาส/enum: `SosScreen`, `_SosScreenState`
- เชื่อมไฟล์ในแอพ: [lib/services/app_preferences.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/app_preferences.dart), [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart), [lib/models/message_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/message_model.dart), [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart), [lib/services/sos_location_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_location_service.dart), [lib/widgets/location_button.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/location_button.dart), [lib/services/sos_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_store.dart), [lib/screens/my_sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/my_sos_screen.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `t` (บรรทัด 22), `initState` (บรรทัด 41), `dispose` (บรรทัด 62), `_run` (บรรทัด 69), `_send` (บรรทัด 84), `_cancel` (บรรทัด 125), `_section` (บรรทัด 202), `_categoryPicker` (บรรทัด 264), `_readLocation` (บรรทัด 383), `build` (บรรทัด 394)

### [lib/screens/sync_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sync_screen.dart)

หน้าคิว Cloud ของ SOS แสดง pending/error/conflicts กด sync และเลือกใช้ local หรือ remote

- คลาส/enum: `SyncScreen`, `_SyncScreenState`
- เชื่อมไฟล์ในแอพ: [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/services/sos_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_store.dart), [lib/services/sos_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_sync_service.dart), [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart), [lib/widgets/rescue_ui.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/rescue_ui.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/member_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/member_screen.dart), [lib/screens/my_sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/my_sos_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `syncAgo` (บรรทัด 10), `initState` (บรรทัด 33), `dispose` (บรรทัด 40), `_load` (บรรทัด 45), `_resolve` (บรรทัด 60), `build` (บรรทัด 86), `_conflict` (บรรทัด 433)

### [lib/services/account_storage.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/account_storage.dart)

สร้าง accounts.db จับคู่ owner กับ SQLite แต่ละบัญชี สร้าง installation ID และลบฐานข้อมูลเจ้าของหลังลบบัญชี; มี legacy claimGuest แต่ flow Login ปัจจุบันปิดไว้

- คลาส/enum: `AccountStorage`
- เชื่อมไฟล์ในแอพ: [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `select` (บรรทัด 37), `removeOwner` (บรรทัด 91), `close` (บรรทัด 110)

### [lib/services/app_preferences.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/app_preferences.dart)

โหลด/บันทึกธีม ภาษา แจ้งเตือน ชื่อร่าง/ชื่อ cache ใน settings ของบัญชี แจ้ง UI เมื่อเปลี่ยน

- คลาส/enum: `AppPreferences`
- เชื่อมไฟล์ในแอพ: [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/l10n/app_strings.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/l10n/app_strings.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/main.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/main.dart), [lib/screens/member_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/member_screen.dart), [lib/screens/messages_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/messages_screen.dart), [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/screens/responder_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/responder_screen.dart), [lib/screens/settings_panel.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/settings_panel.dart), [lib/screens/sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sos_screen.dart), [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/services/member_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/member_service.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `reset` (บรรทัด 15), `t` (บรรทัด 24), `text` (บรรทัด 25), `load` (บรรทัด 26), `setTheme` (บรรทัด 44), `saveLocalName` (บรรทัด 54), `set` (บรรทัด 66)

### [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart)

จัดการ Supabase client, Auth/session/refresh, SecureSessionVault, PKCE, สมัคร/เข้าสู่ระบบ/recovery/resend, ผูกเครื่องและสลับบัญชี

- คลาส/enum: `AccountSession`, `AuthBackend`, `SessionVault`, `SecureSessionVault`, `SecurePkceStorage`, `SupabaseAuthBackend`, `AuthService`
- เชื่อมไฟล์ในแอพ: [lib/services/account_storage.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/account_storage.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/services/app_preferences.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/app_preferences.dart), [lib/services/emergency_profile_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/emergency_profile_store.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/main.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/main.dart), [lib/screens/emergency_profile_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/emergency_profile_screen.dart), [lib/screens/forgot_password_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/forgot_password_screen.dart), [lib/screens/login_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/login_screen.dart), [lib/screens/member_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/member_screen.dart), [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/screens/register_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/register_screen.dart), [lib/screens/settings_panel.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/settings_panel.dart), [lib/services/chat_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/chat_sync_service.dart), [lib/services/emergency_profile_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/emergency_profile_service.dart), [lib/services/media_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_service.dart), [lib/services/media_upload_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_upload_service.dart), [lib/services/member_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/member_service.dart), [lib/services/sos_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_sync_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `authenticate` (บรรทัด 19), `restore` (บรรทัด 26), `linkInstallation` (บรรทัด 27), `signOut` (บรรทัด 32), `sendPasswordResetEmail` (บรรทัด 33), `resendConfirmation` (บรรทัด 34), `resetPasswordWithOtp` (บรรทัด 35), `read` (บรรทัด 43), `write` (บรรทัด 44), `clear` (บรรทัด 45), `read` (บรรทัด 54), `write` (บรรทัด 56), `clear` (บรรทัด 58), `_key` (บรรทัด 67), `getItem` (บรรทัด 69), `setItem` (บรรทัด 72), `removeItem` (บรรทัด 75), `authenticate` (บรรทัด 105), `restore` (บรรทัด 149), `linkInstallation` (บรรทัด 184), `signOut` (บรรทัด 212), `sendPasswordResetEmail` (บรรทัด 225), `resendConfirmation` (บรรทัด 235), `resetPasswordWithOtp` (บรรทัด 245), `cloudClient` (บรรทัด 310), `_getCloudClient` (บรรทัด 319), `_invalidate` (บรรทัด 378), `initialize` (บรรทัด 390), `_restore` (บรรทัด 391), `authenticate` (บรรทัด 422), `signOut` (บรรทัด 534), `sendPasswordResetEmail` (บรรทัด 563), `resendConfirmation` (บรรทัด 572), `resetPasswordWithOtp` (บรรทัด 590)

### [lib/services/chat_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/chat_store.dart)

เก็บสำเนาเฉพาะ text message สำหรับ Cloud พร้อมคิว แก้/ลบประวัติ รับผล sync merge และ resolve conflict

- คลาส/enum: `ChatStore`
- เชื่อมไฟล์ในแอพ: [lib/models/message_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/message_model.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/services/chat_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/chat_sync_service.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `createSchema` (บรรทัด 12), `capture` (บรรทัด 34), `_save` (บรรทัด 46), `list` (บรรทัด 68), `queue` (บรรทัด 74), `edit` (บรรทัด 77), `_putRemote` (บรรทัด 100), `resolve` (บรรทัด 118), `acknowledge` (บรรทัด 148), `mergeRemote` (บรรทัด 186)

### [lib/services/chat_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/chat_sync_service.dart)

SupabaseChatCloud เรียก sync_chat/อ่าน chat_records; service push/pull/retry; coordinator ทุก 15 วินาที/resume/เปลี่ยนบัญชี

- คลาส/enum: `ChatCloud`, `SupabaseChatCloud`, `ChatSyncService`, `ChatSyncCoordinator`
- เชื่อมไฟล์ในแอพ: [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/services/chat_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/chat_store.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/main.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/main.dart), [lib/screens/chat_history_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_history_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `push` (บรรทัด 9), `pull` (บรรทัด 10), `push` (บรรทัด 18), `pull` (บรรทัด 36), `_notify` (บรรทัด 61), `refreshStatus` (บรรทัด 65), `sync` (บรรทัด 79), `dispose` (บรรทัด 133), `start` (บรรทัด 144), `_scopeChanged` (บรรทัด 155), `didChangeAppLifecycleState` (บรรทัด 172)

### [lib/services/connection_session.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/connection_session.dart)

สะพาน MethodChannel ไป Android foreground service, notification, เปิดเหตุจาก notification และตั้งวันเวลา

- คลาส/enum: `ConnectionSession`
- เชื่อมไฟล์ในแอพ: [lib/models/incoming_notice.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/incoming_notice.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart), [lib/services/nearby_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/nearby_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `listenForNotifications` (บรรทัด 9), `detachNotifications` (บรรทัด 24), `notify` (บรรทัด 28), `openDateSettings` (บรรทัด 34), `start` (บรรทัด 40), `stop` (บรรทัด 46), `alert` (บรรทัด 50), `mediaAlert` (บรรทัด 56)

### [lib/services/emergency_profile_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/emergency_profile_service.dart)

repository อ่าน profiles/medical จาก Cloud fallback cache บันทึก local ก่อน upload และถอน consent

- คลาส/enum: `EmergencyProfileResult`, `EmergencyProfileRepository`, `SupabaseEmergencyProfileRepository`
- เชื่อมไฟล์ในแอพ: [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/services/emergency_profile_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/emergency_profile_store.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/emergency_profile_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/emergency_profile_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `read` (บรรทัด 15), `save` (บรรทัด 16), `deleteHealth` (บรรทัด 17), `_check` (บรรทัด 27), `read` (บรรทัด 32), `save` (บรรทัด 83), `_upload` (บรรทัด 95), `deleteHealth` (บรรทัด 112)

### [lib/services/emergency_profile_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/emergency_profile_store.dart)

ตรวจ/normalize ข้อมูลสุขภาพ เก็บใน SecureProfileVault พร้อม pending/revision และซิงก์ผ่าน save_rescue_profile

- คลาส/enum: `ProfileVault`, `SecureProfileVault`, `EmergencyProfileStore`
- เชื่อมไฟล์ในแอพ: ไม่มี relative import
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/emergency_profile_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/emergency_profile_screen.dart), [lib/screens/register_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/register_screen.dart), [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/services/emergency_profile_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/emergency_profile_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `read` (บรรทัด 20), `write` (บรรทัด 21), `remove` (บรรทัด 22), `_key` (บรรทัด 30), `read` (บรรทัด 32), `write` (บรรทัด 34), `remove` (บรรทัด 37), `normalizeProfile` (บรรทัด 39), `Function` (บรรทัด 88), `record` (บรรทัด 100), `_record` (บรรทัด 102), `save` (บรรทัด 112), `sync` (บรรทัด 129), `_sync` (บรรทัด 137)

### [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart)

แกน SQLite schema v9 ธุรกรรมข้อความ/สื่อ/คิว SOS-chat, unread, settings, peers, relay และ ACK

- คลาส/enum: `LocalDatabaseService`
- เชื่อมไฟล์ในแอพ: [lib/models/media_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/media_model.dart), [lib/models/message_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/message_model.dart), [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/services/sos_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_store.dart), [lib/services/chat_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/chat_store.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/member_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/member_screen.dart), [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/services/account_storage.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/account_storage.dart), [lib/services/app_preferences.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/app_preferences.dart), [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/services/chat_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/chat_store.dart), [lib/services/chat_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/chat_sync_service.dart), [lib/services/media_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_service.dart), [lib/services/media_upload_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_upload_service.dart), [lib/services/member_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/member_service.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart), [lib/services/sos_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_store.dart), [lib/services/sos_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_sync_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `_open` (บรรทัด 30), `_createRelaySeen` (บรรทัด 82), `_createRelayQueueSchema` (บรรทัด 85), `_upgradeRelayQueues` (บรรทัด 113), `_createLocalReceiptTime` (บรรทัด 137), `_createMediaSchema` (บรรทัด 153), `claimRelay` (บรรทัด 174), `enqueueRelay` (บรรทัด 192), `retryableRelayItems` (บรรทัด 230), `markRelayAttempt` (บรรทัด 244), `deleteRelayItem` (บรรทัด 259), `enqueueRelayAck` (บรรทัด 270), `_enqueueRelayAck` (บรรทัด 285), `relayItem` (บรรทัด 307), `acceptRelayAck` (บรรทัด 319), `markRelayAckAttempt` (บรรทัด 353), `resetRelayBackoff` (บรรทัด 369), `pendingRelayAcks` (บรรทัด 376), `deleteRelayAckItem` (บรรทัด 386), `cleanupExpiredRelayItems` (บรรทัด 397), `getDeviceId` (บรรทัด 415), `savePeer` (บรรทัด 430), `getSetting` (บรรทัด 446), `saveReceivedRoute` (บรรทัด 456), `getReceivedRoutes` (บรรทัด 463), `setSetting` (บรรทัด 476), `recordRemoteSos` (บรรทัด 486), `getRemoteSos` (บรรทัด 507), `saveSos` (บรรทัด 523), `getPeers` (บรรทัด 536), `insertMessage` (บรรทัด 543), `updateMessageStatus` (บรรทัด 578), `getMessages` (บรรทัด 593), `getUnreadCounts` (บรรทัด 599), `markConversationRead` (บรรทัด 613), `getConversation` (บรรทัด 642), `saveMediaMessage` (บรรทัด 654), `insertMediaFile` (บรรทัด 689), `updateMediaFile` (บรรทัด 698), `getMediaFile` (บรรทัด 707), `getMediaForMessage` (บรรทัด 716), `getAllMedia` (บรรทัด 726), `close` (บรรทัด 736), `retire` (บรรทัด 741)

### [lib/services/media_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_service.dart)

เลือก/คัดลอกภาพและวิดีโอ คำนวณ hash ส่ง mediaInit+FILE รับ/ตรวจ/บันทึก/ACK retry และ relay สื่อ

- คลาส/enum: `MediaService`
- เชื่อมไฟล์ในแอพ: [lib/models/media_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/media_model.dart), [lib/models/message_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/message_model.dart), [lib/models/relay_packet.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/relay_packet.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/services/nearby_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/nearby_service.dart), [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/services/media_upload_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_upload_service.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart), [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `Function` (บรรทัด 49), `Function` (บรรทัด 50), `Function` (บรรทัด 51), `Function` (บรรทัด 52), `getMediaForMessage` (บรรทัด 86), `initialize` (บรรทัด 96), `_resetStuckStates` (บรรทัด 125), `dispose` (บรรทัด 150), `_notify` (บรรทัด 164), `_updateCache` (บรรทัด 168), `pickAndSend` (บรรทัด 176), `sendPendingForPeer` (บรรทัด 282), `_sendMedia` (บรรทัด 316), `_nextRelayHop` (บรรทัด 397), `forwardRelayMedia` (บรรทัด 404), `handleRelayMediaInit` (บรรทัด 445), `acceptRelayMediaAck` (บรรทัด 456), `acceptOriginRelayMediaAck` (บรรทัด 473), `_pauseExpired` (บรรทัด 490), `retryMedia` (บรรทัด 505), `pauseDisconnected` (บรรทัด 518), `_onFilePayloadStarted` (บรรทัด 530), `_onFileTransferProgress` (บรรทัด 543), `_onFileTransferSuccess` (บรรทัด 574), `_finishReceived` (บรรทัด 601), `_verifyAndSaveReceived` (บรรทัด 627), `_onFileTransferFailed` (บรรทัด 760), `handleMediaInit` (บรรทัด 805), `handleMediaAck` (บรรทัด 894), `_mimeFromExtension` (บรรทัด 955)

### [lib/services/media_upload_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_upload_service.dart)

คิวอัปโหลด Cloud แยกจาก P2P, progress/retry/backoff, ตรวจ hash บน Cloud, media_records และ signed URL

- คลาส/enum: `UploadState`, `MediaUpload`, `MediaCloud`, `SupabaseMediaCloud`, `MediaUploadService`
- เชื่อมไฟล์ในแอพ: [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/models/media_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/media_model.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart), [lib/services/media_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `toMap` (บรรทัด 28), `upload` (บรรทัด 50), `verify` (บรรทัด 55), `signedUrl` (บรรทัด 56), `upload` (บรรทัด 66), `verify` (บรรทัด 114), `signedUrl` (บรรทัด 136), `_notify` (บรรทัด 161), `initialize` (บรรทัด 165), `_save` (บรรทัด 181), `enqueue` (บรรทัด 185), `retryPending` (บรรทัด 218), `accessUrl` (บรรทัด 275), `dispose` (บรรทัด 284)

### [lib/services/member_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/member_service.dart)

MemberRepository อ่าน/แก้ profiles และ cache ชื่อ เรียก delete-account แล้วล้างบัญชีในเครื่อง

- คลาส/enum: `MemberProfile`, `MemberRepository`, `SupabaseMemberRepository`
- เชื่อมไฟล์ในแอพ: [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/services/app_preferences.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/app_preferences.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/member_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/member_screen.dart), [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `read` (บรรทัด 16), `updateName` (บรรทัด 17), `deleteAccount` (บรรทัด 18), `read` (บรรทัด 30), `updateName` (บรรทัด 53), `deleteAccount` (บรรทัด 81), `memberError` (บรรทัด 102)

### [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart)

แกน protocol ข้อความ/ACK/SOS/presence/directory/relay ส่งซ้ำ บันทึกก่อน ACK กรองข้อมูลเก่า บริหาร unread และส่ง notice

- คลาส/enum: `MessageService`
- เชื่อมไฟล์ในแอพ: [lib/models/message_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/message_model.dart), [lib/models/incoming_notice.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/incoming_notice.dart), [lib/models/relay_packet.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/relay_packet.dart), [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/models/peer_presence.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/peer_presence.dart), [lib/models/peer_advertisement.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/peer_advertisement.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/services/media_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_service.dart), [lib/services/nearby_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/nearby_service.dart), [lib/services/app_preferences.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/app_preferences.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart), [lib/screens/incident_detail_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/incident_detail_screen.dart), [lib/screens/messages_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/messages_screen.dart), [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/screens/responder_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/responder_screen.dart), [lib/screens/sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sos_screen.dart), [lib/services/responder_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/responder_store.dart), [lib/widgets/nearby_mini_map.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/nearby_mini_map.dart), [lib/widgets/presence_list.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/presence_list.dart), [lib/widgets/sos_radar.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/sos_radar.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `peerRoleLabel` (บรรทัด 43), `conversationPreview` (บรรทัด 50), `markConversationRead` (บรรทัด 71), `getPeerForEndpoint` (บรรทัด 90), `isReachable` (บรรทัด 96), `connectionLabel` (บรรทัด 105), `relayViaName` (บรรทัด 116), `Function` (บรรทัด 135), `Function` (บรรทัด 136), `Function` (บรรทัด 137), `_notice` (บรรทัด 140), `_sosNotice` (บรรทัด 145), `setRescueMode` (บรรทัด 181), `publishSos` (บรรทัด 199), `cancelSos` (บรรทัด 273), `isOnline` (บรรทัด 291), `_notify` (บรรทัด 296), `initialize` (บรรทัด 300), `_refresh` (บรรทัด 390), `_reloadCurrentSos` (บรรทัด 399), `_projectSos` (บรรทัด 417), `_learnSos` (บรรทัด 432), `_saveDirectory` (บรรทัด 448), `_acceptAdvertisement` (บรรทัด 459), `_receivePresence` (บรรทัด 486), `_mayForwardSos` (บรรทัด 570), `_connectionChanged` (บรรทัด 574), `sendTextMessage` (บรรทัด 603), `retry` (บรรทัด 627), `handleIncomingPayload` (บรรทัด 728), `_handleIncomingPayload` (บรรทัด 741), `_receiveRelay` (บรรทัด 855), `_receiveMediaPacket` (บรรทัด 939), `_sendOrQueueRelayAck` (บรรทัด 968), `_receiveRelayAck` (บรรทัด 996), `_drainRelayQueues` (บรรทัด 1050), `dispose` (บรรทัด 1153)

### [lib/services/nearby_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/nearby_service.dart)

ควบคุม Nearby P2P_CLUSTER ประกาศ/ค้นหา/เชื่อมอัตโนมัติ permissions/session lifecycle ส่ง bytes/file และกระจาย callbacks

- คลาส/enum: `NearbyService`
- เชื่อมไฟล์ในแอพ: [lib/models/nearby_device.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/nearby_device.dart), [lib/services/permission_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/permission_service.dart), [lib/services/connection_session.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/connection_session.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/services/media_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/media_service.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `Function` (บรรทัด 51), `Function` (บรรทัด 54), `Function` (บรรทัด 56), `Function` (บรรทัด 63), `Function` (บรรทัด 64), `_current` (บรรทัด 80), `setForeground` (บรรทัด 83), `startNearby` (บรรทัด 89), `startAutomatic` (บรรทัด 100), `_startAutomatic` (บรรทัด 103), `_connectAvailable` (บรรทัด 122), `_connectAvailableNow` (บรรทัด 125), `_rediscover` (บรรทัด 160), `_recoverConnection` (บรรทัด 168), `_keepSession` (บรรทัด 189), `_update` (บรรทัด 200), `_append` (บรรทัด 204), `_log` (บรรทัด 209), `reportError` (บรรทัด 219), `setName` (บรรทัด 226), `checkPermissions` (บรรทัด 230), `startAdvertising` (บรรทัด 237), `_startAdvertising` (บรรทัด 240), `startDiscovery` (บรรทัด 278), `_startDiscovery` (บรรทัด 281), `_startTimeout` (บรรทัด 334), `requestConnection` (บรรทัด 346), `_initiated` (บรรทัด 383), `acceptConnection` (บรรทัด 401), `_result` (บรรทัด 489), `_disconnected` (บรรทัด 514), `sendTextMessage` (บรรทัด 525), `sendMessage` (บรรทัด 561), `sendFile` (บรรทัด 574), `copyReceivedFile` (บรรทัด 586), `stopAdvertising` (บรรทัด 591), `stopDiscovery` (บรรทัด 601), `disconnect` (บรรทัด 611), `stopAll` (บรรทัด 621), `_cleanup` (บรรทัด 642), `dispose` (บรรทัด 663)

### [lib/services/permission_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/permission_service.dart)

ตรวจสิทธิ์ตาม Android SDK และบริการ Location/Bluetooth/Wi-Fi เปิดหน้าตั้งค่า; ปฏิเสธเว็บ/แพลตฟอร์มอื่น

- คลาส/enum: `PermissionService`
- เชื่อมไฟล์ในแอพ: ไม่มี relative import
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/services/nearby_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/nearby_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `statusIsReady` (บรรทัด 18), `requiredPermissions` (บรรทัด 27), `ensureReady` (บรรทัด 37), `openSettings` (บรรทัด 106)

### [lib/services/platform_database.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/platform_database.dart)

conditional export เลือกฐานข้อมูล native หรือ web ตามแพลตฟอร์ม

- คลาส/enum: ไม่มี (ใช้ฟังก์ชันหรือค่าระดับไฟล์)
- เชื่อมไฟล์ในแอพ: [lib/services/platform_database_native.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/platform_database_native.dart), [lib/services/platform_database_web.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/platform_database_web.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/main.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/main.dart)

### [lib/services/platform_database_native.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/platform_database_native.dart)

configurePlatformDatabase เป็น no-op ใช้ database factory ของ native ตามปกติ

- คลาส/enum: ไม่มี (ใช้ฟังก์ชันหรือค่าระดับไฟล์)
- เชื่อมไฟล์ในแอพ: ไม่มี relative import
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/services/platform_database.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/platform_database.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `configurePlatformDatabase` (บรรทัด 1)

### [lib/services/platform_database_web.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/platform_database_web.dart)

ตั้ง sqflite databaseFactory เป็น SQLite WASM สำหรับเว็บ

- คลาส/enum: ไม่มี (ใช้ฟังก์ชันหรือค่าระดับไฟล์)
- เชื่อมไฟล์ในแอพ: ไม่มี relative import
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/services/platform_database.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/platform_database.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `configurePlatformDatabase` (บรรทัด 3)

### [lib/services/responder_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/responder_store.dart)

บันทึก pending/helping/completed ใน settings ตรวจเหตุยังเปิดและ rescueMode แจ้งผู้แจ้งด้วยข้อความปกติ ไม่ล็อกจัดสรรเคส

- คลาส/enum: `ResponderStore`
- เชื่อมไฟล์ในแอพ: [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/responder_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/responder_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `key` (บรรทัด 9), `read` (บรรทัด 10), `update` (บรรทัด 15), `notifyReporter` (บรรทัด 63)

### [lib/services/sos_location_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_location_service.dart)

ขอ location permission เรียก Android capture ตรวจผล/timeout/cancel และข้อความอธิบาย GPS

- คลาส/enum: `SosLocationService`
- เชื่อมไฟล์ในแอพ: [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sos_screen.dart), [lib/widgets/nearby_mini_map.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/nearby_mini_map.dart), [lib/widgets/sos_radar.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/sos_radar.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `_permission` (บรรทัด 14), `capture` (บรรทัด 19), `_diagnostics` (บรรทัด 61)

### [lib/services/sos_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_store.dart)

สร้าง/อ่านประวัติ SOS และ durable Cloud queue ตรวจ revision ปิด/ลบ รับผล sync merge และ resolve conflict

- คลาส/enum: `SosRecord`, `SosStore`
- เชื่อมไฟล์ในแอพ: [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/my_sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/my_sos_screen.dart), [lib/screens/sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sos_screen.dart), [lib/screens/sync_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sync_screen.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/services/sos_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_sync_service.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `createSchema` (บรรทัด 23), `savePublished` (บรรทัด 44), `_save` (บรรทัด 49), `list` (บรรทัด 89), `queue` (บรรทัด 96), `editClosed` (บรรทัด 99), `acknowledge` (บรรทัด 118), `mergeRemote` (บรรทัด 156), `_putRemote` (บรรทัด 171), `_updateCurrent` (บรรทัด 188), `resolve` (บรรทัด 213)

### [lib/services/sos_sync_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_sync_service.dart)

SupabaseSosCloud เรียก sync_sos/อ่าน sos_records; service push/pull/retry; coordinator ทุก 15 วินาที/resume/เปลี่ยนบัญชี

- คลาส/enum: `SosCloud`, `SupabaseSosCloud`, `SosSyncService`, `SosSyncCoordinator`
- เชื่อมไฟล์ในแอพ: [lib/services/auth_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/auth_service.dart), [lib/services/local_database_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/local_database_service.dart), [lib/services/sos_store.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_store.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/main.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/main.dart), [lib/screens/member_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/member_screen.dart), [lib/screens/my_sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/my_sos_screen.dart), [lib/screens/sync_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sync_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `push` (บรรทัด 9), `pull` (บรรทัด 10), `push` (บรรทัด 18), `pull` (บรรทัด 36), `_notify` (บรรทัด 61), `refreshStatus` (บรรทัด 65), `sync` (บรรทัด 79), `dispose` (บรรทัด 133), `start` (บรรทัด 144), `_scopeChanged` (บรรทัด 155), `didChangeAppLifecycleState` (บรรทัด 172)

### [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart)

สี ตัวอักษร component themes ชุดสว่าง/มืด

- คลาส/enum: ไม่มี (ใช้ฟังก์ชันหรือค่าระดับไฟล์)
- เชื่อมไฟล์ในแอพ: ไม่มี relative import
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/main.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/main.dart), [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart), [lib/screens/incident_detail_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/incident_detail_screen.dart), [lib/screens/member_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/member_screen.dart), [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/screens/settings_panel.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/settings_panel.dart), [lib/screens/sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sos_screen.dart), [lib/screens/sync_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sync_screen.dart), [lib/widgets/brand_header.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/brand_header.dart), [lib/widgets/device_tile.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/device_tile.dart), [lib/widgets/media_bubble.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/media_bubble.dart), [lib/widgets/outbox_queue.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/outbox_queue.dart), [lib/widgets/presence_list.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/presence_list.dart), [lib/widgets/rescue_ui.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/rescue_ui.dart)

### [lib/widgets/brand_header.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/brand_header.dart)

ส่วนหัวใช้ร่วม โลโก้/ชื่อ/คำอธิบาย ไม่อ่านฐานข้อมูลเอง

- คลาส/enum: `BrandHeader`
- เชื่อมไฟล์ในแอพ: [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/demo_features_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/demo_features_screen.dart), [lib/screens/incident_detail_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/incident_detail_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `build` (บรรทัด 21)

### [lib/widgets/device_tile.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/device_tile.dart)

การ์ดอุปกรณ์/สถานะและ callback การเชื่อมต่อ; ไม่พบ production Dart อื่นเรียกปัจจุบัน

- คลาส/enum: `DeviceTile`
- เชื่อมไฟล์ในแอพ: [lib/models/nearby_device.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/nearby_device.dart), [lib/models/peer_presence.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/peer_presence.dart), [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: ไม่มีภายใน lib (อาจเป็น entrypoint/conditional target/ไฟล์ที่ยังไม่เชื่อม)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `build` (บรรทัด 22)

### [lib/widgets/location_button.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/location_button.dart)

แสดงพิกัด เปิดแผนภาพออฟไลน์/แอพแผนที่ผ่าน native channel

- คลาส/enum: `LocationButton`
- เชื่อมไฟล์ในแอพ: [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/widgets/offline_location_map.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/offline_location_map.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart), [lib/screens/incident_detail_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/incident_detail_screen.dart), [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart), [lib/screens/responder_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/responder_screen.dart), [lib/screens/sos_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sos_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `build` (บรรทัด 10)

### [lib/widgets/media_bubble.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/media_bubble.dart)

แสดงไฟล์ภาพ/วิดีโอ progress/error ดูเต็มจอและ CloudMediaViewer

- คลาส/enum: `MediaBubble`, `_FullScreenImage`, `_FullScreenVideo`, `CloudMediaViewer`, `_CloudMediaViewerState`, `_FullScreenVideoState`
- เชื่อมไฟล์ในแอพ: [lib/models/media_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/media_model.dart), [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `build` (บรรทัด 15), `_progress` (บรรทัด 46), `_pending` (บรรทัด 100), `_error` (บรรทัด 145), `_mediaContent` (บรรทัด 183), `_imageView` (บรรทัด 197), `_videoThumb` (บรรทัด 237), `_fileCard` (บรรทัด 291), `_openImage` (บรรทัด 323), `_openVideo` (บรรทัด 331), `_fileHeader` (บรรทัด 341), `_card` (บรรทัด 364), `_placeholder` (บรรทัด 384), `_formatSize` (บรรทัด 410), `build` (บรรทัด 426), `initState` (บรรทัด 470), `dispose` (บรรทัด 486), `build` (บรรทัด 492), `initState` (บรรทัด 535), `dispose` (บรรทัด 551), `build` (บรรทัด 557)

### [lib/widgets/nearby_mini_map.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/nearby_mini_map.dart)

แผนภาพตำแหน่ง SOS รอบตัว คำนวณ offset จากพิกัดจริง กดเปิดเหตุและขอพิกัดตนเอง

- คลาส/enum: `NearbyMiniMap`, `_NearbyMiniMapState`, `_MapGrid`
- เชื่อมไฟล์ในแอพ: [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart), [lib/services/sos_location_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_location_service.dart), [lib/screens/incident_detail_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/incident_detail_screen.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `_locate` (บรรทัด 21), `_open` (บรรทัด 47), `build` (บรรทัด 55), `paint` (บรรทัด 265), `shouldRepaint` (บรรทัด 283)

### [lib/widgets/offline_location_map.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/offline_location_map.dart)

วาดกริดพิกัดเหตุ ไม่มีถนนและไม่โหลด map tiles

- คลาส/enum: `OfflineLocationMap`, `_CoordinatePainter`
- เชื่อมไฟล์ในแอพ: [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/widgets/location_button.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/location_button.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `build` (บรรทัด 10), `paint` (บรรทัด 116), `shouldRepaint` (บรรทัด 137)

### [lib/widgets/outbox_queue.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/outbox_queue.dart)

แสดงรายการส่งตามสถานะ รายละเอียดเวลา/เหตุ/เส้นทาง กลุ่ม synced อาศัย MessageStatus ของรายการ

- คลาส/enum: `OutboxQueue`, `_OutboxQueueState`
- เชื่อมไฟล์ในแอพ: [lib/models/message_model.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/message_model.dart), [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `_group` (บรรทัด 54), `_date` (บรรทัด 60), `_compactDate` (บรรทัด 79), `_title` (บรรทัด 109), `_details` (บรรทัด 115), `_status` (บรรทัด 152), `build` (บรรทัด 161), `_card` (บรรทัด 347)

### [lib/widgets/presence_list.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/presence_list.dart)

รายการ presence/เหตุพร้อมสถานะและปุ่มเปิดรายละเอียด/แชต

- คลาส/enum: `PresenceFilter`, `PresenceList`
- เชื่อมไฟล์ในแอพ: [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart), [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart), [lib/screens/incident_detail_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/incident_detail_screen.dart), [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/nearby_test_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/nearby_test_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `build` (บรรทัด 20)

### [lib/widgets/privacy_notice.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/privacy_notice.dart)

dialog แจ้งการใช้/เก็บข้อมูลส่วนตัวและสุขภาพ

- คลาส/enum: ไม่มี (ใช้ฟังก์ชันหรือค่าระดับไฟล์)
- เชื่อมไฟล์ในแอพ: ไม่มี relative import
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/emergency_profile_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/emergency_profile_screen.dart), [lib/screens/register_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/register_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `showPrivacyNotice` (บรรทัด 2)

### [lib/widgets/relay_badge.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/relay_badge.dart)

ป้ายแสดงการส่งผ่านเครื่องกลาง/เส้นทาง

- คลาส/enum: `RelayBadge`
- เชื่อมไฟล์ในแอพ: ไม่มี relative import
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `build` (บรรทัด 9)

### [lib/widgets/rescue_ui.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/rescue_ui.dart)

RescueSectionLabel/Group/Tile/Banner ส่วนประกอบ UI ใช้ร่วม

- คลาส/enum: `RescueBannerKind`, `RescueSectionLabel`, `RescueGroup`, `RescueTile`, `RescueBanner`
- เชื่อมไฟล์ในแอพ: [lib/theme/rescue_theme.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/theme/rescue_theme.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: [lib/screens/member_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/member_screen.dart), [lib/screens/sync_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/sync_screen.dart)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `build` (บรรทัด 12), `build` (บรรทัด 36), `build` (บรรทัด 82), `build` (บรรทัด 149)

### [lib/widgets/sos_radar.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/widgets/sos_radar.dart)

หน้ารูปเรดาร์ตำแหน่ง SOS ขอพิกัด คำนวณและเปิดรายละเอียด/แชต; ไม่พบ production Dart อื่นเรียกปัจจุบัน

- คลาส/enum: `SosRadar`, `_SosRadarState`, `_RadarPainter`
- เชื่อมไฟล์ในแอพ: [lib/models/sos_alert.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/models/sos_alert.dart), [lib/services/message_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/message_service.dart), [lib/services/sos_location_service.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/services/sos_location_service.dart), [lib/screens/chat_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/chat_screen.dart), [lib/screens/incident_detail_screen.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/lib/screens/incident_detail_screen.dart)
- ไฟล์ที่เรียกใช้ผ่าน import/export: ไม่มีภายใน lib (อาจเป็น entrypoint/conditional target/ไฟล์ที่ยังไม่เชื่อม)
- เมธอด/ฟังก์ชันหลักที่ตรวจพบ: `sosDistance` (บรรทัด 9), `initState` (บรรทัด 35), `dispose` (บรรทัด 43), `_locate` (บรรทัด 48), `build` (บรรทัด 70), `paint` (บรรทัด 315), `shouldRepaint` (บรรทัด 347)

## ไฟล์ประกอบทุกไฟล์ในขอบเขตตรวจ

| ไฟล์ | หน้าที่ |
|---|---|
| [.gitignore](D:/3-1/project_keeratiburt/miniProject/rescuelink/.gitignore) | รายการไฟล์ที่ไม่ให้ Git ติดตาม |
| [.metadata](D:/3-1/project_keeratiburt/miniProject/rescuelink/.metadata) | Flutter project metadata สำหรับ tooling/migrations |
| [.vscode/settings.json](D:/3-1/project_keeratiburt/miniProject/rescuelink/.vscode/settings.json) | ไฟล์ประกอบโปรเจกต์/เครื่องมือ: settings.json |
| [README.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/README.md) | คำอธิบาย/ตั้งค่า/ประวัติ Phase; บางส่วนเก่าต้องเทียบโค้ดปัจจุบัน |
| [analysis_options.yaml](D:/3-1/project_keeratiburt/miniProject/rescuelink/analysis_options.yaml) | กฎวิเคราะห์ Dart/Flutter |
| [android/.gitignore](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/.gitignore) | รายการไฟล์ที่ไม่ให้ Git ติดตาม |
| [android/app/build.gradle.kts](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/build.gradle.kts) | การตั้งค่า/ตัวเรียก Android Gradle build และ dependencies native |
| [android/app/src/debug/AndroidManifest.xml](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/debug/AndroidManifest.xml) | manifest สำหรับ debug/profile เช่น Internet permission |
| [android/app/src/main/AndroidManifest.xml](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/main/AndroidManifest.xml) | สิทธิ์ Android และ declaration ของ MainActivity/ConnectionService |
| [android/app/src/main/kotlin/com/rmutt/rescuelink/ConnectionService.kt](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/main/kotlin/com/rmutt/rescuelink/ConnectionService.kt) | Android foreground connected-device service + notification + WakeLock; cleanup เมื่อหยุด |
| [android/app/src/main/kotlin/com/rmutt/rescuelink/LocationCapture.kt](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/main/kotlin/com/rmutt/rescuelink/LocationCapture.kt) | อ่านตำแหน่งจาก GPS/network/Fused รับเฉพาะ fix สดและมี accuracy, diagnostics/timeout/cancel |
| [android/app/src/main/kotlin/com/rmutt/rescuelink/MainActivity.kt](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/main/kotlin/com/rmutt/rescuelink/MainActivity.kt) | Flutter Android entrypoint และ MethodChannel location/session/maps, notifications, Wi-Fi, service |
| [android/app/src/main/res/drawable-v21/launch_background.xml](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/main/res/drawable-v21/launch_background.xml) | Android launcher icon / launch background / styles ตามชนิดไฟล์และ density |
| [android/app/src/main/res/drawable/launch_background.xml](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/main/res/drawable/launch_background.xml) | Android launcher icon / launch background / styles ตามชนิดไฟล์และ density |
| [android/app/src/main/res/mipmap-hdpi/ic_launcher.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/main/res/mipmap-hdpi/ic_launcher.png) | Android launcher icon / launch background / styles ตามชนิดไฟล์และ density |
| [android/app/src/main/res/mipmap-mdpi/ic_launcher.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/main/res/mipmap-mdpi/ic_launcher.png) | Android launcher icon / launch background / styles ตามชนิดไฟล์และ density |
| [android/app/src/main/res/mipmap-xhdpi/ic_launcher.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png) | Android launcher icon / launch background / styles ตามชนิดไฟล์และ density |
| [android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png) | Android launcher icon / launch background / styles ตามชนิดไฟล์และ density |
| [android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png) | Android launcher icon / launch background / styles ตามชนิดไฟล์และ density |
| [android/app/src/main/res/values-night/styles.xml](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/main/res/values-night/styles.xml) | Android launcher icon / launch background / styles ตามชนิดไฟล์และ density |
| [android/app/src/main/res/values/styles.xml](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/main/res/values/styles.xml) | Android launcher icon / launch background / styles ตามชนิดไฟล์และ density |
| [android/app/src/profile/AndroidManifest.xml](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/app/src/profile/AndroidManifest.xml) | manifest สำหรับ debug/profile เช่น Internet permission |
| [android/build.gradle.kts](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/build.gradle.kts) | การตั้งค่า/ตัวเรียก Android Gradle build และ dependencies native |
| [android/gradle.properties](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/gradle.properties) | การตั้งค่า/ตัวเรียก Android Gradle build และ dependencies native |
| [android/gradle/wrapper/gradle-wrapper.properties](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/gradle/wrapper/gradle-wrapper.properties) | การตั้งค่า/ตัวเรียก Android Gradle build และ dependencies native |
| [android/settings.gradle.kts](D:/3-1/project_keeratiburt/miniProject/rescuelink/android/settings.gradle.kts) | การตั้งค่า/ตัวเรียก Android Gradle build และ dependencies native |
| [assets/branding/README.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/assets/branding/README.md) | คำอธิบายที่มา/การใช้งาน assets |
| [assets/branding/rescuelink-logo-dark.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/assets/branding/rescuelink-logo-dark.png) | รูปโลโก้ RescueLink ที่หน้า UI ใช้ |
| [assets/branding/rescuelink-logo.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/assets/branding/rescuelink-logo.png) | รูปโลโก้ RescueLink ที่หน้า UI ใช้ |
| [assets/fonts/NotoSansThai.ttf](D:/3-1/project_keeratiburt/miniProject/rescuelink/assets/fonts/NotoSansThai.ttf) | ฟอนต์ NotoSansThai สำหรับแสดงภาษาไทย |
| [assets/fonts/OFL-NotoSansThai.txt](D:/3-1/project_keeratiburt/miniProject/rescuelink/assets/fonts/OFL-NotoSansThai.txt) | ใบอนุญาตฟอนต์ |
| [assets/onboarding/README.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/assets/onboarding/README.md) | คำอธิบายที่มา/การใช้งาน assets |
| [assets/onboarding/nearby.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/assets/onboarding/nearby.png) | ภาพประกอบ Onboarding |
| [assets/onboarding/sos.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/assets/onboarding/sos.png) | ภาพประกอบ Onboarding |
| [assets/onboarding/welcome.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/assets/onboarding/welcome.png) | ภาพประกอบ Onboarding |
| [config/supabase.example.json](D:/3-1/project_keeratiburt/miniProject/rescuelink/config/supabase.example.json) | ตัวอย่างชื่อ config SUPABASE_URL/PUBLISHABLE_KEY ไม่มี credentials จริง |
| [docs/AUTH_MEDICAL_PROFILE_VERIFICATION.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/AUTH_MEDICAL_PROFILE_VERIFICATION.md) | เอกสาร/หลักฐานเดิม: Authentication และข้อมูลสุขภาพฉุกเฉิน — 9 ตุลาคม 2026; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/CHAT_CLOUD_SYNC.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/CHAT_CLOUD_SYNC.md) | เอกสาร/หลักฐานเดิม: ประวัติข้อความ CRUD และ Cloud Sync — 2026-10-08; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/EMULATOR_RUN_FIX.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/EMULATOR_RUN_FIX.md) | เอกสาร/หลักฐานเดิม: แก้ flutter run -d emulator-5554 — 2026-09-23; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/MESSAGES_SOS_PROFILE_IMPLEMENTATION.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/MESSAGES_SOS_PROFILE_IMPLEMENTATION.md) | เอกสาร/หลักฐานเดิม: รายงาน Messages, SOS และ Profile; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/MESSAGES_SOS_PROFILE_QUEUE_AUDIT.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/MESSAGES_SOS_PROFILE_QUEUE_AUDIT.md) | เอกสาร/หลักฐานเดิม: รายงานตรวจ Message Queue / Supabase Sync; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/NEARBY_HOME_MODES_VERIFICATION.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/NEARBY_HOME_MODES_VERIFICATION.md) | เอกสาร/หลักฐานเดิม: หน้าใกล้ฉัน: Normal / SOS / Rescue; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/NEARBY_MAP_UI.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/NEARBY_MAP_UI.md) | เอกสาร/หลักฐานเดิม: แผนที่รอบตัว; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/PHASE_2_MEMBERSHIP.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/PHASE_2_MEMBERSHIP.md) | เอกสาร/หลักฐานเดิม: Phase 2 — สมาชิกและโครงสร้างข้อมูล; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/PHASE_2_TEST.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/PHASE_2_TEST.md) | เอกสาร/หลักฐานเดิม: Phase 2: Reliable Offline Messaging; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/PHASE_3_CRUD_SYNC.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/PHASE_3_CRUD_SYNC.md) | เอกสาร/หลักฐานเดิม: Phase 3 — SOS CRUD and Cloud Sync; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/PHASE_3_TEST.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/PHASE_3_TEST.md) | เอกสาร/หลักฐานเดิม: Phase 3 — SOS / Rescue / Location; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/PHASE_4_TEST.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/PHASE_4_TEST.md) | เอกสาร/หลักฐานเดิม: Phase 4 — SOS / Rescue / Map acceptance; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/PHASE_5_DIRECTORY_SOS_VERIFICATION.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/PHASE_5_DIRECTORY_SOS_VERIFICATION.md) | เอกสาร/หลักฐานเดิม: รายชื่อและ SOS/Rescue ผ่าน Relay — 2026-10-05; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/PHASE_5_PART_1.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/PHASE_5_PART_1.md) | เอกสาร/หลักฐานเดิม: Phase 5 — ช่วงที่ 1: Text multi-hop; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/PHASE_5_PROTOCOL.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/PHASE_5_PROTOCOL.md) | เอกสาร/หลักฐานเดิม: Phase 5 — Protocol Reference; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/PHASE_5_QUEUE_ACK_VERIFICATION.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/PHASE_5_QUEUE_ACK_VERIFICATION.md) | เอกสาร/หลักฐานเดิม: Phase 5 — Text relay queue and ACK verification; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/PHYSICAL_TEST.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/PHYSICAL_TEST.md) | เอกสาร/หลักฐานเดิม: บันทึกผลทดสอบ Android จริง — Phase 1; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/RELAY_MAP_UI.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/RELAY_MAP_UI.md) | เอกสาร/หลักฐานเดิม: Relay badge และแผนภาพพิกัดออฟไลน์; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/REQUIREMENTS_ROADMAP.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/REQUIREMENTS_ROADMAP.md) | เอกสาร/หลักฐานเดิม: ขอบเขตส่งงาน Off-Grid SOS & Nearby Share; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/SOS_REDESIGN.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/SOS_REDESIGN.md) | เอกสาร/หลักฐานเดิม: SOS redesign — 2026-09-27; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/TWO_PHONE_FIXES.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/TWO_PHONE_FIXES.md) | เอกสาร/หลักฐานเดิม: การแก้ปัญหาจากการทดสอบโทรศัพท์สองเครื่อง; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/UI_FLUTTER_CHECKPOINT.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/UI_FLUTTER_CHECKPOINT.md) | เอกสาร/หลักฐานเดิม: UX/UI Flutter — checkpoint 2026-09-25; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/VALIDATION.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/VALIDATION.md) | เอกสาร/หลักฐานเดิม: Validation; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/WEEK3_VERIFICATION.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/WEEK3_VERIFICATION.md) | เอกสาร/หลักฐานเดิม: Week 3 member CRUD - 2026-10-08; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/WEEK3_VIDEO_SCRIPT.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/WEEK3_VIDEO_SCRIPT.md) | เอกสาร/หลักฐานเดิม: RescueLink - สคริปต์วิดีโอ Week 3; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/phase4-tests.txt](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/phase4-tests.txt) | ไฟล์ประกอบโปรเจกต์/เครื่องมือ: phase4-tests.txt |
| [docs/phase4-verification.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/phase4-verification.md) | เอกสาร/หลักฐานเดิม: Phase 4 — ผลการทำงานและหลักฐาน; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/ui-audit/REPORT.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/ui-audit/REPORT.md) | เอกสาร/หลักฐานเดิม: ผลทดสอบ UX/UI เบื้องต้น — RescueLink; ไม่ใช่ runtime และอาจเป็นผลตรวจของรุ่นก่อน |
| [docs/ui-audit/home.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/ui-audit/home.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [docs/ui-audit/media.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/ui-audit/media.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [docs/ui-audit/messages.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/ui-audit/messages.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [docs/ui-audit/phase3-history.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/ui-audit/phase3-history.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [docs/ui-audit/phase3-sync.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/ui-audit/phase3-sync.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [docs/ui-audit/settings-redesign.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/ui-audit/settings-redesign.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [docs/ui-audit/sos-dark.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/ui-audit/sos-dark.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [docs/ui-audit/sos-redesign-details.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/ui-audit/sos-redesign-details.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [docs/ui-audit/sos-redesign.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/ui-audit/sos-redesign.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [docs/ui-audit/sos.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/docs/ui-audit/sos.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [ios/.gitignore](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/.gitignore) | รายการไฟล์ที่ไม่ให้ Git ติดตาม |
| [ios/Flutter/AppFrameworkInfo.plist](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Flutter/AppFrameworkInfo.plist) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Flutter/Debug.xcconfig](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Flutter/Debug.xcconfig) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Flutter/Release.xcconfig](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Flutter/Release.xcconfig) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner.xcodeproj/project.pbxproj](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner.xcodeproj/project.pbxproj) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner.xcworkspace/contents.xcworkspacedata](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner.xcworkspace/contents.xcworkspacedata) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner/AppDelegate.swift](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/AppDelegate.swift) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png) | asset catalog/icon ของ Apple runner |
| [ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md) | คำอธิบาย/ตั้งค่า/ประวัติ Phase; บางส่วนเก่าต้องเทียบโค้ดปัจจุบัน |
| [ios/Runner/Base.lproj/LaunchScreen.storyboard](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Base.lproj/LaunchScreen.storyboard) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner/Base.lproj/Main.storyboard](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Base.lproj/Main.storyboard) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner/Info.plist](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Info.plist) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner/Runner-Bridging-Header.h](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/Runner-Bridging-Header.h) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/Runner/SceneDelegate.swift](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/Runner/SceneDelegate.swift) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [ios/RunnerTests/RunnerTests.swift](D:/3-1/project_keeratiburt/miniProject/rescuelink/ios/RunnerTests/RunnerTests.swift) | ชุดทดสอบ host runner ของ Apple platform |
| [linux/.gitignore](D:/3-1/project_keeratiburt/miniProject/rescuelink/linux/.gitignore) | รายการไฟล์ที่ไม่ให้ Git ติดตาม |
| [linux/CMakeLists.txt](D:/3-1/project_keeratiburt/miniProject/rescuelink/linux/CMakeLists.txt) | CMake build ของ Flutter desktop runner |
| [linux/flutter/CMakeLists.txt](D:/3-1/project_keeratiburt/miniProject/rescuelink/linux/flutter/CMakeLists.txt) | CMake build ของ Flutter desktop runner |
| [linux/flutter/generated_plugin_registrant.cc](D:/3-1/project_keeratiburt/miniProject/rescuelink/linux/flutter/generated_plugin_registrant.cc) | Flutter สร้างรายการลงทะเบียน native plugins อัตโนมัติ ไม่ใช่ logic ฟีเจอร์ที่เขียนเอง |
| [linux/flutter/generated_plugin_registrant.h](D:/3-1/project_keeratiburt/miniProject/rescuelink/linux/flutter/generated_plugin_registrant.h) | Flutter สร้างรายการลงทะเบียน native plugins อัตโนมัติ ไม่ใช่ logic ฟีเจอร์ที่เขียนเอง |
| [linux/flutter/generated_plugins.cmake](D:/3-1/project_keeratiburt/miniProject/rescuelink/linux/flutter/generated_plugins.cmake) | Flutter สร้างรายการลงทะเบียน native plugins อัตโนมัติ ไม่ใช่ logic ฟีเจอร์ที่เขียนเอง |
| [linux/runner/CMakeLists.txt](D:/3-1/project_keeratiburt/miniProject/rescuelink/linux/runner/CMakeLists.txt) | CMake build ของ Flutter desktop runner |
| [linux/runner/main.cc](D:/3-1/project_keeratiburt/miniProject/rescuelink/linux/runner/main.cc) | โค้ด/ทรัพยากร host window และ Flutter desktop runner ไม่ใช่ฟีเจอร์ Cloud หรือ Nearby เพิ่ม |
| [linux/runner/my_application.cc](D:/3-1/project_keeratiburt/miniProject/rescuelink/linux/runner/my_application.cc) | โค้ด/ทรัพยากร host window และ Flutter desktop runner ไม่ใช่ฟีเจอร์ Cloud หรือ Nearby เพิ่ม |
| [linux/runner/my_application.h](D:/3-1/project_keeratiburt/miniProject/rescuelink/linux/runner/my_application.h) | โค้ด/ทรัพยากร host window และ Flutter desktop runner ไม่ใช่ฟีเจอร์ Cloud หรือ Nearby เพิ่ม |
| [macos/.gitignore](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/.gitignore) | รายการไฟล์ที่ไม่ให้ Git ติดตาม |
| [macos/Flutter/Flutter-Debug.xcconfig](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Flutter/Flutter-Debug.xcconfig) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Flutter/Flutter-Release.xcconfig](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Flutter/Flutter-Release.xcconfig) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Flutter/GeneratedPluginRegistrant.swift](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Flutter/GeneratedPluginRegistrant.swift) | Flutter สร้างรายการลงทะเบียน native plugins อัตโนมัติ ไม่ใช่ logic ฟีเจอร์ที่เขียนเอง |
| [macos/Runner.xcodeproj/project.pbxproj](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner.xcodeproj/project.pbxproj) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner.xcworkspace/contents.xcworkspacedata](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner.xcworkspace/contents.xcworkspacedata) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner/AppDelegate.swift](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/AppDelegate.swift) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json) | asset catalog/icon ของ Apple runner |
| [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png) | asset catalog/icon ของ Apple runner |
| [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png) | asset catalog/icon ของ Apple runner |
| [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png) | asset catalog/icon ของ Apple runner |
| [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png) | asset catalog/icon ของ Apple runner |
| [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png) | asset catalog/icon ของ Apple runner |
| [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png) | asset catalog/icon ของ Apple runner |
| [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png) | asset catalog/icon ของ Apple runner |
| [macos/Runner/Base.lproj/MainMenu.xib](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Base.lproj/MainMenu.xib) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner/Configs/AppInfo.xcconfig](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Configs/AppInfo.xcconfig) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner/Configs/Debug.xcconfig](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Configs/Debug.xcconfig) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner/Configs/Release.xcconfig](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Configs/Release.xcconfig) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner/Configs/Warnings.xcconfig](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Configs/Warnings.xcconfig) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner/DebugProfile.entitlements](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/DebugProfile.entitlements) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner/Info.plist](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Info.plist) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner/MainFlutterWindow.swift](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/MainFlutterWindow.swift) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/Runner/Release.entitlements](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/Runner/Release.entitlements) | Flutter Apple platform host/project/build/permissions; ไม่พบ Nearby native implementation เทียบ Android ในส่วนนี้ |
| [macos/RunnerTests/RunnerTests.swift](D:/3-1/project_keeratiburt/miniProject/rescuelink/macos/RunnerTests/RunnerTests.swift) | ชุดทดสอบ host runner ของ Apple platform |
| [output/design/nearby-refresh/dark.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/output/design/nearby-refresh/dark.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [output/design/nearby-refresh/general.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/output/design/nearby-refresh/general.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [output/design/nearby-refresh/helper.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/output/design/nearby-refresh/helper.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [output/design/nearby-refresh/sos.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/output/design/nearby-refresh/sos.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [output/design/rescuelink-redesign/01-nearby-messages.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/output/design/rescuelink-redesign/01-nearby-messages.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [output/design/rescuelink-redesign/02-sos-rescue.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/output/design/rescuelink-redesign/02-sos-rescue.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [output/design/rescuelink-redesign/03-queue-profile.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/output/design/rescuelink-redesign/03-queue-profile.png) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [output/design/rescuelink-redesign/DESIGN-NOTES.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/output/design/rescuelink-redesign/DESIGN-NOTES.md) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [output/design/rescuelink-redesign/image-prompts.txt](D:/3-1/project_keeratiburt/miniProject/rescuelink/output/design/rescuelink-redesign/image-prompts.txt) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [output/pdf/rescuelink-week3-report.pdf](D:/3-1/project_keeratiburt/miniProject/rescuelink/output/pdf/rescuelink-week3-report.pdf) | ภาพ/เอกสารผลออกแบบหรือรายงานที่สร้างไว้ ไม่ใช่ runtime |
| [pubspec.lock](D:/3-1/project_keeratiburt/miniProject/rescuelink/pubspec.lock) | ล็อกเวอร์ชัน dependencies ที่ resolve แล้ว |
| [pubspec.yaml](D:/3-1/project_keeratiburt/miniProject/rescuelink/pubspec.yaml) | ชื่อ/เวอร์ชันแอพ dependencies assets และฟอนต์ |
| [supabase/functions/delete-account/index.ts](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/functions/delete-account/index.ts) | Edge Function delete-account ตรวจ JWT/รหัสผ่าน ลบไฟล์ revoke session และลบ Auth user |
| [supabase/migrations/20260928152738_membership_foundation.sql](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/migrations/20260928152738_membership_foundation.sql) | เปลี่ยน schema/สิทธิ์ฐานข้อมูล: membership foundation; ดูผลแต่ละ migration ในรายงานหลัก |
| [supabase/migrations/20260928153353_lock_internal_rls_function.sql](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/migrations/20260928153353_lock_internal_rls_function.sql) | เปลี่ยน schema/สิทธิ์ฐานข้อมูล: lock internal rls function; ดูผลแต่ละ migration ในรายงานหลัก |
| [supabase/migrations/20260929060828_sos_cloud_sync_verified.sql](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/migrations/20260929060828_sos_cloud_sync_verified.sql) | เปลี่ยน schema/สิทธิ์ฐานข้อมูล: sos cloud sync verified; ดูผลแต่ละ migration ในรายงานหลัก |
| [supabase/migrations/20260930082212_sos_payload_validation.sql](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/migrations/20260930082212_sos_payload_validation.sql) | เปลี่ยน schema/สิทธิ์ฐานข้อมูล: sos payload validation; ดูผลแต่ละ migration ในรายงานหลัก |
| [supabase/migrations/20260930153219_media_private_storage.sql](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/migrations/20260930153219_media_private_storage.sql) | เปลี่ยน schema/สิทธิ์ฐานข้อมูล: media private storage; ดูผลแต่ละ migration ในรายงานหลัก |
| [supabase/migrations/20261008054140_chat_history_cloud_sync.sql](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/migrations/20261008054140_chat_history_cloud_sync.sql) | เปลี่ยน schema/สิทธิ์ฐานข้อมูล: chat history cloud sync; ดูผลแต่ละ migration ในรายงานหลัก |
| [supabase/migrations/20261009070000_emergency_medical_profiles.sql](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/migrations/20261009070000_emergency_medical_profiles.sql) | เปลี่ยน schema/สิทธิ์ฐานข้อมูล: emergency medical profiles; ดูผลแต่ละ migration ในรายงานหลัก |
| [supabase/templates/README.md](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/templates/README.md) | วิธีตั้ง template อีเมลใน Supabase Dashboard |
| [supabase/templates/confirmation.html](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/templates/confirmation.html) | แม่แบบอีเมลยืนยันสมัครบัญชี Supabase |
| [supabase/templates/recovery.html](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/templates/recovery.html) | แม่แบบอีเมลตั้งรหัสผ่านใหม่ Supabase |
| [supabase/tests/chat_sync.sql](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/tests/chat_sync.sql) | SQL tests ตรวจ chat sync; ไม่ทำงานใน runtime แอพ |
| [supabase/tests/emergency_medical_profiles.sql](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/tests/emergency_medical_profiles.sql) | SQL tests ตรวจ emergency medical profiles; ไม่ทำงานใน runtime แอพ |
| [supabase/tests/media_storage.sql](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/tests/media_storage.sql) | SQL tests ตรวจ media storage; ไม่ทำงานใน runtime แอพ |
| [supabase/tests/ownership.sql](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/tests/ownership.sql) | SQL tests ตรวจ ownership; ไม่ทำงานใน runtime แอพ |
| [supabase/tests/sos_sync.sql](D:/3-1/project_keeratiburt/miniProject/rescuelink/supabase/tests/sos_sync.sql) | SQL tests ตรวจ sos sync; ไม่ทำงานใน runtime แอพ |
| [test/account_auth_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/account_auth_test.dart) | ทดสอบ account auth; ตัวอย่างกรณี: resend calls backend and throttles repeated attempts / catalog failure never falls back to previously claimed legacy data / sign in creates user-specific storage without transferring Guest data |
| [test/account_deletion_storage_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/account_deletion_storage_test.dart) | ทดสอบ account deletion storage; ตัวอย่างกรณี: deletion isolates other owners and retained handles cannot recreate deleted database |
| [test/chat_sync_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/chat_sync_test.dart) | ทดสอบ chat sync; ตัวอย่างกรณี: offline messages and edits survive restart and sync once online / lost upload response replays idempotently and preserves radio delivery / delete syncs tombstone and duplicate incoming packet cannot resurrect |
| [test/dark_theme_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/dark_theme_test.dart) | ทดสอบ dark theme; ตัวอย่างกรณี: SOS adapts live to dark theme with readable secondary text |
| [test/delete_account_function_test.mjs](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/delete_account_function_test.mjs) | Node tests จำลอง Auth/Storage API เพื่อตรวจ Edge Function delete-account ไม่ลบผู้ใช้จริง |
| [test/demo_features_screen_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/demo_features_screen_test.dart) | ทดสอบ demo features screen; ตัวอย่างกรณี: demo sync requires online account and supports failure recovery / media demo queues samples and discards them when closed |
| [test/emergency_profile_screen_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/emergency_profile_screen_test.dart) | ทดสอบ emergency profile screen; ตัวอย่างกรณี: medical editor saves and withdraws consent on small screen dark=$dark / verification dialog scrolls without overflow at 320px |
| [test/emergency_profile_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/emergency_profile_test.dart) | ทดสอบ emergency profile; ตัวอย่างกรณี: no health consent strips every medical field; limits are enforced / SDK signup keeps medical data out of Auth/JWT and duplicate signup cannot overwrite it / late upload cannot mark a newer consent withdrawal as synced |
| [test/forgot_password_screen_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/forgot_password_screen_test.dart) | ทดสอบ forgot password screen; ตัวอย่างกรณี: forgot password screen validates email and moves to otp step |
| [test/login_screen_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/login_screen_test.dart) | ทดสอบ login screen; ตัวอย่างกรณี: signup collects all steps and resends without repeating signup / skip removes health even when consent was checked / signup validates password match and required names |
| [test/media_cloud_live_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/media_cloud_live_test.dart) | ทดสอบ media cloud live; ตัวอย่างกรณี: live private upload, checksum, metadata, retry and denied anonymous access (ต้องเปิด flag ทดสอบ Cloud จริง; default ข้าม) |
| [test/media_search_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/media_search_test.dart) | ทดสอบ media search; ตัวอย่างกรณี: searches text and media filenames; filters image, video and pending |
| [test/media_service_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/media_service_test.dart) | ทดสอบ media service; ตัวอย่างกรณี: FILE start and init cannot finalize until SUCCESS; duplicate notifies once / intermediary forwards a verified file with origin and route intact / SUCCESS before init is retained and verified after metadata arrives |
| [test/media_upload_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/media_upload_test.dart) | ทดสอบ media upload; ตัวอย่างกรณี: 100 percent uploaded is not ready until cloud verification passes / failure is durable; restart does not upload until selected; retry uses same ID / account switch cannot expose the previous account upload or reuse its queue |
| [test/medical_cloud_live_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/medical_cloud_live_test.dart) | ทดสอบ medical cloud live; ตัวอย่างกรณี: live verified member can read own personal and medical rows; anonymous access is denied (ต้องเปิด flag ทดสอบ Cloud จริง; default ข้าม) |
| [test/member_repository_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/member_repository_test.dart) | ทดสอบ member repository; ตัวอย่างกรณี: real SDK reads and updates owned profile, then calls guarded deletion and clears owner storage |
| [test/member_screen_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/member_screen_test.dart) | ทดสอบ member screen; ตัวอย่างกรณี: reads profile, blocks empty names and persists edited name / delete cancellation and incorrect password preserve account |
| [test/message_service_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/message_service_test.dart) | ทดสอบ message service; ตัวอย่างกรณี: switching to rescue cancels SOS through the existing pending outbox / broadcast state reaches a newly connected peer and repeats cancellation / unread summary is per peer, deduplicated and persists read watermark |
| [test/messages_responder_settings_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/messages_responder_settings_test.dart) | ทดสอบ messages responder settings; ตัวอย่างกรณี: conversation list uses real history, sorts, searches and filters unread / case work is durable, duplicate-safe, unconfirmed and uses original offline queue / locale, three theme modes and local profile draft survive preferences reload |
| [test/multi_hop_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/multi_hop_test.dart) | ทดสอบ multi hop; ตัวอย่างกรณี: A to B to C and ACK preserve origin; duplicates and restart do not add chat rows / looped path, wrong last hop, unsupported type and excessive hops are rejected / version 1 storage upgrades without losing identity or history |
| [test/my_sos_screen_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/my_sos_screen_test.dart) | ทดสอบ my sos screen; ตัวอย่างกรณี: history edit/delete and responsive SOS and Sync screens |
| [test/nearby_mini_map_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/nearby_mini_map_test.dart) | ทดสอบ nearby mini map; ตัวอย่างกรณี: map shows no invented location and reads local GPS only on request |
| [test/nearby_modes_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/nearby_modes_test.dart) | ทดสอบ nearby modes; ตัวอย่างกรณี: resume during permission work retries once; explicit stop stays stopped / home changes priority using own mode, dark=$dark |
| [test/nearby_screen_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/nearby_screen_test.dart) | ทดสอบ nearby screen; ตัวอย่างกรณี: nearby page renders and scrolls on a phone |
| [test/nearby_service_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/nearby_service_test.dart) | ทดสอบ nearby service; ตัวอย่างกรณี: active background session retains payload delivery when paused and STOP releases it / home search connects automatically and keeps scanning after connection / automatic mode requests discovered peers and continues discovery after connection |
| [test/network_presence_sos_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/network_presence_sos_test.dart) | ทดสอบ network presence sos; ตัวอย่างกรณี: A discovers C through B without pairing and sends a chat with ACK / Rescue changes cross B and old cached entries cannot renew after restart / stale age and a missing first hop do not advertise reachable users |
| [test/onboarding_screen_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/onboarding_screen_test.dart) | ทดสอบ onboarding screen; ตัวอย่างกรณี: three introduction pages lead to login on a small screen / swiping and skip open login |
| [test/outbox_queue_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/outbox_queue_test.dart) | ทดสอบ outbox queue; ตัวอย่างกรณี: filters delivery states and opens details on a narrow screen |
| [test/phase_4_widgets_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/phase_4_widgets_test.dart) | ทดสอบ phase 4 widgets; ตัวอย่างกรณี: live directory hides stale people and opens reachable chat / SOS requester sees helper names without their cancelled SOS history / map sends exact coordinates and handles missing map application |
| [test/redesign_screens_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/redesign_screens_test.dart) | ทดสอบ redesign screens; ตัวอย่างกรณี: renders properly with Guest (profile null) / renders extremely long name without overflow and with ellipsis / supports dark theme seamlessly |
| [test/relay_map_widgets_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/relay_map_widgets_test.dart) | ทดสอบ relay map widgets; ตัวอย่างกรณี: relay separates intermediary devices from radio hops / unknown route never invents a relay count / offline coordinate diagram is readable on narrow screens |
| [test/settings_panel_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/settings_panel_test.dart) | ทดสอบ settings panel; ตัวอย่างกรณี: flat settings fit a small screen and open the real queue |
| [test/signup_backend_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/signup_backend_test.dart) | ทดสอบ signup backend; ตัวอย่างกรณี: real SDK signup sends PKCE challenge and name before awaiting confirmation |
| [test/sos_cloud_live_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/sos_cloud_live_test.dart) | ทดสอบ sos cloud live; ตัวอย่างกรณี: live authenticated SQLite -> RPC -> pull -> conflict -> delete (ต้องเปิด flag ทดสอบ Cloud จริง; default ข้าม) |
| [test/sos_location_service_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/sos_location_service_test.dart) | ทดสอบ sos location service; ตัวอย่างกรณี: native fresh coordinates preserve accuracy and capture timestamp / timeout diagnostics distinguish no satellites from returned fixes / denied permission never starts native GPS |
| [test/sos_radar_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/sos_radar_test.dart) | ทดสอบ sos radar; ตัวอย่างกรณี: distance uses coordinates in metres / filters range, keeps stale SOS and expires by incident age |
| [test/sos_redesign_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/sos_redesign_test.dart) | ทดสอบ sos redesign; ตัวอย่างกรณี: SOS mobile layout, large text and role navigation |
| [test/sos_screen_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/sos_screen_test.dart) | ทดสอบ sos screen; ตัวอย่างกรณี: SOS can broadcast without recipients but requires confirmation / Rescue card displays SOS details and opens sender chat |
| [test/sos_sync_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/sos_sync_test.dart) | ทดสอบ sos sync; ตัวอย่างกรณี: CRUD and durable queue survive closing and reopening SQLite / active incidents cannot be edited or deleted through history / offline then online drains persistent queue |
| [test/supabase_live_test.dart](D:/3-1/project_keeratiburt/miniProject/rescuelink/test/supabase_live_test.dart) | ทดสอบ supabase live; ตัวอย่างกรณี: live Supabase rejects wrong credentials and anonymous profile access / live member login, installation link, expired session refresh and logout (ต้องเปิด flag ทดสอบ Cloud จริง; default ข้าม) |
| [tool/create_week3_report.py](D:/3-1/project_keeratiburt/miniProject/rescuelink/tool/create_week3_report.py) | สร้าง PDF รายงาน Week 3 ไม่ใช่โค้ด runtime ของแอพ |
| [tool/flutter.ps1](D:/3-1/project_keeratiburt/miniProject/rescuelink/tool/flutter.ps1) | ตัวช่วยเรียก Flutter รองรับ path และโหลด config สำหรับ build/run |
| [web/favicon.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/web/favicon.png) | ไอคอน/ทรัพยากร Flutter web |
| [web/icons/Icon-192.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/web/icons/Icon-192.png) | ไอคอน/ทรัพยากร Flutter web |
| [web/icons/Icon-512.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/web/icons/Icon-512.png) | ไอคอน/ทรัพยากร Flutter web |
| [web/icons/Icon-maskable-192.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/web/icons/Icon-maskable-192.png) | ไอคอน/ทรัพยากร Flutter web |
| [web/icons/Icon-maskable-512.png](D:/3-1/project_keeratiburt/miniProject/rescuelink/web/icons/Icon-maskable-512.png) | ไอคอน/ทรัพยากร Flutter web |
| [web/index.html](D:/3-1/project_keeratiburt/miniProject/rescuelink/web/index.html) | HTML host โหลด Flutter บนเว็บ |
| [web/manifest.json](D:/3-1/project_keeratiburt/miniProject/rescuelink/web/manifest.json) | metadata การติดตั้งเว็บแอพ/ไอคอน |
| [web/sqflite_sw.js](D:/3-1/project_keeratiburt/miniProject/rescuelink/web/sqflite_sw.js) | worker ของ SQLite บนเว็บ |
| [web/sqlite3.wasm](D:/3-1/project_keeratiburt/miniProject/rescuelink/web/sqlite3.wasm) | SQLite engine แบบ WebAssembly ของเว็บ |
| [windows/.gitignore](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/.gitignore) | รายการไฟล์ที่ไม่ให้ Git ติดตาม |
| [windows/CMakeLists.txt](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/CMakeLists.txt) | CMake build ของ Flutter desktop runner |
| [windows/flutter/CMakeLists.txt](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/flutter/CMakeLists.txt) | CMake build ของ Flutter desktop runner |
| [windows/flutter/generated_plugin_registrant.cc](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/flutter/generated_plugin_registrant.cc) | Flutter สร้างรายการลงทะเบียน native plugins อัตโนมัติ ไม่ใช่ logic ฟีเจอร์ที่เขียนเอง |
| [windows/flutter/generated_plugin_registrant.h](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/flutter/generated_plugin_registrant.h) | Flutter สร้างรายการลงทะเบียน native plugins อัตโนมัติ ไม่ใช่ logic ฟีเจอร์ที่เขียนเอง |
| [windows/flutter/generated_plugins.cmake](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/flutter/generated_plugins.cmake) | Flutter สร้างรายการลงทะเบียน native plugins อัตโนมัติ ไม่ใช่ logic ฟีเจอร์ที่เขียนเอง |
| [windows/runner/CMakeLists.txt](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/runner/CMakeLists.txt) | CMake build ของ Flutter desktop runner |
| [windows/runner/Runner.rc](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/runner/Runner.rc) | โค้ด/ทรัพยากร host window และ Flutter desktop runner ไม่ใช่ฟีเจอร์ Cloud หรือ Nearby เพิ่ม |
| [windows/runner/flutter_window.cpp](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/runner/flutter_window.cpp) | โค้ด/ทรัพยากร host window และ Flutter desktop runner ไม่ใช่ฟีเจอร์ Cloud หรือ Nearby เพิ่ม |
| [windows/runner/flutter_window.h](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/runner/flutter_window.h) | โค้ด/ทรัพยากร host window และ Flutter desktop runner ไม่ใช่ฟีเจอร์ Cloud หรือ Nearby เพิ่ม |
| [windows/runner/main.cpp](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/runner/main.cpp) | โค้ด/ทรัพยากร host window และ Flutter desktop runner ไม่ใช่ฟีเจอร์ Cloud หรือ Nearby เพิ่ม |
| [windows/runner/resource.h](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/runner/resource.h) | โค้ด/ทรัพยากร host window และ Flutter desktop runner ไม่ใช่ฟีเจอร์ Cloud หรือ Nearby เพิ่ม |
| [windows/runner/resources/app_icon.ico](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/runner/resources/app_icon.ico) | ไอคอน Windows app |
| [windows/runner/runner.exe.manifest](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/runner/runner.exe.manifest) | โค้ด/ทรัพยากร host window และ Flutter desktop runner ไม่ใช่ฟีเจอร์ Cloud หรือ Nearby เพิ่ม |
| [windows/runner/utils.cpp](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/runner/utils.cpp) | โค้ด/ทรัพยากร host window และ Flutter desktop runner ไม่ใช่ฟีเจอร์ Cloud หรือ Nearby เพิ่ม |
| [windows/runner/utils.h](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/runner/utils.h) | โค้ด/ทรัพยากร host window และ Flutter desktop runner ไม่ใช่ฟีเจอร์ Cloud หรือ Nearby เพิ่ม |
| [windows/runner/win32_window.cpp](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/runner/win32_window.cpp) | โค้ด/ทรัพยากร host window และ Flutter desktop runner ไม่ใช่ฟีเจอร์ Cloud หรือ Nearby เพิ่ม |
| [windows/runner/win32_window.h](D:/3-1/project_keeratiburt/miniProject/rescuelink/windows/runner/win32_window.h) | โค้ด/ทรัพยากร host window และ Flutter desktop runner ไม่ใช่ฟีเจอร์ Cloud หรือ Nearby เพิ่ม |

## ไฟล์เฉพาะเครื่องและผลสร้างที่ไม่ใช่ source

- `config/supabase.local.json`: URL และ public/publishable key ของโปรเจกต์จริง โหลดตอน build/run ไม่แสดงค่า key ในรายงาน.
- `android/local.properties`: path SDK/Flutter เฉพาะเครื่อง.
- `build/`: APK, compiled web, intermediate และ native build outputs; ไม่ใช่ source หลัก.
- `.dart_tool/`, `.flutter-plugins-dependencies`: dependency resolution และ cache/tool metadata.
- `.git/`: ประวัติ repository; `.idea/`, `.vscode/`, `.iml`: ตั้งค่า editor เฉพาะเครื่อง.
- `tmp/` และ `*.log`: หลักฐาน/ผลทดสอบ/ไฟล์ชั่วคราว ไม่ควรนับเป็นฟีเจอร์แอพ.
- OS app data เช่น `accounts.db`, SQLite รายบัญชี, secure storage และสื่อ: เกิดบนอุปกรณ์ขณะใช้งาน ไม่ใช่ไฟล์ฐานข้อมูล production ที่เก็บใน repo.
