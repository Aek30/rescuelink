# Authentication และข้อมูลสุขภาพฉุกเฉิน — 9 ตุลาคม 2026

เพิ่มข้อมูลส่วนตัวและข้อมูลสุขภาพบนโปรเจกต์ RescueLink เดิม ผู้ใช้เดิมเติมข้อมูลได้ที่ **ข้อมูลสมาชิก → ข้อมูลส่วนตัวและสุขภาพฉุกเฉิน** โดยไม่ต้องสมัครบัญชีใหม่

## การเก็บรักษาข้อมูลเดิม

- เพิ่มคอลัมน์ใน `profiles` และตาราง `emergency_medical_profiles` ไม่ลบตาราง บัญชี หรือประวัติเดิม
- ผู้ใช้เดิมมีชื่อจริง/เบอร์โทรเริ่มต้นเป็นช่องว่าง วันเกิดและความยินยอมเริ่มต้นไม่ระบุ ไม่มีการเดาข้อมูลหรือยินยอมแทนผู้ใช้
- ตรวจฐานข้อมูลจริงก่อนและหลัง migration: จำนวนโปรไฟล์เดิม 1 รายการเท่าเดิม ค่า fingerprint ของ ID, display_name, created_at ตรงกัน (`83df342a1d1fcb0b00bd86ea8aaf88c5`)
- Logout ไม่ลบฐานข้อมูล Local หรือสำเนาสุขภาพของบัญชี ข้อมูลแยกตาม User ID บัญชีอื่นอ่านผ่านแอปไม่ได้ ประวัติ Guest เดิมคงแยกอยู่และไม่มีการโอนให้อีกบัญชีอัตโนมัติ
- การถอนความยินยอม/ลบสุขภาพไม่ลบบัญชี ข้อมูลส่วนตัว หรือประวัติ Chat/SOS การลบบัญชีถาวรยังเป็นคำสั่งแยกต่างหาก

## พฤติกรรมใหม่

- Login ไม่มี Guest ไม่มี checkbox ผูกข้อมูล และเก็บ session ใน secure storage เพื่อเปิดแอปออฟไลน์ได้
- Register มีบัญชี → ส่วนตัว → สุขภาพ พร้อม validation ยอมรับนโยบายและยินยอมสุขภาพแยกกัน การกดข้ามไม่นำสุขภาพที่เคยกรอกไปบันทึก
- ข้อมูลส่วนตัวส่งให้ Supabase Auth เพื่อสร้างโปรไฟล์ตั้งแต่สมัคร ข้อมูลสุขภาพไม่อยู่ใน Auth metadata/JWT
- สุขภาพที่รอยืนยันอีเมลเก็บใน secure storage แยกตาม Supabase project และ User ID ต้องเข้าสู่ระบบบนเครื่องที่สมัครเพื่อซิงก์ข้อมูลสุขภาพที่กรอกไว้ หากใช้เครื่องใหม่สามารถกรอกสุขภาพใหม่หลังเข้าสู่ระบบได้
- Dialog ปิดบังอีเมล เลื่อนบนจอเล็กได้ ส่งอีเมลซ้ำด้วย `auth.resend(type: OtpType.signup)` จริง มี loading/error/success และจำกัดการกดซ้ำ 60 วินาที
- หน้าโปรไฟล์อ่าน/แก้ไขข้อมูลทั้งชุด รองรับออฟไลน์เมื่อเคยโหลดข้อมูลแล้ว และรอซิงก์ผ่าน Cloud coordinator เดิมเมื่อกลับมาออนไลน์
- ถอนความยินยอมล้างสุขภาพและผู้ติดต่อในเครื่องทันที และลบแถวสุขภาพบน Cloud เมื่อซิงก์สำเร็จ สถานะรอซิงก์แสดงอย่างชัดเจน
- RPC บันทึกข้อมูลส่วนตัวและสุขภาพใน transaction เดียว ใช้ `auth.uid()` และ RLS เจ้าของข้อมูลเท่านั้น ไม่เชื่อ ID ที่ส่งจาก client
- ไม่มีการเพิ่มสุขภาพใน Nearby/SOS/Chat payload หรือ debug log
- เมื่อ access token หมดอายุและติดต่อเซิร์ฟเวอร์ไม่ได้ session ที่เคยยืนยันอีเมลและเก็บใน secure storage ยังเปิด Local/Nearby/SOS ได้ Cloud ต้อง refresh ให้สำเร็จก่อนใช้งาน หากเซิร์ฟเวอร์ยืนยันว่า session ถูกเพิกถอน จะล็อก Local และกลับ Login

## ไฟล์ที่แก้ในงานนี้

- `lib/services/auth_service.dart`
- `lib/services/member_service.dart`
- `lib/services/emergency_profile_store.dart` (ใหม่)
- `lib/services/emergency_profile_service.dart` (ใหม่)
- `lib/screens/login_screen.dart`
- `lib/screens/register_screen.dart`
- `lib/screens/member_screen.dart`
- `lib/screens/emergency_profile_screen.dart` (ใหม่)
- `lib/screens/nearby_test_screen.dart` — คืนหน้า Login เมื่อ Cloud ปฏิเสธบัญชี
- `lib/widgets/privacy_notice.dart` (ใหม่)
- `lib/theme/rescue_theme.dart`
- `supabase/migrations/20261009070000_emergency_medical_profiles.sql`
- `supabase/tests/emergency_medical_profiles.sql` (ใหม่)
- `test/account_auth_test.dart`, `test/login_screen_test.dart`
- `test/emergency_profile_test.dart`, `test/emergency_profile_screen_test.dart`, `test/medical_cloud_live_test.dart` (ใหม่)
- เอกสารนี้ และ `output/auth-medical-test.log`

