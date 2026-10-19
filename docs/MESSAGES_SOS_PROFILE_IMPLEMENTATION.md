> อัปเดต 19 ต.ค. 2569: นำระบบรับเคส/กำลังช่วยเหลือ/เสร็จสิ้นและ ResponderStore ออกแล้ว หน้ากู้ภัยเหลือเปิด–ปิด Rescue ดู SOS/พิกัด และติดต่อผู้แจ้งผ่านแชต รายละเอียดเกี่ยวกับรับเคสด้านล่างเป็นบันทึกการทำงานรุ่นเดิม

# รายงาน Messages, SOS และ Profile

วันที่ 9 ตุลาคม 2026 (Asia/Bangkok)

## ผลงานที่ดำเนินการ

พัฒนาต่อยอดจากระบบ Flutter เดิมโดยใช้ MessageService, LocalDatabaseService, ChatScreen, SosStore, Location service, Auth และ Supabase profiles เดิม ไม่มีการเปลี่ยนฐานข้อมูลหรือ migration และไม่มีการแก้ Message Queue/Cloud Sync/Nearby transport

- Messages: รายการสัมพันธ์กับข้อความจริง ไม่แสดง peer ที่ไม่เคยสนทนาแทน conversation; ค้นหาชื่อและ unread filter, เวลาล่าสุด, ชื่อจาก peer history/identity, ป้าย SOS, สถานะรอส่งและการเชื่อมต่อ เปิดประวัติเดิมแบบ offline
- SOS: เป็นแท็บหลัก ไม่มี back หรือ segmented role control; เลือกน้ำท่วม/ไฟไหม้/อุบัติเหตุ/การแพทย์/ติดในพื้นที่อันตราย/อื่น ๆ และคงอาหาร/น้ำจากระบบเดิม ส่งโดยไม่มี GPS ได้หลังยืนยัน มี active status card และเปิด editor ผ่านเพิ่มข้อมูล ส่งซ้ำด้วย retry ของ event เดิม ยกเลิกพร้อมเหตุผลและ cancellation revision เดิม
- Responder: เข้าได้จากฉัน; switch พร้อมรับเหตุแยกจากการยืนยันหน่วยงาน; dashboard/filter/list/detail ใช้เหตุที่รับและบันทึกจริง; รับเคสแบบรอยืนยัน มี local work notes กำลังช่วยเหลือ/เสร็จสิ้น ส่งข้อความแจ้งกลับด้วยคิวแชตเดิมและป้องกันกดซ้ำ
- Profile: ชื่อแสดงเด่นกว่าอีเมล ใช้กับการสื่อสารโดยไม่เปลี่ยน peer UUID; cloud read/update ผ่าน repository เดิม มีชื่อ draft ในเครื่องสำหรับ offline และระบุชัดว่ายังไม่บันทึกบน Cloud ต้องกด cloud save เมื่อออนไลน์
- Settings: ไทย/English ใช้ AppPreferences และ resources กลาง; เก็บค่าหลังเปิดใหม่; system/light/dark ผ่าน theme เดิม; แจ้งเตือนภายในแอปผ่าน preference เดิม; confirmation ก่อน sign out โดยไม่ลบประวัติ/คิวของบัญชี

## ไฟล์และฟังก์ชัน

