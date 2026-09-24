# RescueLink Design System · Orange / Thai

## แนวคิด

อบอุ่น อ่านง่าย และทำให้สถานะการสื่อสารเข้าใจได้ ลดการตกแต่งบนข้อความสำคัญ ใช้พื้นขาว/ครีมเป็นหลักและเงาอ่อน เส้นกรอบบางช่วยแยกการ์ด ปุ่ม SOS อยู่กลาง bottom navigation เสมอบนมือถือ

## Tokens

| Token | Light | ใช้งาน |
|---|---|---|
| Primary | #FF9F5A | ปุ่มหลัก / โลโก้ |
| Primary light | #FFE8D6 | พื้นข้อความฝั่งเรา / selected |
| Primary dark | #E8772E | เส้นตกแต่ง / switch |
| Accent ink | #873B10 | ข้อความบนพื้นส้มอ่อน |
| Background | #FFF8F2 | พื้นหลัง |
| Surface | #FFFFFF | การ์ด / input |
| Text | #2B2B2B | ข้อความหลัก |
| Muted | #6B625C | คำอธิบาย |
| SOS | #EF4444 | เครื่องหมายเตือน; ข้อความใช้ #AA2626 |
| Rescuer | #3B82F6 | สถานะกู้ภัย; ข้อความใช้ #2252A0 |
| Success | #22C55E | สถานะสำเร็จ; ข้อความใช้ #176437 |
| Pending | #F59E0B | ค้างส่ง; ข้อความใช้ #845008 |

โหมดมืด: background #191512, surface #241E1A, text #FFF5ED, secondary #C5B5A7 และสีสถานะที่สว่างขึ้น ใช้ CSS variables ชุดเดียว

- Spacing: 8 / 16 / 24 / 32 / 40px; 4px สำหรับรายละเอียดขนาดเล็ก
- Radius: input/button 14–16px, card 20–24px, chip 999px
- Shadow: `0 8px 32px #54371b08`
- Font: Noto Sans Thai variable ที่บันเดิลในเครื่อง; body 400–500, heading 600–800
- Icons: Lucide แบบเส้น 1.8px บันเดิล SVG 37 ตัว ชุดเดียวกันทั้งแอป
- Motion: 200–300ms, radar/SOS ใช้การเคลื่อนไหวช้า; ปิดเมื่อ prefers-reduced-motion

## Components

`btn` primary / soft / ghost / danger, `input`, `card`, `pill`, `avatar`, sidebar + bottom-nav, network-strip, device row, chat bubble + receipt, dialog, toast aria-live, toggle switch, skeleton, empty state

สถานะ hover/pressed/focus-visible ใช้ CSS; disabled ใช้ native disabled; loading ใช้ skeleton หรือปุ่มที่แสดงว่ากำลังทำงาน; error มีคำแนะนำและปุ่มแก้; ไม่ใช้สีเพียงอย่างเดียว มีข้อความและไอคอนกำกับ

## Responsive & accessibility

- ออกแบบ mobile-first ที่ 390px; bottom nav ที่ <=760px, rail ที่ <=950px, sidebar บน desktop
- ปุ่มหลักและ touch targets >=48px, keyboard focus ring 3px
- สีส้ม primary ไม่ใช้ตัวอักษรสีขาวขนาดเล็ก แต่ใช้หมึกเข้มเพื่อ contrast; สี semantic ดิบเป็น accent ส่วน label ใช้เฉดเข้ม
- Contrast ของ token หลักตรวจด้วยสูตร WCAG; ยังไม่ใช่การรับรอง accessibility audit ทั้งระบบ
- Modal ใช้ native dialog, form มี label, status มี aria-live, switch มี aria-checked
- ระยะ/พิกัดทุกค่าที่เห็นเป็น mock พร้อม label ไม่ได้ประมาณจาก GPS จริง
- SOS ไม่อ้างว่าช่วยเหลือสำเร็จ ไม่แสดงจำนวนผู้รับจริง

## ก่อนนำไปใช้ใน Flutter

1. ย้าย tokens ไป ThemeData / ColorScheme และสร้าง widget components
2. แทน mock message ด้วย MessageService/SQLite เดิม ใช้ DELIVERED เมื่อได้รับ ACK จริง
3. ซ่อนหรือปิดใช้งาน cloud/SOS/media/mesh จน backend/transport พร้อม
4. ทดสอบ text scaling, screen reader, keyboard, RTL ถ้ามี และโทรศัพท์จริงสองเครื่อง