ไฟล์อื่นที่มีการแก้ค้างใน working tree อยู่ก่อนงานนี้ยังคงอยู่ ไม่มี commit หรือ push

## Supabase และการตรวจจริง

เพิ่ม schema บนโปรเจกต์เดิม `yrpqhupqbzymesknalnq` แล้ว และบันทึก migration version `20261009070000` ใน history ตรงกับไฟล์ local คำสั่ง `apply_migration` ของ connector เกิด `Invalid or expired requestState` จึงใช้ SQL transaction เดียวและตรวจผลจริงหลังทำ

- SQL test บนฐานข้อมูลจริง **ผ่าน**: เจ้าของบันทึกข้อมูลส่วนตัว/สุขภาพได้, บังคับ consent, บัญชี B อ่าน/แก้/ลบ/เพิ่มสุขภาพของ A ไม่ได้, ถอน consent ลบสุขภาพและรักษาโปรไฟล์, anon อ่านตารางหรือเรียก RPC ไม่ได้ Fixtures ทั้งหมด rollback และไม่ส่งอีเมล
- อ่าน Auth settings จริง: `disable_signup=false`, `mailer_autoconfirm=false`, anonymous sign-in ปิด
- Supabase security advisor ไม่พบข้อแจ้งเตือนของตารางสุขภาพใหม่ ยังมี INFO ของ `sync_private.chat_receipts` ซึ่งตั้ง RLS แบบไม่อนุญาต client โดยตั้งใจ และ WARN ว่า [Leaked Password Protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) ปิดอยู่
- ทดสอบ Login กับบัญชีทดสอบเดิมใน `config/test-account.local.json` จริง **ไม่ผ่าน** (`invalid_credentials`) ไม่ได้เปลี่ยนรหัสผ่าน/บัญชีเดิม หากต้องการรันทดสอบนี้ซ้ำต้องใช้ข้อมูลบัญชีทดสอบที่ถูกต้องในไฟล์ local นี้
- ยังไม่ได้ทดสอบการรับอีเมลและกดลิงก์ในกล่องจดหมายจริง หรือทดสอบ Nearby/SOS กับโทรศัพท์สองเครื่องโดยตัดอินเทอร์เน็ต

## การตั้งค่าและใช้งาน

1. Supabase Dashboard → Authentication → Sign In / Providers → Email: เปิด Email และ **Confirm email** (โปรเจกต์นี้เปิดอยู่แล้ว)
2. ตั้ง password policy ขั้นต่ำ 8 ตัวอักษรให้สอดคล้องกับฟอร์ม และตั้ง SMTP/Email template/URL Configuration ให้ส่งลิงก์ยืนยันได้ หลังยืนยันอีเมลกลับมา Login ด้วยรหัสผ่าน
3. เริ่มต้นบัญชีครั้งแรกต้องออนไลน์ หลังจากนั้น session ที่เชื่อถือได้ใช้ฟังก์ชันในเครื่องได้ การ refresh/Cloud Sync ไม่ใช่เงื่อนไขก่อนส่ง SOS ผ่าน Nearby
4. สร้างแอปด้วย `./tool/flutter.ps1 build apk --debug` เพื่อใช้ public config เดิม ไม่ใส่ service-role key ในแอป

ดูวิธี [signUp](https://supabase.com/docs/reference/dart/auth-signup) และ [resend](https://supabase.com/docs/reference/dart/auth-resend) จาก Supabase

## ผลตรวจรอบสุดท้าย

- `flutter analyze`: **PASS**, No issues found
- `flutter test`: **PASS**, 171 ผ่าน, 5 skipped (live tests ที่ต้องเปิดด้วย flag) ใช้เวลา 1 นาที 48 วินาที ผลทั้งหมดอยู่ที่ `output/auth-medical-test.log`
- `./tool/flutter.ps1 build apk --debug`: **PASS**, 154.2 วินาที APK: `build/app/outputs/flutter-apk/app-debug.apk`
- `git diff --check`: **PASS**
- Widget tests ครอบคลุมการสมัคร 3 ขั้นตอน ข้ามสุขภาพ Dialog/resend หน้าแก้ไข/ลบสุขภาพทั้ง Light/Dark mode ที่ 320×640
- SDK tests ครอบคลุมข้อมูลสุขภาพไม่เข้า Auth/JWT, duplicate signup ไม่เขียนทับข้อมูล, อัปโหลดช้าไม่รับรองคิวใหม่, การลบ/แยกบัญชีขณะออฟไลน์, ซิงก์หลังออนไลน์, resend endpoint/rate limit, session ที่ยืนยันแล้วใช้ Local ขณะออฟไลน์ได้, session ไม่ยืนยันเข้าไม่ได้ และ server revocation ล็อก Local/ล้าง session
- Build ยังมี warning จาก plugin `location` เรื่อง Kotlin Gradle Plugin และเวอร์ชัน SDK XML ของเครื่อง แต่สร้าง APK สำเร็จ ไม่ได้อัปเกรด dependency ในงานนี้
