# รายงานตรวจ Message Queue / Supabase Sync

## อัปเดตการแก้ไข 11 ตุลาคม 2026

แก้การเชื่อมสถานะหน้าคิวกับผล Cloud Sync แล้ว: `ChatStore` / `SosStore` บันทึกหลักฐานรายเนื้อหาใน settings ของฐานข้อมูลบัญชีเดียวกัน เมื่อ RPC ตอบ `applied` โดย commit พร้อมการลบ operation ออกจากคิว และเมื่อ pull พบ record ที่ยืนยันอยู่บน Cloud จริง หลักฐานเทียบกับเนื้อหาข้อความหรือ SOS revision นั้น จึงไม่ใช้เพียง ID หรือเวลาซิงก์รวม และไม่ถือ `MessageStatus.synced` เก่าเป็นหลักฐาน

`MessageService` รับการเปลี่ยนแปลงหลัง commit แล้วส่ง `cloudSyncedMessageIds` ให้หน้าคิวอัปเดตตัวกรอง จำนวน และสถานะทันที หลักฐานอยู่หลังเปิดแอปใหม่ ขณะที่ `messages.status` ยังคงสถานะ P2P เดิมเพื่อให้ retry/ACK ทำงานต่อ แม้ Cloud สำรองสำเร็จแล้ว รายละเอียดแสดงแยกว่าผู้รับยืนยันหรือยัง

เพิ่ม regression tests ใน `test/queue_cloud_sync_test.dart` และปรับ `test/outbox_queue_test.dart` ครอบคลุม offline, lost reply, conflict, invalid response, exact content, SOS revision/หลายผู้รับ, restart และ live listener รวมถึงการส่งซ้ำหลัง Cloud สำเร็จ การทดสอบใช้ Cloud จำลอง ยังไม่ได้ยืนยันรอบนี้กับ Supabase และอุปกรณ์จริง

รายละเอียดด้านล่างเป็นผล audit ก่อนแก้ไข เก็บไว้เพื่ออธิบายสาเหตุเดิม


วันที่ 9 ตุลาคม 2026 (Asia/Bangkok)

## คำตอบ

**คำว่า “ซิงก์แล้ว” บนหน้าคิวส่งยังใช้ยืนยันไม่ได้ว่า Local Storage ถูกอัปโหลดและบันทึกใน Supabase สำเร็จจริง** หน้านี้อ่าน `messages.status == synced` แต่ Cloud Sync เดิมใช้ `chat_queue` / `sos_queue` และลบ operation เมื่อ RPC ตอบ `outcome=applied` โดยไม่มีการเชื่อมกลับไปตั้ง `messages.status=synced` การสำรอง Cloud สามารถสำเร็จขณะที่ข้อความ P2P ยังรอส่งได้ และผู้รับสามารถ ACK แล้วขณะที่การสำรอง Cloud ยังไม่สำเร็จได้

เส้นทาง RPC/migration แสดงว่าผล applied คืนหลังบันทึก record และ receipt ใน transaction แต่การมีโค้ดใน repository ไม่พิสูจน์ว่า migration นี้ deployed หรือคำขอหนึ่งถูกบันทึกในฐานข้อมูล production แล้ว รอบนี้ตรวจโค้ดและรันเทสต์จำลองเท่านั้น ไม่ได้รัน live write/query บน Supabase

## หลักฐาน

