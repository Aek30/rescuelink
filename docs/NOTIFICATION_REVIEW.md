# การปรับปรุงการแจ้งเตือน RescueLink

วันที่ตรวจ: 22 ตุลาคม 2026

## พฤติกรรมที่ปรับ

1. แยก `chatAlerts` และ `sosAlerts` ค่าเริ่มต้นเปิดทั้งคู่ ย้ายค่าเดิมที่เก็บใน `sosAlerts` ไปเป็นค่าแชตครั้งเดียว ภายใน transaction ส่วน SOS เริ่มเปิด ผู้ใช้ต้องยืนยันก่อนปิด SOS
2. ตรวจสิทธิ์ก่อนส่งแจ้งเตือน Android แสดงสถานะและปุ่มขอสิทธิ์ในหน้าการเชื่อมต่อและสิทธิ์ Manifest มี `POST_NOTIFICATIONS` อยู่แล้ว และเพิ่ม `VIBRATE`
3. ใช้ Channel `rescue-sos-v3` พร้อมเสียงปลุก สั่นยาว ไฟ และแสดง SOS บนหน้าจอล็อก ส่วน `rescue-chat-v3` ใช้การแจ้งเตือนปกติ สร้าง Channel ตอน configure engine และอัปเดตชื่อจากภาษาที่เลือกใน Dart
4. ไม่สร้าง notice ของแชตหรือสื่อจาก peer ที่เปิดแชตอยู่ SOS ยังผ่านเส้นทางแจ้งเตือนตามสวิตช์ SOS และโหมดช่วยเหลือ
5. การอ่านแชตสำเร็จส่ง callback ลบแจ้งเตือนของคู่สนทนา ส่วน SOS revision ใหม่ที่ยกเลิกส่ง callback ลบของ incident นั้น แม้ปิดสวิตช์ SOS อยู่ ลบแบนเนอร์ที่ค้างด้วย
6. ใช้ key `chat:<peerId>` และ `sos:<incidentId>` เหมือนกันทั้งตอนสร้างและลบ ข้อความใหม่แทนรายการเดิม แชตหลาย unread แสดงจำนวน ส่วนแบนเนอร์รวมรายการของคู่สนทนาหรือ incident เดียวกัน
7. ไอคอนข้อความแสดง Badge ตาม totalUnread สูงสุด `99+`
8. ลบ native route `alert` และ `mediaAlert` ที่ไม่มีการเรียกในแอป ให้สื่อผ่าน `notify` และแตะเพื่อเปิดแชตผู้ส่ง ซ่อนเนื้อหาแชตบนหน้าจอล็อก ส่งชื่อ Channel และปุ่มจาก Dart ตามภาษา

ไม่เปลี่ยน logic relay, ACK หรือ SOS publish และรักษาการแก้ไขเดิมของ workspace ไว้

ตอนเปิดแอปยังใช้แบนเนอร์โดยไม่มีเสียงเพิ่มเติม เสียง SOS ที่เพิ่มอยู่ใน Android notification ตอนพักแอป ไม่ใช่เสียงไซเรนวนซ้ำ

## ไฟล์

- `lib/services/app_preferences.dart`: สวิตช์และ migration
- `lib/services/message_service.dart`: กรอง notice, active peer และ callback ลบ
- `lib/services/connection_session.dart`: สิทธิ์, notify, cancel และข้อความแปลภาษา
- `lib/screens/settings_panel.dart`: สวิตช์และกล่องยืนยัน
- `lib/screens/nearby_test_screen.dart`: สถานะสิทธิ์, รวมแบนเนอร์, callback และ Badge
- `lib/screens/chat_screen.dart`: ตั้ง/ล้าง active peer
- `lib/models/incoming_notice.dart`: key คงที่
- `lib/l10n/app_strings.dart`: คำแปลข้อความใหม่
- `android/app/src/main/kotlin/com/rmutt/rescuelink/MainActivity.kt`: Channel, การสร้าง/ลบ notification และความเป็นส่วนตัว
- `android/app/src/main/AndroidManifest.xml`: สิทธิ์สั่น
- `android/app/src/main/res/drawable/ic_stat_rescuelink.xml`: ไอคอนชั่วคราว
- `test/notification_service_test.dart`: เทสต์ใหม่ 8 ข้อ

## ผลตรวจ

