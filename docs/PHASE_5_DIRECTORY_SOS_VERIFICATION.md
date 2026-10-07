# รายชื่อและ SOS/Rescue ผ่าน Relay — 2026-10-05

## สิ่งที่ทำแล้ว

- A รู้จัก C ผ่าน B โดยไม่มี direct pairing A–C และส่งข้อความถึง C ได้
- UI แสดงการเชื่อมต่อโดยตรงหรือผ่าน B พร้อมจำนวน hops
- Rescue และ SOS แบบประกาศกระจายผ่าน directory; SOS แบบเลือกผู้รับใช้ RelayPacket คิวถาวร และ ACK เดิม
- เปิด/แก้ไข/ยกเลิก SOS ใช้ revision ต่อ incident; ข้อมูลเก่าไม่ย้อนสถานะยกเลิกหรือยืดอายุ
- active SOS หมดอายุเมื่อครบ 24 ชั่วโมงจาก updatedAt; presence เก่าไม่เท่ากับ SOS ยกเลิก
- คิวเครื่องกลางหยุดส่ง active SOS ที่หมดอายุหรือ revision ที่ถูกแทนแล้ว
- เก็บ directory, presence และ SOS ledger ใน settings เดิม ไม่ล้างข้อมูลผู้ใช้และไม่เพิ่ม schema version

## Wire format ที่ใช้งานจริง

ข้อมูลรายชื่ออยู่ใน JSON ของ presence.text เดิม เพิ่ม directoryVersion: 1 และ directory
แต่ละ entry คือ {peerId, name, sequence, rescue, sos, ageMs, path}; sos เป็น JSON string หรือ null
ไม่มี packetType peerDirectory แยกต่างหาก และ presence ไม่ได้ห่อด้วย RelayPacket

- sequence เพิ่มและบันทึกที่เจ้าของข้อมูลก่อนส่ง heartbeat
- ageMs สะสมตามเวลาที่เก็บข้อมูล ไม่รีเซ็ตเมื่อส่งต่อหรือรับ sequence เดิม
- path เริ่มจากเจ้าของข้อมูล จบที่ peer ผู้ส่งจริง ห้ามซ้ำหรือผ่านผู้รับมาแล้ว
- ทั้ง direct และ remote presence สดไม่เกิน 30 วินาที; หยุดประกาศข้อมูลอายุ 48 ชั่วโมง
- แบ่ง heartbeat ไม่เกิน 32 entries และ 24 KiB เพื่อรองรับชื่อ/รายละเอียดภาษาไทย
- reachable ต้องมีข้อมูลสดและลิงก์ไปยัง hop ถัดไป; ชื่อและประวัติยังอยู่หลังหลุด
- สถานะยกเลิกใน SOS ledger คงอยู่หลัง restart เพื่อกันข้อมูลเก่าทำให้เหตุเปิดใหม่

## ผลทดสอบอัตโนมัติ

flutter test --no-pub: ผ่าน 138 tests; ข้าม 4 opt-in/live tests
ตรวจขั้นสุดท้ายวันที่ 2026-10-06: flutter analyze --no-pub ไม่มี issues
flutter build apk --debug --no-pub สำเร็จ: build/app/outputs/flutter-apk/app-debug.apk
เพิ่ม 11 tests ใน network_presence_sos_test.dart ใช้ transport ทดสอบและ SQLite แยกสามเครื่อง
ครอบคลุม discovery, chat/ACK, Rescue, stale replay, path วน/ผิดผู้ส่ง, payload ใหญ่,
SOS lifecycle, targeted relay, offline/restart, cancellation ก่อน open และ expiry
ปรับ widget test ให้ SOS ยังแสดงเมื่อ presence เก่า แต่หายเมื่อ SOS หมดอายุ

ผลเหล่านี้ไม่ใช่หลักฐานการทดสอบมือถือจริง

## ขั้นตอนยืนยันมือถือสามเครื่อง

1. ลง APK รุ่นเดียวกันบน A/B/C บันทึกรุ่นมือถือ Android และ build ที่ใช้
2. ใช้ A และ C ที่ยังไม่เคยจับคู่กัน เชื่อมเฉพาะ A–B และ B–C ตรวจรายการ endpoint/log ว่าไม่มี A–C
3. ตรวจ A เห็นชื่อ C ผ่าน B และกลับกัน ส่งข้อความสองทิศทาง ตรวจข้อความเดียวและ ACK delivered
4. เปิด/ปิด Rescue ที่ C ตรวจ A เปลี่ยนตาม จากนั้นตัด C–B รอเกิน 30 วินาที ตรวจสถานะเก่า ไม่แสดง reachable
5. เปิด SOS ที่ C แก้รายละเอียด และยกเลิก ตรวจ A เห็นตาม revision โดยไม่สร้างเหตุซ้ำ
6. ที่ A เลือก C เป็นผู้รับ SOS ตรวจส่งผ่าน B และ ACK กลับ A
7. ตัด C–B ส่ง SOS จาก A ให้ B รับคิว แล้วแก้ไข/ยกเลิก ปิดแอป B แบบ force-stop และเปิดใหม่ เชื่อมกลับ ตรวจ C เห็นสถานะยกเลิกล่าสุด
8. ทดสอบตัดลิงก์หลัง C รับก่อน ACK กลับ A ตรวจ retry ไม่สร้างรายการซ้ำและ A ได้ ACK ภายหลัง
9. ทดสอบ expiry ด้วยเหตุครบ 24 ชั่วโมงจริง หรือ fixture เวลาที่ควบคุมและระบุชัดในรายงาน แยกจากผลการรอครบจริง
10. เก็บวิดีโอหน้าจอทั้งสามเครื่อง พร้อม log message ID, incident/revision, relay path, enqueue/retry/ACK และเวลา

หากบังคับจังหวะ ACK หายหรือ packet ซ้ำไม่ได้ ให้ระบุว่ายังไม่ตรวจบนเครื่องจริง
การทดสอบเส้นทางวนใช้ topology ที่มีวงจรแยกจากเคส A–B–C และต้องยืนยันว่า traffic หยุด
สื่อรูป/วิดีโอผ่าน Relay ยังอยู่นอกงานรอบนี้ และ Phase 5 ยังต้องผ่านการทดสอบมือถือจริงก่อนปิดงาน