| รายการ | ไฟล์ / บรรทัด | ฟังก์ชัน | หลักฐาน | ผลตรวจ |
|---|---|---|---|---|
| Queue UI | `lib/widgets/outbox_queue.dart:30`; `lib/widgets/outbox_queue.dart:52` | _group / build | รอการยืนยันรวม pending และ sent; ถึงเครื่องรับแล้วนับ delivered; ซิงก์แล้วนับ synced จาก messages เท่านั้น ไม่อ่าน chat_queue หรือ sos_queue | ทำงานแล้ว (widget tests); พบปัญหาในการตีความ Cloud |
| Delivery ACK | `lib/services/message_service.dart:813`; `lib/services/message_service.dart:985` | handleIncomingPayload / _receiveRelayAck | ACK โดยตรงตรวจ id ผู้ส่งและผู้รับก่อนเปลี่ยน delivered; relay ACK ตรวจเส้นทาง/ผู้ส่งเดิม การรับข้อความบันทึก SQLite ก่อนตอบ ACK | ทำงานแล้วใน automated tests; รอ Android สองเครื่อง |
| Supabase Upload | `lib/services/chat_sync_service.dart:18`; `supabase/migrations/20261008054140_chat_history_cloud_sync.sql:70`; `lib/services/sos_sync_service.dart:18` | SupabaseChatCloud.push / SupabaseSosCloud.push / apply_chat / apply_sos | RPC sync_chat และ sync_sos รอผลลัพธ์; migration insert/update record แล้วคืน outcome=applied ใน transaction และเก็บ operation receipt | มีโค้ดแต่ยังไม่ได้ยืนยันกับ Supabase จริงในรอบนี้ |
| Online Detection | `lib/services/chat_sync_service.dart:79`; `lib/services/sos_sync_service.dart:79` | sync | ไม่มี connectivity listener หรือ probe แยก ใช้การเรียก Cloud จริงและ timeout/exception; การมี cloud client ไม่เท่ากับออนไลน์ ส่วน P2P ใช้ connection ของ Nearby เดิม | ยังไม่มี Online Detection แบบแยก; การจับความล้มเหลวมีโค้ดและเทสต์ |
| Retry Sync | `lib/services/chat_sync_service.dart:149`; `lib/services/chat_sync_service.dart:172`; `lib/services/sos_sync_service.dart:149` | ChatSyncCoordinator.start / SosSyncCoordinator.start / didChangeAppLifecycleState | ลองทุก 15 วินาทีขณะแอปทำงาน และเมื่อ resumed; attempts/error เก็บในคิว; ไม่มี network-restored trigger โดยตรง ไม่มีหลักฐาน retry เมื่อระบบปิดแอป | ทำงานแล้วใน simulated tests; background/อุปกรณ์จริงรอตรวจ |
| SYNCED State | `lib/models/message_model.dart:3`; `lib/services/chat_store.dart:174`; `lib/services/local_database_service.dart:578` | ChatStore.acknowledge / LocalDatabaseService.updateMessageStatus | applied ลบเฉพาะ chat_queue operation; ไม่เปลี่ยน messages.status เป็น synced การค้นหา lib ทั้งหมดไม่พบ call ที่ตั้ง MessageStatus.synced; enum และ UI มีแต่ไม่มีการเชื่อมสถานะ Cloud | พบปัญหา: ซิงก์แล้วบน Queue ไม่ใช่หลักฐานการบันทึก Supabase |
| Delivered / Not Synced | `lib/services/message_service.dart:813`; `lib/services/chat_store.dart:34`; `lib/services/chat_sync_service.dart:79` | ACK / capture / sync | P2P เปลี่ยน delivered ได้โดยไม่ต้องมี Cloud; คิวสำรอง private history ยังค้างเมื่อ offline และ ACK ไม่ drain cloud queue; capture เก็บเฉพาะข้อความทั่วไป ไม่ใช่ทุกชนิด | รองรับจากโครงสร้างและเทสต์ offline; รอ Supabase+อุปกรณ์จริง |
| Synced / Not Delivered | `test/chat_sync_test.dart:103`; `lib/services/chat_store.dart:174` | ChatSyncService.sync / ChatStore.acknowledge | เทสต์ยืนยัน queue=0 และ Cloud record version=1 แต่ messages.status ยัง pending; Cloud backup ไม่สร้าง delivery ACK | ทำงานแล้วใน automated simulation; มิใช่ live Supabase test |

## ความหมายที่ต้องแยก

- Local persistence: transaction SQLite สำเร็จ หมายถึงเก็บข้อมูลในเครื่อง
- P2P sent: transport รับคำขอส่ง ไม่ยืนยันเครื่องปลายทาง
- Delivery ACK: ปลายทางบันทึกข้อความและตอบ ACK ตาม identity/route ที่ตรวจสอบได้ ไม่ใช่การรับเคส
- Cloud backup: RPC ตอบ applied และ client acknowledge operation; เป็น private archive ของบัญชี ไม่ส่งข้อความถึงผู้รับแทน P2P
- Case assignment: ยังไม่มี protocol ยืนยันหรือจัดสรรเคสจากผู้แจ้ง การแจ้งสถานะผ่านแชตในงานนี้เป็นข้อความจากผู้ช่วยเหลือเท่านั้น

## ข้อเสนอสำหรับงานถัดไป (ยังไม่ได้แก้)

1. เพิ่มตัวบ่งชี้ Cloud backup แยกจาก P2P delivery ไม่เปลี่ยน delivered เป็น synced จนสูญเสียข้อมูล ACK
2. ให้ Queue UI อ่าน Cloud operation/record receipt ที่สัมพันธ์กับ message ID ก่อนแสดงจำนวนสำรองแล้ว; แยก SOS, media และ plain chat ตาม backend ที่รองรับจริง
3. เพิ่ม network-restored trigger และนโยบาย background ตาม Android หลังตกลงขอบเขต ไม่อ้างว่า timer ขณะแอปเปิดคือ background worker
4. ทดสอบ live ด้วยบัญชีทดสอบและ query record/receipt owner_id + operation_id จริงหลัง RPC applied รวมถึง lost-response/retry/conflict
5. แยก schema/สิทธิ์สำหรับ Case acceptance และ acknowledgement ของผู้แจ้งในงานที่อนุญาตเปลี่ยน protocol/backend

## ตรวจขอบเขตที่ห้ามแก้

เทียบเนื้อหากับ Git HEAD โดยไม่นับรูปแบบ newline ของ Windows:

| ไฟล์ | ผล |
|---|---|
| `lib/services/nearby_service.dart` | ไม่เปลี่ยน |
| `lib/services/message_service.dart` | ไม่เปลี่ยน |
| `lib/services/local_database_service.dart` | ไม่เปลี่ยน |
| `lib/services/chat_store.dart` | ไม่เปลี่ยน |
| `lib/services/chat_sync_service.dart` | ไม่เปลี่ยน |
| `lib/services/sos_store.dart` | ไม่เปลี่ยน |
| `lib/services/sos_sync_service.dart` | ไม่เปลี่ยน |
| `lib/widgets/outbox_queue.dart` | ไม่เปลี่ยน |
| `lib/screens/sync_screen.dart` | ไม่เปลี่ยน |

ส่วน `_buildHomeTab()` และ `_buildQueue()` ภายใน `lib/screens/nearby_test_screen.dart` เทียบแล้วเหมือนเดิม; ไฟล์นี้เปลี่ยนเฉพาะการเชื่อมแท็บ Messages/SOS/Profile, การใช้ display name ของโปรไฟล์ และย้ายส่วน Messages ออกเป็นหน้าของตัวเอง ไม่มีการแก้ schema หรือ migration