- `flutter analyze lib test`: ไม่พบปัญหา
- `flutter analyze --no-fatal-infos`: ไม่มี error/warning เหลือ info เดิม 6 รายการใน `third_party/video_thumbnail`
- `flutter test`: ผ่าน 277 ข้อ ข้าม 5 ข้อ ไม่ผ่าน 3 ข้อที่คาดหวังข้อความ UI ของคิวส่ง แผนที่ และสถานะ SOS ไม่ตรงกับ UI ปัจจุบัน ดู `output/notification-tests-final.log`
- เทสต์ใหม่ 8 ข้อผ่าน รวมปิดแชตแล้วยังรับ SOS, ไม่แจ้งในแชตที่เปิดอยู่, ยกเลิก SOS แล้วลบแจ้งเตือน, แยกสวิตช์อีกด้าน, ลบเมื่ออ่าน, ID คงที่ และ migration
- ตรวจ Kotlin และ Android resources ของ arm64 ผ่าน (`BUILD SUCCESSFUL`) ด้วย `:app:compileDebugKotlin -x :app:compileFlutterBuildDebug -Ptarget-platform=android-arm64 --offline` ผลอยู่ใน `output/notification-kotlin-build-arm64.log` มีคำเตือน deprecation ของ API รองรับ Android รุ่นเก่าและปลั๊กอินเดิม
- ยังไม่ได้สร้าง APK ใหม่สำเร็จ: การ build APK ทุกสถาปัตยกรรมค้างก่อน compile Kotlin ส่วนรอบ offline ยืนยันว่าขาด Flutter engine ของ x86_64 และ armeabi_v7a จึงตรวจ compile เฉพาะ arm64 ที่มีแคชแทน

เทสต์ UI ที่ยังไม่ผ่าน:

- `outbox_queue_test.dart`: คาดหวัง `รูปภาพ: photo.png`
- `phase_4_widgets_test.dart`: คาดหวังปุ่มข้อความแผนที่แบบเดิม
- `sos_redesign_test.dart`: คาดหวัง `มีผู้รับแล้ว 1 เครื่อง`

ไม่ได้แก้พฤติกรรม UI เหล่านี้เพื่อให้เทสต์ผ่าน เพราะอยู่นอกขอบเขตแจ้งเตือน

ไฟล์ test runner เก่าที่อ้างถึงเทสต์ที่ไม่มีแล้วถูกย้ายจาก `tmp/flutter_tools.*` ไปเก็บใน `.build-tools/stale-test-runners` เพื่อไม่ให้ analyzer ตรวจไฟล์ generated ที่หมดอายุ

## สิ่งที่ต้องทำบนเครื่องจริง

1. เปลี่ยน `ic_stat_rescuelink.xml` เป็นไอคอน RescueLink จริง สีขาว พื้นโปร่งใส ขนาด 24dp ปัจจุบันเป็นรูปกากบาทชั่วคราว
2. ติดตั้งรุ่นใหม่บน Android 13+ ทดสอบอนุญาต/ปฏิเสธสิทธิ์ และกลับจากการตั้งค่า ตรวจว่าสถานะอัปเดตและไม่เกิดข้อผิดพลาดเมื่อสิทธิ์ถูกปิด
3. ใช้โทรศัพท์สองเครื่อง เปิดโหมดช่วยเหลือบนผู้รับ ทดสอบ SOS ใหม่ แก้ไข และยกเลิก ทั้งขณะเปิดแอป สลับแอป และดับหน้าจอ
4. ตรวจว่า SOS ใช้เสียงปลุกและสั่นตามการตั้งค่าระบบ ส่วนแชตใช้เสียงปกติ ตรวจโหมดเงียบ/ห้ามรบกวนด้วย การตั้งค่าผู้ใช้และความสามารถของเครื่องยังเป็นตัวกำหนดเสียง การสั่น และไฟ
5. ตรวจว่าแชตหลายข้อความจากคนเดิมมีแจ้งเตือนเดียวพร้อมจำนวน อ่านแล้วหาย คู่สนทนาอื่นมีรายการแยก และสื่อแตะแล้วเปิดแชตผู้ส่ง
6. ตรวจหน้าจอล็อก: แชตแสดงเพียงข้อความใหม่ SOS แสดงรายละเอียด ตรวจ Badge ที่ 0, 1 และมากกว่า 99
7. ตรวจภาษาไทยและอังกฤษ โดยเฉพาะชื่อ Channel และปุ่มดู SOS/เปิดแชต ตรวจเปิดแชตซ้อนแล้วการปิดหน้าหนึ่งไม่ล้างค่า active peer ของอีกหน้า

อ้างอิงข้อจำกัดการตั้งค่าเสียง/ความสำคัญของ Channel หลังสร้าง: [Android NotificationChannel](https://developer.android.com/reference/android/app/NotificationChannel)
