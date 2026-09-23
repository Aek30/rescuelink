# บันทึกผลทดสอบ Android จริง — Phase 1

สถานะเริ่มต้น: **NOT RUN / ไม่ผ่านการรับรองจนกว่าจะทดสอบจริง**
Unit tests ไม่ถือเป็นผลทดแทน ห้ามกรอก PASS หากยังไม่ตรวจบนมือถือสองเครื่อง

วันที่/ผู้ทดสอบ: ____________________
APK/build version: ____________________
Phone A ยี่ห้อ/รุ่น/Android API/Google Play services version: ____________________
Phone B ยี่ห้อ/รุ่น/Android API/Google Play services version: ____________________

ทั้งสองเครื่อง: Mobile Data OFF, ไม่มี Wi-Fi internet connection, ไม่ใช้ hotspot/tethering, Bluetooth/Wi-Fi radio/Location ON

| รายการ | ผลจริง PASS/FAIL/NOT RUN | หลักฐาน/หมายเหตุ |
| --- | --- | --- |
| Build และติดตั้ง APK ทั้งสองเครื่อง | NOT RUN | |
| A = Rescue-A, B = Rescue-B | NOT RUN | |
| Runtime permission อนุญาตครบ | NOT RUN | |
| A Advertising และ B Discovery | NOT RUN | |
| B พบ A หนึ่งรายการ ไม่ซ้ำ | NOT RUN | |
| B Connect และทั้งสองฝั่ง Connected | NOT RUN | |
| B → A: Hello A แสดงบน A | NOT RUN | |
| A → B: Hello B แสดงบน B | NOT RUN | |
| Hello from RescueLink ทั้งสองทิศทาง | NOT RUN | |
| ข้อความไทยทั้งสองทิศทาง | NOT RUN | |
| Deny Nearby / Location permission แล้วแอปไม่ crash | NOT RUN | |
| Location service / Bluetooth off มี error ที่เข้าใจได้ | NOT RUN | |
| ส่งข้อความว่าง/ส่งก่อนเชื่อมต่อ ถูกป้องกัน | NOT RUN | |
| STOP / Disconnect ทำงาน และเชื่อมต่อใหม่ได้ | NOT RUN | |
| สลับแอป/ล็อกหน้าจอ หยุด session; กลับมาเชื่อมต่อใหม่ได้ | NOT RUN | |
| ทดสอบซ้ำโดยสลับ A Discovery / B Advertising | NOT RUN | |

ข้อผิดพลาดและ System Log: ____________________

อนุมัติ Phase 1: __________ เฉพาะเมื่อการค้นหา เชื่อมต่อ และส่งสองทิศทางแบบไม่มีอินเทอร์เน็ตผ่านบน Android จริง 2 เครื่อง