| ไฟล์ | ฟังก์ชัน / ส่วนหลัก | หน้าที่ |
|---|---|---|
| `lib/screens/messages_screen.dart` | `MessagesScreen / build` | รายการจากประวัติจริงเท่านั้น เรียง displayTime ล่าสุด ค้นหาชื่อ กรอง unread แสดงเวลาข้อความ สถานะรอส่ง ป้าย SOS และเปิด ChatScreen ด้วย peerId เดิม; empty state ไป Nearby |
| `lib/screens/sos_screen.dart` | `_categoryPicker / _send / _cancel / build` | SOS mainTab ไม่มี back/segmented control, ฟอร์ม 6 ประเภทตามคำขอและคงอาหาร/น้ำเดิม, GPS จาก service เดิม, เหตุปัจจุบัน/เพิ่มข้อมูล/ส่งซ้ำ/ยกเลิกพร้อมเหตุผล, แสดงสถานะตาม packets จริง |
| `lib/screens/responder_screen.dart` | `incidents / _refresh / _detail / _run` | Dashboard จาก remote SOS ที่บันทึกจริง + messages + presence, switch พร้อมรับเหตุ, ตัวกรอง, รายละเอียดและ GPS, รับเคสรอยืนยันและบันทึกการช่วยเหลือ, ติดต่อผู้แจ้งผ่าน chat |
| `lib/services/responder_store.dart` | `read / update / notifyReporter` | บันทึก responder/owner/incident/time/stage ใน settings ของบัญชีเดิม; กันรับซ้ำและเหตุที่ยกเลิก; ส่งข้อความสถานะผ่าน MessageService เดิม โดยไม่สร้าง queue หรือ protocol ใหม่ |
| `lib/screens/settings_panel.dart` | `build` | ชื่อโปรไฟล์/อีเมล/บทบาทผู้ช่วยเหลือที่ยังไม่ยืนยัน, เมนูหน่วยกู้ภัย→ภาษา→ธีม→แจ้งเตือน, ตัวเลือก system/light/dark, preference แจ้งเตือนร่วมที่ระบบเดิมรองรับ, sign out confirmation |
| `lib/screens/member_screen.dart` | `_load / _save / _signOut` | อ่านข้อมูลบัญชีจริงและ cache ชื่อ, offline name draft แยกจาก cloud save, validation, ยืนยัน sign out และใช้ก่อนออกจากบัญชีเดิม; คงเมนูข้อมูลสุขภาพและลบบัญชีเดิม |
| `lib/services/member_service.dart` | `SupabaseMemberRepository.read / updateName` | reuse Supabase profiles เดิม, cache displayName ในฐานข้อมูลบัญชีหลัง cloud response, ตรวจบัญชีไม่เปลี่ยน และจำกัดชื่อใหม่ 80 ตัวอักษรให้ใช้กับ SOS/identity เดิมได้ |
| `lib/services/app_preferences.dart` | `load / text / setTheme / saveLocalName` | เก็บ locale/theme/notifications/draft ใน settings เดิม แยกบัญชีตาม LocalDatabaseService.instance; ใช้ระบบ t เดิมกับ resources ส่วนกลาง |
| `lib/l10n/app_strings.dart` | `appEnglish` | resources อังกฤษส่วนกลางสำหรับหน้าใหม่และส่วนที่ปรับ พร้อม key ภาษาไทย ใช้ AppPreferences เดิม ไม่มี translation service ใหม่ |
| `lib/main.dart` | `RescueLinkApp.build` | ใช้ ThemeMode.system/light/dark จาก preference เดิม |
| `lib/screens/nearby_test_screen.dart` | `build / _buildSettingsTab / _profileNameChanged` | เชื่อม MessagesScreen, SOS เป็นแท็บหลัก, Responder จากฉัน และชื่อบัญชีสำหรับการประกาศตัวตน; UUID, Nearby transport, UI หน้า Nearby และ Queue builder คงเดิม |

ไฟล์ทดสอบที่ปรับ: `test/sos_screen_test.dart`, `test/sos_redesign_test.dart`, `test/dark_theme_test.dart`, `test/settings_panel_test.dart`, `test/member_repository_test.dart` เพื่อรองรับโครงสร้างหน้าใหม่และ local cache

ไฟล์ทดสอบใหม่: `test/messages_responder_settings_test.dart` ตรวจ conversation history/search/unread/sort, case duplicate/durable local record/offline chat queue, locale/theme/name reload และ navigation ห้าแท็บใน route เดียว

## ผลตรวจจริง

