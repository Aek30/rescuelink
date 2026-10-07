# RescueLink Auth emails

## สถานะการตรวจสอบ (7 ตุลาคม 2026)

หลังผู้ใช้ตั้งค่า Gmail Custom SMTP แล้ว หน้า Dashboard ของโปรเจกต์ `yrpqhupqbzymesknalnq` (RescueLink) ปลดล็อกการแก้เทมเพลตแล้ว บันทึกหัวข้อและ HTML จาก `confirmation.html` / `recovery.html` ลงใน Confirm sign up / Reset password สำเร็จทั้งสองรายการ โดย Dashboard แสดง “Successfully updated email template” และ Preview แสดงข้อความภาษาไทยตรงกับไฟล์

ยังไม่ได้ทดสอบส่งจริงไปยัง inbox จึงยังไม่ยืนยันว่า Gmail SMTP ส่งสำเร็จหรือว่าขั้นตอนยืนยันบัญชี/รีเซ็ตจริงผ่านครบ ควรทดสอบตามรายการด้านล่าง

ตรวจสอบโค้ดแล้ว:

- สมัครสมาชิก: `SupabaseAuthBackend.authenticate` เรียก `auth.signUp` และแจ้งให้ผู้ใช้ยืนยันอีเมลก่อนเข้าสู่ระบบ ใช้ `{{ .ConfirmationURL }}` ในเทมเพลตยืนยันบัญชี
- ลืมรหัสผ่าน: `sendPasswordResetEmail` เรียก `auth.resetPasswordForEmail` แต่หน้าแอปให้กรอก OTP แล้ว `resetPasswordWithOtp` เรียก `verifyOTP(type: OtpType.recovery)` ก่อน `updateUser` จึงต้องแสดง `{{ .Token }}` ในอีเมล recovery
- recovery ใช้ OTP โดยไม่มีลิงก์ยืนยัน เพื่อให้ผู้ใช้กรอกรหัสในแอปและไม่เผลอใช้ token ผ่านลิงก์ก่อนกรอก
- ไม่ระบุเวลาหมดอายุหรือจำนวนหลักตายตัวในอีเมล เพราะขึ้นอยู่กับการตั้งค่า Auth ของโปรเจกต์ ตรวจสอบให้ตรงกับหน้าแอปก่อนเปิดใช้

## วิธีนำไปใช้กับ hosted Supabase

1. เปิด [SMTP Settings](https://supabase.com/dashboard/project/yrpqhupqbzymesknalnq/auth/smtp) และตั้งค่า SMTP ของผู้ให้บริการที่ใช้ พร้อมยืนยันโดเมนผู้ส่งตามข้อกำหนดของผู้ให้บริการ ตั้ง Sender name เป็น `RescueLink` และใช้อีเมลผู้ส่งของโดเมนที่ยืนยันแล้ว
2. เปิด [Confirm sign up](https://supabase.com/dashboard/project/yrpqhupqbzymesknalnq/auth/templates/confirm-sign-up)
   - Subject: `ยืนยันอีเมลเพื่อเริ่มใช้งาน RescueLink`
   - Body / Source: เนื้อหาทั้งหมดจาก `confirmation.html`
3. เปิด [Reset password](https://supabase.com/dashboard/project/yrpqhupqbzymesknalnq/auth/templates/reset-password)
   - Subject: `รหัสยืนยันเพื่อตั้งรหัสผ่านใหม่ — RescueLink`
   - Body / Source: เนื้อหาทั้งหมดจาก `recovery.html`
4. Preview แล้ว Save changes ของทั้งสองรายการ ห้ามแทนที่ตัวแปร Go template ด้วยลิงก์หรือรหัสจริง
5. ตรวจสอบ Site URL / Redirect URLs ของ signup ให้เปิดได้จริง โค้ดสมัครปัจจุบันไม่ได้ส่ง `emailRedirectTo` จึงใช้ Site URL ของโปรเจกต์ อย่าใส่ลิงก์รีเซ็ตเองใน recovery เพราะแอปใช้ OTP

การเพิ่มไฟล์ HTML ใน repository ไม่ได้อัปเดต hosted Auth และ `supabase db push` ก็ไม่ส่งเทมเพลตเหล่านี้

## การตรวจสอบหลังตั้งค่า

ใช้กล่องจดหมายทดสอบที่คุณเป็นเจ้าของ:

1. สมัครบัญชีใหม่ ตรวจหัวข้อภาษาไทย ชื่อผู้ส่ง และปุ่มยืนยัน เปิดลิงก์ครั้งเดียว แล้วกลับเข้าแอปและทดสอบเข้าสู่ระบบ
2. กดลืมรหัสผ่าน ตรวจว่าอีเมลแสดง OTP จริงแทน `{{ .Token }}` และไม่แสดงลิงก์รีเซ็ต กรอกรหัสในแอปพร้อมรหัสผ่านใหม่ แล้วทดสอบเข้าสู่ระบบ
3. ตรวจว่ารหัสผิด รหัสใช้แล้ว และรหัสหมดอายุถูกปฏิเสธ ส่งรหัสใหม่แล้วใช้ฉบับล่าสุด ตรวจ Spam หากไม่ได้รับอีเมล

การตรวจโค้ดและเทมเพลตยังไม่ยืนยันการส่งจริงหรือการรับใน inbox จนกว่าจะตั้งค่าและทดสอบขั้นตอนข้างต้น

อ้างอิง: [Email Templates](https://supabase.com/docs/guides/auth/auth-email-templates), [Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)
