# การปรับแท็บ SOS

- [lib/screens/sos_screen.dart](C:/MILK/3-1/rescuelink/lib/screens/sos_screen.dart): ฟอร์ม SOS: เลือกหลายเหตุ, ปุ่มส่งติดล่าง, จำนวนคน, ตำแหน่ง, ผู้รับ, ส่งซ้ำ/ยกเลิก
- [lib/widgets/sos_status_card.dart](C:/MILK/3-1/rescuelink/lib/widgets/sos_status_card.dart): การ์ดสถานะและ progress 3 ขั้น ตรวจ ACK และแยกสถานะยกเลิก
- [lib/widgets/sos_confirmation_dialog.dart](C:/MILK/3-1/rescuelink/lib/widgets/sos_confirmation_dialog.dart): bottom sheet ยืนยัน: หัว/ปุ่มคงที่ เนื้อหาเลื่อนและอัปเดตพิกัดเก่า
- [lib/widgets/emergency_type_chip.dart](C:/MILK/3-1/rescuelink/lib/widgets/emergency_type_chip.dart): chip ประเภทเหตุ การ์ดร่วม อายุพิกัด และคำเตือนพิกัดเก่า
- [lib/widgets/sos_location_card.dart](C:/MILK/3-1/rescuelink/lib/widgets/sos_location_card.dart): แผนที่ย่อ 132dp เปิดปรับหมุดเต็มจอ คัดลอก/เปิดพิกัด
- [lib/widgets/bundled_offline_map.dart](C:/MILK/3-1/rescuelink/lib/widgets/bundled_offline_map.dart): รับการแตะเลือกพิกัด โหมดแผนที่ย่อ และ tooltip ปุ่มแผนที่
- [lib/models/sos_alert.dart](C:/MILK/3-1/rescuelink/lib/models/sos_alert.dart): ประเภทเหตุหลายรายการและ flag ตำแหน่งที่ปักเอง; อ่าน JSON เก่าได้
- [lib/services/message_service.dart](C:/MILK/3-1/rescuelink/lib/services/message_service.dart): ส่ง/ยกเลิกพร้อมประเภททั้งหมด และติดตามการประกาศ P2P จริง
- [lib/services/sos_store.dart](C:/MILK/3-1/rescuelink/lib/services/sos_store.dart): คงประเภททั้งหมดเมื่อแก้ข้อมูลขัดแย้ง
- [lib/screens/my_sos_screen.dart](C:/MILK/3-1/rescuelink/lib/screens/my_sos_screen.dart): แสดง/แก้หลายประเภทในประวัติ SOS
- [lib/theme/rescue_theme.dart](C:/MILK/3-1/rescuelink/lib/theme/rescue_theme.dart): token kSosRed = #B82E37 (ผ่าน AA กับข้อความขาว)
- [lib/screens/nearby_test_screen.dart](C:/MILK/3-1/rescuelink/lib/screens/nearby_test_screen.dart): ใช้ kSosRed ที่ไอคอน SOS ของ bottom nav
- [lib/widgets/presence_list.dart](C:/MILK/3-1/rescuelink/lib/widgets/presence_list.dart): การ์ดคนที่ต้องการความช่วยเหลือใช้ EmergencyTypeChips ร่วม
- [lib/widgets/sos_radar.dart](C:/MILK/3-1/rescuelink/lib/widgets/sos_radar.dart): การ์ดใกล้ฉันใช้ EmergencyTypeChips ร่วม
- [lib/screens/responder_screen.dart](C:/MILK/3-1/rescuelink/lib/screens/responder_screen.dart): ฝั่งผู้รับแสดงประเภทจาก categories
- [lib/screens/messages_screen.dart](C:/MILK/3-1/rescuelink/lib/screens/messages_screen.dart): ข้อความตัวอย่าง SOS ใช้ categoriesLabel
- [lib/widgets/outbox_queue.dart](C:/MILK/3-1/rescuelink/lib/widgets/outbox_queue.dart): คิวส่งแสดงประเภทจาก categories
- [lib/models/incoming_notice.dart](C:/MILK/3-1/rescuelink/lib/models/incoming_notice.dart): การแจ้งเตือนใช้ประเภทจาก categories

## ข้อมูลที่เพิ่ม

- `SosAlert.categories: List<EmergencyType>` เป็นรายการแก้ไขไม่ได้ และตัด `other` หากมีประเภทเฉพาะ; เพิ่ม `flood`, `fire`, `accident`. `category` เดิมยังเป็น getter สำหรับโค้ดเก่า
- `SosLocation.manuallySelected: bool` ค่าเริ่มต้น false; พิกัดที่ปักเองแสดง “ปักหมุดเอง” แทนการอ้างความแม่นยำ GPS ±0
- เก็บทั้งสอง field ใน JSON เดิม ไม่เพิ่มตาราง/คอลัมน์หรือเปลี่ยน schema version
- wire category เดิมยังใช้ medical/trapped/supplies/other เพื่อรองรับ cloud constraint และแอปรุ่นเดิม; แอปที่อัปเดตอ่านประเภทจริงจาก categories ไม่ได้อ่านจากรายละเอียด
- JSON ของเหตุเก่าแบบประเภทเดียวคงรูปแบบเดิมเพื่อรักษา sync receipt เดิม

## การใช้งาน

- เริ่มต้นไม่เลือกประเภทอัตโนมัติ: เลือกเหตุ → ส่ง SOS → ยืนยัน (3 แตะ)
- อ่าน GPS อัตโนมัติเมื่อไม่มีพิกัดหรือเก่ากว่า 5 นาที โดยไม่ปิดปุ่มส่งระหว่างรอ
- แผนที่ออฟไลน์ปรับหมุดได้ในพื้นที่ข้อมูลที่แอปมี; นอกพื้นที่ยังใช้/คัดลอกพิกัด GPS ได้
- ข้อมูลตำแหน่งที่ผู้ใช้เห็นในหน้ายืนยันเป็น snapshot; GPS ที่มาทีหลังไม่เปลี่ยนพิกัดที่ส่งเงียบ ๆ
- จำนวนคน 1–999; รายละเอียดไม่เกิน 1,000 ตัวอักษรตาม model เดิม (970 เดิมเผื่อ prefix ประเภทเหตุ ซึ่งเลิกใช้แล้ว)
- กดค้างปุ่มซูมออกเพื่อกลับไปดูทั้งพื้นที่
- ยังคงคิวออฟไลน์ P2P ส่งซ้ำ ยกเลิกพร้อมเหตุผล ประวัติ และการซิงก์เดิม

## ขอบเขตการตรวจ

ทดสอบ widget/model/SQLite/คิวและเครือข่ายจำลอง รวมถึงธีมสว่าง/มืด จอ 320dp ตัวอักษร 150% และคีย์บอร์ด ไม่ได้ทดสอบ GPS หรือการส่ง Nearby บนโทรศัพท์จริงในงานนี้

## ผลตรวจ

- Flutter tests ที่เกี่ยวข้อง 98 รายการผ่านทั้งหมด
- flutter analyze --no-pub lib test: No issues found
- ภาพตัวอย่างจาก widget จริง: form.png, form-sticky.png, form-dark.png, status.png และ ../sos-confirmation-light.png / dark.png
