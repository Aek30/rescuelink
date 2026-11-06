# เวลาไทยของการซิงค์

หน้าซิงค์ในแอปแสดงวันและเวลาที่ซิงค์สำเร็จในเขตเวลาไทย UTC+7 แม้โทรศัพท์ตั้งเขตเวลาอื่น เช่น `04/11/2026 09:34:00 (เวลาไทย)` เวลาที่ผ่านไป เช่น “5 นาทีที่แล้ว” ยังคำนวณจากเวลาเดิม

## Supabase Table Editor

เปิด SQL Editor ของโปรเจกต์ แล้วรันไฟล์ `supabase/migrations/20261104060000_thai_sync_display_time.sql` จากนั้น Refresh ตาราง `chat_records` และ `sos_records` และดูคอลัมน์ใหม่ `updated_at_th`

- `updated_at`: เวลาอ้างอิงเดิมชนิด timestamptz เช่น `2026-11-04 02:34:00+00`
- `updated_at_th`: วันและเวลาไทยสำหรับแสดงผล เช่น `2026-11-04 09:34:00` ไม่มี suffix เขตเวลา เนื่องจากชนิดข้อมูลเป็น timestamp without time zone

คอลัมน์ใหม่คำนวณจาก `updated_at` อัตโนมัติทั้งแถวเก่าและแถวใหม่ ไม่ต้องแก้ RPC หรือส่งค่า updated_at_th จากแอป และไม่ต้อง UPDATE เวลาเดิมบวก 7 ชั่วโมง

ไฟล์นี้เตรียมไว้ในโปรเจกต์แล้ว แต่ยังไม่ได้รันกับฐานข้อมูล Supabase จริง การติดตั้ง APK อย่างเดียวจะไม่เพิ่มคอลัมน์ใน Supabase

หากต้องการดูเวลาไทยอย่างเดียวก่อนปรับ schema สามารถรันคำสั่งอ่านข้อมูล:

```sql
select id, updated_at,
       updated_at at time zone 'Asia/Bangkok' as updated_at_th
from public.chat_records
order by updated_at desc
limit 100;
```

ก่อนรัน migration ในฐานข้อมูลที่มีข้อมูลจำนวนมาก ควรเลือกช่วงที่ใช้งานน้อย เนื่องจากการเพิ่มคอลัมน์ generated stored ต้องคำนวณค่าของแถวเดิม
