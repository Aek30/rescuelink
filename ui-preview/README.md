# RescueLink · Interactive UI Preview

เว็บต้นแบบภาษาไทยสำหรับทดลอง UI/UX ก่อนนำดีไซน์ไปใช้กับแอป Flutter Phase 2

## เปิดใช้งาน

ต้องมี Node.js ไม่ต้องติดตั้ง npm packages:

```powershell
cd D:\3-1\project_keeratiburt\miniProject\rescuelink
node ui-preview/server.cjs
```

เปิด **http://localhost:4173** ในเบราว์เซอร์ กด Ctrl+C ใน terminal เพื่อหยุด server

หน้าเริ่มต้นเป็น Home เพื่อดูภาพรวมทันที ดู Splash ที่ `http://localhost:4173/#splash` และ onboarding ที่ `http://localhost:4173/#onboarding` หรือเมนู ฉัน → ดูวิธีใช้งาน

## ทดลองได้

- หน้า Home / Radar, กรองบทบาท, แชตแต่ละคน, สถานะว่าง / กำลังโหลด / สิทธิ์ไม่พร้อม
- SOS กดค้าง 2 วินาที (หรือ Space/Enter ค้าง) เพื่อเปิดจำลอง และแตะอีกครั้งเพื่อปิด
- สวิตช์โหมดกู้ภัย และกรองระยะคำขอความช่วยเหลือ
- พิมพ์ข้อความจำลอง, ค้างส่ง → ส่งแล้ว → ถึงปลายทางแล้ว, ประวัติอยู่หลัง reload
- เลือกภาพแล้วบีบอัด JPEG สูงสุด 1280px / quality .8; วิดีโอพรีวิวได้แต่ **ยังไม่บีบอัด** จำกัดไฟล์แนบ 20 MB
- สื่อแนบเป็น object URL ชั่วคราว ไม่ส่งออกและไม่เก็บหลัง reload
- Queue: retry, เปลี่ยนเครือข่ายจำลองเพื่อส่งคิว, sync จำลอง, ประวัติ sync ในเซสชัน
- โปรไฟล์จำลอง, Dark Mode, คู่มือสิทธิ์, หน้าบัญชีจำลอง (ไม่ขอรหัสผ่าน)
- PWA manifest, PNG icons, Service Worker precache รวมฟอนต์และไอคอน

## ขอบเขตที่ต้องแยกจากระบบจริง

**เว็บนี้ไม่ใช่ระบบแจ้งเหตุฉุกเฉิน และไม่ส่งข้อความให้บุคคลอื่น**

Nearby / BLE / Wi-Fi Direct, SOS broadcast, GPS, cloud authentication, cloud sync และ mesh routing ทั้งหมดเป็นข้อมูลและสถานะตัวอย่าง ไม่มีการเรียก API ภายนอกเวลาใช้งาน

`localStorage` ใช้เก็บสถานะต้นแบบและข้อความตัวอย่าง ไม่ใช่ IndexedDB/SQLite production database จึงจำกัดประวัติถาวรไว้ 150 ข้อความ และไม่ควรใส่ข้อมูลส่วนตัวหรือสุขภาพจริง

UI นี้ไม่แก้โค้ด Flutter เดิม; Phase 2 จริงยังอยู่ใน `lib/` และทดสอบ 2 เครื่องตาม `docs/PHASE_2_TEST.md`

## ออฟไลน์และติดตั้ง

1. เปิดผ่าน localhost หรือ HTTPS ออนไลน์ครั้งแรกจนหน้า Network แสดงแคช PWA พร้อมใช้งาน
2. Reload หนึ่งครั้งให้ Service Worker ควบคุมหน้าเว็บ
3. ใช้เมนูติดตั้งของ Chrome/Edge หรือปุ่มติดตั้งใน Settings เมื่อเบราว์เซอร์รองรับ
4. ทดสอบตัดอินเทอร์เน็ตหรือหยุด local server แล้ว reload: แอปควรเปิดจากแคช (ในเบราว์เซอร์ที่อนุญาต Service Worker)

ถ้าจะดูบนมือถือผ่าน LAN ให้ตั้ง `$env:HOST='0.0.0.0'` ก่อนรัน server และใช้ IP ของคอมพิวเตอร์ แต่ **PWA/Service Worker ต้อง HTTPS บนมือถือ**; HTTP LAN ใช้ดูเลย์เอาต์ได้เท่านั้น อย่าเปิดพอร์ตนี้สู่อินเทอร์เน็ต

อัปเดตโค้ดแล้วให้เพิ่ม cache version ใน `sw.js` และ reload หลัง worker ใหม่ activate

## ไฟล์

- `index.html`, `app.js`, `styles.css`: UI และ simulation
- `manifest.webmanifest`, `sw.js`: install / offline shell
- `server.cjs`: server ในเครื่อง แบบไม่มี dependencies
- `DESIGN_SYSTEM.md`: tokens, components, accessibility และข้อจำกัด
- `assets/`: Noto Sans Thai (OFL), Lucide (ISC / MIT notices), original app icons
- `download-assets.cjs`, `make-icons.cjs`: เครื่องมือเตรียม assets ไม่ต้องรันเพื่อใช้ต้นแบบ

Noto Sans Thai จาก https://github.com/google/fonts/tree/main/ofl/notosansthai และ Lucide จาก https://github.com/lucide-icons/lucide พร้อม license ใน assets
