# SOS redesign — 2026-09-27

ปรับเฉพาะหน้า SOS ใน Flutter ตามภาพที่ผู้ใช้ส่ง ไม่แก้ service หรือข้อมูลเดิม

- พื้นเทาอ่อน การ์ดขาว มุมมน และสีส้มเป็นจุดเน้น
- แยกแท็บขอความช่วยเหลือ/หน่วยกู้ภัย การเปลี่ยนแท็บไม่เปิด Rescue โดยอัตโนมัติ
- เลือกประเภทเหตุด้วยการ์ดไอคอน 4 แบบแทน dropdown
- แบ่งแบบฟอร์มเป็นประเภทเหตุ ข้อมูลผู้ขอ และตำแหน่ง
- ยุบผู้รับเพิ่มเติมและรายละเอียดระบบเพื่อลดข้อความบนหน้าหลัก
- คง GPS, validation, การยืนยันส่ง, แก้ไข/ยกเลิก SOS, ผู้รับเดิม, สถานะส่ง และแชตจากคำขอ

## ตรวจสอบ

- flutter analyze: ผ่าน
- flutter build apk --debug: ผ่าน; build/app/outputs/flutter-apk/app-debug.apk
- SOS tests เดิมและ layout/role navigation test ใหม่: ผ่าน 3 tests
- ทดสอบ layout 390 × 844 และ 320 × 700 พร้อมตัวอักษร 150% ไม่พบ exception
- ภาพใน ui-audit/sos-redesign.png และ sos-redesign-details.png เรนเดอร์ด้วย Flutter widget test และข้อมูลทดสอบ ไม่ใช่ภาพจากโทรศัพท์จริง
- สร้างภาพซ้ำ: flutter test test/sos_redesign_test.dart --dart-define=UX_CAPTURE=true
- ยังต้องตรวจสัมผัส/คีย์บอร์ด/GPS/การรับส่งบนโทรศัพท์จริง