| การตรวจ | ผล | หลักฐาน |
|---|---|---|
| Flutter analyze --no-pub | ผ่าน ไม่มี issues | `tmp/features-analyze.log` |
| Flutter tests ทั้งชุด | ผ่าน 174 รายการ ข้าม 5 รายการ ไม่พบ failures | `tmp/features-tests-final.log` |
| เทสต์ส่วนที่แก้หลังจัดหน้าสุดท้าย | ผ่าน 11 รายการ | `tmp/features-targeted.log` |
| เทสต์เพิ่มการนำทางและ regression ของหน้าที่เพิ่ม | ผ่าน 4 รายการ รวม navigation ใหม่ 1 รายการ | `tmp/features-navigation.log` |
| Android debug APK พร้อม config Supabase เดิม | build สำเร็จ | `tmp/features-android-build.log`; `build/app/outputs/flutter-apk/app-debug.apk` |
| Protected code | 9 ไฟล์เดิมไม่เปลี่ยน รวม transport, MessageService, schema และ Cloud Sync; home/queue builders เดิม | `docs/MESSAGES_SOS_PROFILE_QUEUE_AUDIT.md` |
| Diff whitespace | ผ่านเมื่อใช้ cr-at-eol สำหรับไฟล์ Windows ที่มี CRLF เดิม | `tmp/features-diff-check.log` |

เทสต์ Cloud ที่ถูกข้ามต้องเปิด flag และตั้งค่าบัญชี/บริการภายนอก ผลเทสต์ทั้งหมดข้างต้นไม่ใช่หลักฐานว่ารัน P2P ระหว่างโทรศัพท์จริงหรือเชื่อม production Supabase แล้ว

## ข้อจำกัดที่แสดงตามความจริง

1. **ยังไม่มีการยืนยันจัดสรรเคสจากผู้แจ้ง**: การรับเคสเป็น local request ที่รอยืนยัน การแจ้งผ่านข้อความ P2P/ACK ยืนยันได้เพียงรับข้อความ ไม่ยืนยัน exclusivity หรือ consent การกำลังช่วยเหลือ/เสร็จสิ้นเป็น work note ของผู้ช่วยเหลือ ไม่เลื่อนสถานะ SOS ของผู้แจ้งโดยอัตโนมัติ
2. **ยังไม่มีหลักฐานยืนยันหน่วยกู้ภัยใน transport เดิม**: rescueMode เป็นความพร้อมช่วยเหลือ UI จึงแสดงผู้ช่วยเหลือทั่วไป/หน่วยงานยังไม่ยืนยัน ไม่สร้างตรายืนยันจาก switch; ไม่ดึงข้อมูลสุขภาพ โทรศัพท์ หรืออีเมลของผู้แจ้งมาแสดงใน incident
3. **ประเภทเหตุใหม่คงรูปแบบข้อมูลเดิม**: น้ำท่วม/ไฟไหม้/อุบัติเหตุใช้ category=other และเพิ่มชื่อประเภทในรายละเอียด เช่น `[น้ำท่วม] ...` เพื่อให้เครื่องรุ่นเดิมและ Cloud schema อ่านได้ ไม่เพิ่ม enum/protocol/schema โดยไม่จำเป็น ประเภทใหม่จึงปรากฏเป็นอื่น ๆ ในมุมมองเก่าบางส่วนพร้อมชื่อจริงในรายละเอียด
4. **Cloud backup ของ Queue ยังไม่เชื่อมกับ synced enum**: รายละเอียดและข้อเสนออยู่ในรายงาน audit แยก ไม่แก้ตามข้อห้าม
5. **การแจ้งเตือนมีหนึ่ง preference ร่วมกัน**: เปิด/ปิดใช้กับ notice ที่ service เดิมรองรับ ไม่มี notification categories แยก, Push Notification หรือ case-confirmation notification ปลอม
6. **Offline profile draft ไม่ส่ง Cloud อัตโนมัติ**: มีการบันทึกในเครื่องและใช้ชื่อเพื่อสื่อสาร ต้องกดบันทึกข้อมูลสมาชิกเมื่อออนไลน์ ไม่มี sync queue โปรไฟล์ใหม่
7. **เวลา SOS ใน protocol เป็น updatedAt**: แสดงเวลาข้อมูลจากผู้แจ้งที่มีจริง ไม่มีการสร้างเวลาสร้างเหตุย้อนหลังหากระบบเดิมไม่ได้เก็บแยกจาก revision update
8. **ชื่อที่ใช้กับ SOS จำกัด 80 ตัวอักษรตามโมเดลเดิม**: validation ชื่อใหม่สอดคล้องกับข้อจำกัดนี้ รูป avatar/ข้อมูลส่วนตัวอื่นใช้หน้าข้อมูลส่วนตัวและสุขภาพที่มีอยู่ ไม่สร้าง storage/schema รูปภาพใหม่
9. การแปลครอบคลุม label ของหน้าที่ปรับและการตั้งค่าที่บันทึกไว้ แต่ข้อความ/ข้อผิดพลาดจาก service และ widgets เดิมบางส่วน รวมถึงหน้าที่ไม่ได้อยู่ในงานนี้ อาจยังเป็นภาษาไทย

