# ตรวจต้นแบบ UI

ตรวจใน Codex in-app browser:

- หน้า desktop 1440px และ mobile 390px: main content ไม่มี horizontal overflow หลังแก้ grid min-width
- ฟอนต์ Noto Sans Thai โหลดจากไฟล์ local และไอคอน Lucide แสดงผล
- ส่งข้อความไทย: SENT จำลอง → DELIVERED จำลอง
- โหมด Offline จำลอง: ข้อความเข้าคิวและยังอยู่หลัง reload
- เปลี่ยนเป็น Online จำลอง: คิวถูกส่งและเปลี่ยนสถานะซิงก์ คิวคงเหลือ 0
- Service Worker แสดงพร้อมใช้งาน; หยุด Node server แล้วเปิดแท็บใหม่ `/#sos` ได้จากแคช หลังตรวจเปิด server คืน
- Console ระหว่าง flow ข้อความ/คิวไม่มี JavaScript error
- Syntax check ผ่าน app.js, sw.js และ server.cjs

## Contrast ของคู่สีหลัก

ตรวจด้วยสูตร relative luminance ของ WCAG:

| คู่สี | อัตราส่วน |
|---|---:|
| ข้อความปุ่มหลัก | 6.92:1 |
| ข้อความหลัก / พื้นครีม | 13.46:1 |
| ข้อความรอง / พื้นครีม | 5.66:1 |
| Label ส้ม | 6.67:1 |
| Label SOS | 6.29:1 |
| Label กู้ภัย | 6.82:1 |
| Label สำเร็จ | 6.62:1 |
| Label ค้างส่ง | 6.19:1 |
| ปุ่ม SOS | 5.29:1 |
| ข้อความรองโหมดมืด | 8.26:1 |

นี่เป็นการตรวจ tokens และ flow หลัก ไม่ใช่การรับรอง WCAG ทั้งระบบ ยังต้องตรวจ screen reader / text scaling / การติดตั้ง PWA บนโทรศัพท์จริง และทดสอบ hold gesture บนอุปกรณ์สัมผัสจริง

ไม่ได้ทดสอบหรืออ้างว่าเว็บนี้ส่ง Nearby/SOS/cloud/mesh ได้จริง
