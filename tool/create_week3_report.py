"""Generate the Week 3 report. Bundled Python + reportlab; Thai shaping via uharfbuzz."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tmp/pdf-deps'))
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph, Table, TableStyle
from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import A4

OUT = ROOT / 'output/pdf/rescuelink-week3-report.pdf'
OUT.parent.mkdir(parents=True, exist_ok=True)
pdfmetrics.registerFont(TTFont('Thai', str(ROOT / 'assets/fonts/NotoSansThai.ttf')))
W, H = A4
NAVY, BLUE, GRAY = map(HexColor, ['#102D43', '#2563EB', '#526477'])
c = canvas.Canvas(str(OUT), pagesize=A4)
c.setTitle('RescueLink - Advanced Programming Week 3')
c.setAuthor('RescueLink project')
body = ParagraphStyle('Body', fontName='Thai', fontSize=11, leading=18, textColor=NAVY, wordWrap='CJK', shaping=True)
small = ParagraphStyle('Small', parent=body, fontSize=9, leading=14)
heading = ParagraphStyle('Heading', parent=body, fontSize=17, leading=26, textColor=BLUE)
y = H - 100
page = 0

def p(text, style=body, gap=12):
    global y
    para = Paragraph(text, style)
    _, height = para.wrap(W - 88, H)
    if y - height < 55:
        raise RuntimeError(f'Page {page} overflow: {text[:60]}')
    para.drawOn(c, 44, y - height)
    y -= height + gap

def start(title):
    global y, page
    if page:
        c.showPage()
    page += 1
    c.setFillColor(NAVY)
    c.rect(0, H - 64, W, 64, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont('Thai', 14)
    c.drawString(44, H - 40, 'RescueLink | Advanced Programming | Week 3', shaping=True)
    c.setFillColor(GRAY)
    c.setFont('Thai', 8)
    c.drawString(44, 27, 'จัดทำ 8 ตุลาคม 2569 | กำหนดส่ง 10 ตุลาคม 2569 เวลา 23:59', shaping=True)
    c.drawRightString(W - 44, 27, f'{page} / 6')
    y = H - 94
    p(title, heading, 18)

def table(headers, rows, widths):
    global y
    data = [[Paragraph(str(v), small) for v in row] for row in [headers] + rows]
    t = Table(data, colWidths=widths, repeatRows=1)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), HexColor('#EAF1FC')),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('GRID', (0,0), (-1,-1), .5, HexColor('#CCD5DF')),
        ('LEFTPADDING', (0,0), (-1,-1), 8), ('RIGHTPADDING', (0,0), (-1,-1), 8),
        ('TOPPADDING', (0,0), (-1,-1), 7), ('BOTTOMPADDING', (0,0), (-1,-1), 7),
    ]))
    _, height = t.wrap(W-88, H)
    if y-height < 55: raise RuntimeError(f'Table overflow page {page}')
    t.drawOn(c, 44, y-height)
    y -= height + 18

start('1. วัตถุประสงค์และความคืบหน้า')
p('RescueLink เป็นแอป Flutter สำหรับแจ้งเหตุ SOS และสื่อสารระหว่างอุปกรณ์เมื่ออินเทอร์เน็ตไม่พร้อม ใช้ SQLite เก็บข้อมูลในเครื่อง และ Supabase สำหรับสมาชิก ข้อมูลเหตุ SOS และไฟล์ที่ผู้ใช้เลือกอัปโหลด')
p('งาน Week 3: สาธิตการเชื่อมต่อฐานข้อมูลและ CRUD สมาชิกผ่าน Chrome ได้แก่ สมัครสมาชิก เข้าสู่ระบบ อ่านโปรไฟล์ แก้ไขชื่อ และลบบัญชี พร้อมรายงาน schema และส่วนประกอบของระบบ')
table(['หัวข้อ', 'สิ่งที่พัฒนาแล้ว'], [
    ['Create / Auth', 'สมัครอีเมลและรหัสผ่าน พร้อมชื่อสมาชิก; หากเปิด email confirmation ต้องยืนยันอีเมลก่อน Login'],
    ['Read', 'หน้า “ข้อมูลสมาชิก” อ่าน id และ display_name จาก profiles บน Supabase; อีเมลมาจาก session'],
    ['Update', 'แก้ชื่อ 1-100 ตัวอักษร และบันทึกเฉพาะโปรไฟล์ของบัญชีปัจจุบัน'],
    ['Delete', 'Edge Function delete-account ตรวจ session และรหัสผ่าน ลบไฟล์ Cloud ของเจ้าของ เพิกถอน session และลบบัญชี Auth'],
    ['Local / Sync', 'ข้อมูล SOS และคิวอยู่ใน SQLite; มีการส่งซ้ำ ตรวจเวอร์ชัน และจัดการ conflict'],
], [110, W-198])
p('สถานะการยืนยัน: Flutter ทั้งโปรเจกต์ผ่าน 144 tests และข้าม 4 live tests ที่ต้องเปิดใช้งานเอง; บริการลบบัญชีผ่าน 8 tests แบบจำลอง Analyzer ไม่มีปัญหาและ build เว็บผ่าน ตรวจ endpoint จริงพบคำขอไม่มี session ได้ 401 และ CORS preflight ได้ 204', small)
p('การสมัคร ยืนยันอีเมล และลบบัญชีจริงแบบครบวงจรยังต้องซ้อมด้วยบัญชีทดสอบของผู้ใช้ก่อนบันทึกวิดีโอ ผลทดสอบจำลองไม่ได้เป็นหลักฐานว่าขั้นตอนนี้ผ่านบน Cloud จริงทั้งหมด', small)

start('2. Schema และความสัมพันธ์')
p('Schema สมาชิกบน Supabase (PostgreSQL) ใช้ UUID ของ auth.users เป็นตัวเชื่อมหลัก')
# Compact ER diagram; labels use the exact deployed table names.
top = y
def box(x, center, width, label, key):
    c.setFillColor(HexColor('#EAF1FC'))
    c.setStrokeColor(BLUE)
    c.roundRect(x, center - 20, width, 40, 5, fill=1, stroke=1)
    c.setFillColor(NAVY)
    c.setFont('Thai', 10)
    c.drawCentredString(x + width/2, center + 3, label)
    c.setFont('Thai', 8)
    c.drawCentredString(x + width/2, center - 10, key)
box(44, top-61, 120, 'auth.users', 'PK: id')
box(211, top-61, 120, 'profiles', 'PK / FK: id')
for center, label, key in [(top-17, 'account_devices', 'FK: user_id'), (top-61, 'sos_records', 'FK: owner_id'), (top-105, 'media_records', 'FK: owner_id')]:
    box(406, center, 145, label, key)
    c.setStrokeColor(BLUE)
    c.line(331, top-61, 371, top-61)
    c.line(371, top-61, 371, center)
    c.line(371, center, 406, center)
    c.setFillColor(GRAY)
    c.setFont('Thai', 7)
    c.drawString(379, center+4, '1:N')
c.line(164, top-61, 211, top-61)
c.setFont('Thai', 8)
c.drawString(178, top-55, '1:1')
y -= 137
table(['ตารางต้นทาง', 'ความสัมพันธ์', 'ตารางปลายทาง / Foreign key'], [
    ['auth.users', '1 : 1', 'profiles.id references auth.users.id'],
    ['profiles', '1 : N', 'account_devices.user_id references profiles.id'],
    ['profiles', '1 : N', 'sos_records.owner_id references profiles.id'],
    ['profiles', '1 : N', 'media_records.owner_id references profiles.id'],
    ['account_devices', '1 : N', 'owned_records.(owner_id, installation_id) references account_devices.(user_id, installation_id)'],
], [130, 70, W-288])
p('Primary key: profiles ใช้ id; account_devices ใช้ (user_id, installation_id); sos_records และ media_records ใช้ (owner_id, id)')
p('Foreign key หลักกำหนด ON DELETE CASCADE เมื่อบัญชีใน auth.users ถูกลบ โปรไฟล์และข้อมูลลูกที่เกี่ยวข้องจึงถูกลบตาม ส่วน Storage ต้องลบไฟล์ผ่าน Storage API ก่อนลบบัญชี')
p('ฐานข้อมูลในเครื่อง: accounts.db เก็บรหัสการติดตั้งและบัญชีที่เป็นเจ้าของไฟล์ฐานข้อมูล แต่ละบัญชีมีไฟล์ SQLite แยกกัน ภายในมี settings, peers, messages, sos_records, sos_queue และข้อมูลสื่อ/คิว relay')
p('ข้อมูล session เก็บผ่าน flutter_secure_storage ไม่เก็บรหัสผ่านใน SQLite ไม่ฝังกุญแจ service_role หรือ secret key ในแอป')
p('ตาราง owned_records เป็นโครงสร้างเตรียมไว้ การมีตารางนี้ไม่หมายถึงข้อความแชตถูกซิงก์แล้ว ข้อความแชตปัจจุบันยังเก็บและรับส่งระหว่างเครื่อง', small)

start('3. Data dictionary')
table(['ตาราง', 'คอลัมน์ / ชนิด', 'ความหมาย'], [
    ['profiles', 'id: uuid (PK, FK)<br/>display_name: text<br/>created_at: timestamptz', 'โปรไฟล์สมาชิก ชื่อยาวไม่เกิน 100 ตัวอักษร; trigger สร้างแถวหลังสมัคร'],
    ['account_devices', 'user_id: uuid<br/>installation_id: uuid<br/>radio_identity: uuid<br/>linked_at, last_seen_at: timestamptz', 'บัญชีที่ผูกกับการติดตั้งแอป และรหัสสำหรับสื่อสาร Nearby; ไม่ใช่รหัสฮาร์ดแวร์'],
    ['sos_records (Cloud)', 'owner_id, id: uuid<br/>payload: jsonb<br/>version: bigint<br/>deleted: boolean<br/>updated_at: timestamptz', 'เหตุ SOS ของเจ้าของ พร้อมเวอร์ชันและเครื่องหมายลบ; payload เก็บชื่อ ประเภท จำนวนคน รายละเอียด และพิกัดถ้ามี'],
    ['media_records', 'owner_id, id, message_id: uuid<br/>file_name, mime_type, checksum: text<br/>file_size: bigint', 'ข้อมูลไฟล์ที่อัปโหลดสำเร็จและตรวจ checksum แล้ว ไฟล์จริงอยู่ใน bucket chat-media'],
    ['sos_queue (SQLite)', 'operation_id, record_id: TEXT<br/>base_version: INTEGER<br/>payload: TEXT<br/>deleted, attempts, blocked: INTEGER<br/>error: TEXT', 'คิวคำสั่งรอส่งบนเครื่อง ใช้ operation_id กันคำสั่งซ้ำ และ base_version ตรวจ conflict'],
    ['messages (SQLite)', 'id, senderId, receiverId, text, timestamp, type, status', 'ข้อความและสถานะการส่งระหว่างอุปกรณ์ เก็บในฐานข้อมูลเครื่องของบัญชี'],
], [100, 185, W-373])

start('4. การทำ CRUD สมาชิก')
p('Create: ฟอร์มตรวจชื่อ อีเมล รหัสผ่าน และการยืนยันรหัสผ่าน  ->  Supabase Auth signUp  ->  auth.users  ->  trigger สร้าง profiles  ->  ผู้ใช้ยืนยันอีเมลตามการตั้งค่าระบบ')
p('Login: signInWithPassword  ->  ได้ session / User UID  ->  เลือกฐานข้อมูล SQLite ของบัญชี  ->  upsert account_devices  ->  Chrome เปิดหน้าข้อมูลสมาชิก')
p('Read: หน้า “ข้อมูลสมาชิก” ใช้ SELECT id, display_name FROM profiles โดยกรอง id เท่ากับบัญชีที่ Login พร้อมแสดงอีเมลและ UID ปุ่มโหลดใหม่อ่านค่าจาก Cloud อีกครั้ง')
p('Update: ตรวจชื่อไม่ว่างและไม่เกิน 100 ตัวอักษร  ->  UPDATE profiles SET display_name โดยกรอง id ของตนเอง  ->  อ่านค่าที่ฐานข้อมูลตอบกลับ  ->  แสดงข้อความบันทึกสำเร็จ')
p('Delete: ผู้ใช้เลือก “ลบบัญชีถาวร” และกรอกรหัสผ่าน  ->  แอปเรียก Edge Function delete-account  ->  เซิร์ฟเวอร์ตรวจ JWT กับ Auth และตรวจรหัสผ่านอีกครั้ง  ->  ใช้เฉพาะ user.id ที่ตรวจได้  ->  ลบไฟล์ Cloud ของบัญชี  ->  เพิกถอน session  ->  Admin API ลบ auth.users  ->  FK ลบข้อมูลลูก  ->  แอปออกจากบัญชีและลบฐานข้อมูลของเจ้าของในเครื่อง')
p('การป้องกันสิทธิ์: ใช้ RLS profiles_owner โดย auth.uid() ต้องตรงกับ profiles.id ทั้ง USING และ WITH CHECK; Edge Function เปิด verify_jwt และตรวจตัวตนซ้ำก่อนงานที่ใช้กุญแจผู้ดูแล')
p('Logout เพียงจบ session และกลับ Guest ไม่ใช่ Delete ส่วนรหัสผ่านของฟอร์มยืนยันลบใช้ส่งเพื่อยืนยันกับ Auth และไม่บันทึกลง log หรือฐานข้อมูลของแอป', small)

start('5. Sync, error handling และข้อจำกัด')
p('SOS ทำงานตามเส้นทาง UI  ->  SQLite sos_records + sos_queue ภายใน transaction  ->  sync_sos บน Supabase  ->  Cloud ยืนยันผล  ->  ลบคำสั่งจากคิว  ->  ดึงข้อมูล Cloud กลับมา merge')
table(['กรณี', 'พฤติกรรม'], [
    ['ไม่มีอินเทอร์เน็ต', 'SOS ยังบันทึกในเครื่องได้ คิวคงอยู่และลองซิงก์ใหม่เมื่อเชื่อมต่อได้; โปรไฟล์สมาชิกต้องออนไลน์'],
    ['ผลตอบกลับหาย / ส่งซ้ำ', 'ใช้ operation_id เดิมและ receipt ฝั่ง Cloud ป้องกันทำรายการซ้ำ'],
    ['แก้ไขหลายเครื่อง', 'ตรวจ base_version; เมื่อ conflict ให้ผู้ใช้เลือกข้อมูลเครื่องหรือ Cloud'],
    ['ลบ SOS', 'เก็บ deleted = true บน Cloud ป้องกันข้อมูลเก่าจากเครื่องออฟไลน์กลับมาสร้างรายการ'],
    ['ชื่อว่าง / รหัสผิด', 'ฟอร์มไม่บันทึกชื่อว่าง; การยืนยันลบด้วยรหัสผิดไม่ลบบัญชี'],
    ['โหลด / บันทึกไม่สำเร็จ', 'แสดง error และให้ลองใหม่ ไม่แสดงสำเร็จก่อนฐานข้อมูลตอบกลับ'],
], [140, W-228])
p('การทดสอบ: Flutter regression ทั้งโปรเจกต์ผ่าน 144 tests ข้าม 4 live tests; Node 8 tests ของบริการลบบัญชีผ่าน ครอบคลุมการยกเลิก/รหัสผิด ตัวตนผิด การปลอมเป้าหมาย การลบเฉพาะไฟล์เจ้าของ และการลบฐานข้อมูลโดยไม่กระทบบัญชีอื่น Supabase security advisor ไม่พบรายการแจ้งเตือน', small)
p('ขอบเขตที่ยังไม่ได้ทำ: ข้อความแชตยังไม่มี Cloud Sync; Nearby ต้องทดสอบบน Android จริง; บัญชีสมาชิก CRUD บน Chrome ต้องซ้อมผ่านอีเมลจริงก่อนอัด ส่วนไฟล์สื่อเก่าที่เก็บในเครื่อง Androidไม่ได้ถูกลบเป็นไฟล์โดยฟังก์ชันลบฐานข้อมูลนี้', small)

start('6. ลำดับวิดีโอและหลักฐาน')
table(['ลำดับ', 'สิ่งที่แสดง / สิ่งที่พูด'], [
    ['1. แนะนำ', 'RescueLink ใช้ SQLite และ Supabase วันนี้สาธิต CRUD สมาชิกผ่าน Chrome'],
    ['2. สมัคร', 'สร้างบัญชีทดสอบชื่อ Week3 Demo; แสดง Users และ profiles ของบัญชีใหม่ ยืนยันอีเมลก่อน Login ถ้าจำเป็น'],
    ['3. Login / Read', 'ลองรหัสผิดหนึ่งครั้ง แล้ว Login ถูกต้อง; แสดงหน้าข้อมูลสมาชิก อีเมล UID และชื่อที่อ่านจากฐานข้อมูล'],
    ['4. Update', 'แก้ชื่อเป็น Week3 Updated แล้วบันทึก; Refresh profiles ให้เห็น display_name เปลี่ยน โดย id เดิม'],
    ['5. Schema', 'เปิด Schema / PDF อธิบาย auth.users  ->  profiles  ->  account_devices และข้อมูลเหตุ SOS'],
    ['6. Delete', 'ลบบัญชีทดสอบผ่านแอปด้วยรหัสผ่านปัจจุบัน; แสดงว่ากลับหน้า Login และแถวบัญชี/โปรไฟล์หายจาก Supabase'],
    ['7. ปิดท้าย', 'อธิบาย SOS local-first + คิว Sync และแยกแชต Nearby ที่ยังไม่ซิงก์ Cloud'],
], [105, W-193])
p('ก่อนอัด: ใช้บัญชีทดสอบที่ยอมลบได้ ซ้อมครบหนึ่งรอบ เตรียม Supabase project RescueLink และตาราง profiles, account_devices เปิดไว้ ไม่โชว์รหัสผ่านหรือ token; ใส่รายชื่อสมาชิกกลุ่มในระบบส่งงานหรือหน้าปกเพิ่มเติมตามรูปแบบของวิชา', small)
p('แหล่งอ้างอิง', heading, 6)
p('Supabase: User Management<br/>https://supabase.com/docs/guides/auth/managing-user-data<br/>Securing Edge Functions<br/>https://supabase.com/docs/guides/functions/auth<br/>Auth Admin deleteUser<br/>https://supabase.com/docs/reference/javascript/auth-admin-deleteuser', small)
c.save()
print(OUT)
