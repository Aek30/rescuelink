# Phase 4 — ผลการทำงานและหลักฐาน

ตรวจวันที่ 30 กันยายน 2026 (Asia/Bangkok)

สถานะ: โค้ด, automated tests, Cloud จริง และ Android build ผ่านแล้ว แต่ยังไม่ปิด Phase 4 เพราะยังไม่มีหลักฐานส่งสื่อและแจ้งเตือนจากโทรศัพท์ Android สองเครื่องจริง ไม่มี Android เชื่อมต่อกับเครื่องพัฒนาในรอบนี้ และยังไม่รับรองสื่อผ่าน Multi-hop

## สิ่งที่เพิ่มและแก้ไข

- รูป/วิดีโอผ่านลิงก์ Nearby โดยตรง เก็บไฟล์ถาวรแยกตามตัวตนในเครื่องและ metadata ใน SQLite รุ่น 4
- ผู้รับต้องได้ทั้ง metadata และ FILE SUCCESS ก่อนตรวจขนาด/SHA-256 และบันทึกข้อความ/metadata แบบ transaction แล้วส่ง ACK ผู้ส่งเปลี่ยนเป็น delivered ได้เมื่อรับ ACK จาก peer ที่ตรงกันเท่านั้น
- รับ FILE/metadata สลับลำดับได้; ACK หายมี timeout; retry ใช้ mediaId/messageId เดิม; หลัง restart รายการที่ส่งค้างกลับเป็น paused และรายการรับไม่ครบเป็น failed
- Android content URI ใช้ API คัดลอกของ Nearby; เปิดรูปเต็มและเล่นวิดีโอจากไฟล์ในเครื่องได้ รวมถึงเปิดไฟล์ฝั่งผู้ส่งขณะรอส่ง
- Cloud เป็นสำเนาส่วนตัวของบัญชีที่กด Upload: bucket chat-media เป็น private และ RLS จำกัด owner ทุก operation; metadata อยู่ใน media_records; เปิดผ่าน signed URL อายุ 60 วินาที
- ปุ่ม Upload รายไฟล์มี progress ตามจำนวนไบต์ที่ส่งเข้าสตรีม HTTP และสถานะตรวจสอบแยกต่างหาก; 100% ยังไม่ใช่สำเร็จ ต้องอ่านไฟล์บน Cloud ตรวจ checksum/ขนาดและบันทึก metadata ก่อน ready
- คิว Upload เก็บใน SQLite; retry อัตโนมัติแบบเว้นระยะเฉพาะไฟล์ที่ผู้ใช้กดใน session ปัจจุบัน ไม่เกิน 5 ครั้ง พร้อมปุ่มลองใหม่ หลัง restart ผู้ใช้กดเริ่มงานที่ค้างอีกครั้ง ไม่มี Upload อัตโนมัติจากประวัติแชต
- ค้นหาข้อความ/ชื่อไฟล์ในแชตและกรองทั้งหมด, ข้อความ, รูปภาพ, วิดีโอ, ค้างส่ง
- แจ้งเตือนสื่อหลังบันทึกรับครบเพียงครั้งเดียวต่อข้อความ ผ่าน callback และ notification Android เคารพสวิตช์แจ้งเตือนเดิม; SOS เดิมยังทำงาน

## หลักฐานที่ผ่าน

| การตรวจ | ผล | หลักฐาน |
| --- | --- | --- |
| Flutter analyze --no-pub | ผ่าน ไม่มี issues | ผลคำสั่งใน chat |
| Flutter test --no-pub ทั้งโครงการ | ผ่าน 104 tests; ข้าม 4 live opt-in tests | phase4-tests.txt |
| รับสลับลำดับ, ไฟล์เสีย, duplicate, restart, ACK หาย/ผิด peer | ผ่าน | ../test/media_service_test.dart |
| Upload 100% แต่ตรวจไม่เสร็จ, failure/restart/retry, เปลี่ยนบัญชี, ไฟล์ในเครื่องเสีย | ผ่าน | ../test/media_upload_test.dart |
| ค้นหาชื่อไฟล์/ข้อความและกรองรูป/วิดีโอ/ค้างส่งบน UI | ผ่าน | ../test/media_search_test.dart |
| Cloud จริง: HTTP upload, download/checksum, metadata, อัปโหลดซ้ำ, signed URL, anonymous denied, cross-owner insert denied | ผ่าน 1 live test; synthetic image ถูกลบท้าย test | ../test/media_cloud_live_test.dart |
| Storage RLS: owner อ่านได้; identity อื่นอ่าน/เขียนทับ/แทรกไม่ได้; delete ถูก server guard ปฏิเสธ | ผ่าน; fixture rollback | ../supabase/tests/media_storage.sql |
| Android APK รุ่นสุดท้าย | build สำเร็จ | ../build/app/outputs/flutter-apk/app-debug.apk |
| git diff --check | ผ่าน | ผลคำสั่งใน chat |