## ต้องทดสอบเพิ่มเติมบน Android สองเครื่อง

สถานะทั้งหมดต่อไปนี้: **รอทดสอบบนอุปกรณ์จริง**

1. เปิด airplane mode แล้วเปิด Bluetooth/Wi‑Fi ที่ Nearby ต้องใช้ ค้นหา/เชื่อมต่อเดิม ส่งข้อความแล้วตรวจ pending→sent→delivered หลังปลายทางบันทึกจริง
2. ปิดแอปและเปิดใหม่ ตรวจประวัติ การเรียง unread markers และชื่อ peer; เปลี่ยนชื่อโปรไฟล์แล้วตรวจว่า UUID/history ยังผูกกับคนเดิม
3. ส่ง SOS ทุกประเภท มี/ไม่มี GPS; ปิดสิทธิ์ GPS/ปิด location service ตรวจสาเหตุและยืนยันส่งไม่มีพิกัด; ตรวจ accuracy/capturedAt จริง
4. Disconnect แล้ว retry SOS ให้ event ID เดิม reconnect ตรวจเหตุและ revision ไม่ซ้ำ ยกเลิกพร้อมเหตุผลให้ปลายทางเห็นข้อมูลยกเลิกเมื่อรับ revision จริง
5. เปิดพร้อมรับเหตุจากฉัน ตรวจว่าไม่เกิดตรายืนยัน agency; รับเคสใน offline ตรวจ local pending และข้อความแจ้งผ่าน queue; reconnect ตรวจ receipt เฉพาะข้อความ
6. ช่วยเหลือ/เสร็จสิ้น ตรวจบันทึกในเครื่องและข้อความแจ้ง ไม่อ้างว่า authoritative assignment; จำลองกดซ้ำและเหตุถูกยกเลิกก่อนกดรับ
7. เปลี่ยน theme/locale/notice preference เปิดแอปใหม่; theme ตามระบบบน Android จริง; ปิด notice แล้วตรวจไม่มี in-app banner ตาม service ที่รองรับ
8. Sign out/sign in บัญชีอีกคน ตรวจว่า chat/SOS/queue/draft/settings ของเดิมไม่ปรากฏในบัญชีใหม่ แต่ประวัติเดิมกลับมาหลังเข้าสู่บัญชีเดิม
9. Supabase live: ตรวจ actual records และ operation receipts หลัง RPC applied ทั้ง delivered/not backed-up และ backed-up/not delivered, conflict/retry/lost response และสิทธิ์ owner

## ปัญหาที่พบและคำแนะนำ

- จัดลำดับต่อไปตาม audit: แยก Cloud backup state ออกจาก P2P delivery และเพิ่ม protocol สำหรับ authoritative case confirmation เมื่ออนุญาตแก้ backend/protocol/queue
- Android build มี warning จาก plugin `location` ที่ใช้ Kotlin Gradle Plugin และ native-access warning ของ toolchain; build รอบนี้สำเร็จ ควรวางแผนอัปเกรด plugin/toolchain เมื่อทำงานส่วน dependency แยก ไม่เปลี่ยนในงานนี้
- ไม่มีการลบข้อมูลผู้ใช้หรือประวัติในงานนี้ การลบที่อยู่ใน automated tests ใช้ฐานข้อมูล/บัญชีจำลองแยกจากข้อมูลผู้ใช้

รายงาน Queue/Supabase พร้อมตาราง path/function/line จริง: [MESSAGES_SOS_PROFILE_QUEUE_AUDIT.md](MESSAGES_SOS_PROFILE_QUEUE_AUDIT.md)