ใช้ Supabase RescueLink project ตาม URL ใน config เดิม และ apply migration media_private_storage แล้ว ไม่สร้างบัญชีใหม่ ไม่ส่ง email และทดสอบด้วยภาพสังเคราะห์เท่านั้น

รัน live test ซ้ำได้ด้วย `flutter test --no-pub test/media_cloud_live_test.dart --dart-define=RUN_LIVE_MEDIA=true` โดยต้องมี config/supabase.local.json และ config/test-account.local.json ที่เก็บเฉพาะในเครื่อง ห้ามนำ credentials เข้า Git

## การตรวจบนโทรศัพท์ก่อนปิด Phase 4

1. ติดตั้ง APK บน Android A และ B เปิดสิทธิ์ Nearby และ notification แล้วเชื่อมต่อโดยตรง
2. ปิด mobile data และเชื่อม Wi-Fi ที่ไม่มีอินเทอร์เน็ต หรือปิด Wi-Fi เมื่อ Nearby ยังเชื่อมต่อได้ ส่ง PNG/JPEG และ MP4 จาก A ไป B บันทึกวิดีโอหน้าจอทั้งสองฝั่ง
3. ตรวจว่า B เปิดรูปและเล่นวิดีโอได้ และ A แสดง delivered หลัง B รับครบเท่านั้น บันทึกขนาด/checksum จาก metadata หรือ log เพื่อเทียบต้นฉบับ
4. ส่งวิดีโอขนาดใหญ่แล้วตัดการเชื่อมต่อกลางทาง ต้องไม่ขึ้น delivered; reconnect และกดส่งใหม่ ต้องได้ไฟล์ครบและมีข้อความเดียว
5. ปิด/เปิดแอปทั้งสองเครื่อง สื่อที่รับครบต้องเปิดได้ ข้อความที่ค้างต้องไม่กลายเป็นสำเร็จ
6. ตั้ง B เป็นแอปเบื้องหลังระหว่าง session ที่ผู้ใช้เริ่มไว้ ส่งสื่อจาก A ต้องแจ้งเตือนหลังตรวจไฟล์ผ่านครั้งเดียว ทดสอบ retry และปิดสวิตช์แจ้งเตือนด้วย
7. เปิดอินเทอร์เน็ตและเข้าสู่ระบบ กด Upload รายไฟล์ ดู progress/กำลังตรวจสอบ/Cloud พร้อม แล้วเปิดจาก Cloud
8. ตัดอินเทอร์เน็ตขณะ Upload ต้องแสดง failed/รอลองใหม่ ไม่ขึ้นพร้อม; เปิดแอปใหม่ คิวต้องยังอยู่ และกดลองใหม่ได้
9. ค้นหาข้อความ/ชื่อไฟล์และใช้ทุกตัวกรองหลัง restart แล้วตรวจแชตข้อความธรรมดาและ SOS เดิม
10. เก็บหลักฐานพร้อมรุ่นโทรศัพท์/Android/ขนาดไฟล์ ผลจริง และระบุว่าเป็น direct link เท่านั้น

Foreground connection service ไม่เปิด Flutter engine ใหม่หลัง force-stop/process death; การรับในเบื้องหลังต้องอยู่ใน session ที่ยังทำงาน ส่วนการเปิดดูสื่อที่บันทึกแล้วหลัง restart ไม่ต้องอาศัย session นั้น
