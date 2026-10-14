"""Create reviewed Thai Week 3 submission and recording guide from current source."""
from pathlib import Path
import sys, json
from xml.sax.saxutils import escape
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tmp/pdf-deps'))
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph, Table, TableStyle
from reportlab.lib.colors import HexColor, white
from reportlab.lib.pagesizes import A4

OUT = ROOT / 'output/pdf'
OUT.mkdir(parents=True, exist_ok=True)
pdfmetrics.registerFont(TTFont('Thai', str(ROOT / 'assets/fonts/NotoSansThai.ttf')))
W,H=A4
INK=HexColor('#142D42'); BLUE=HexColor('#2463A8'); MUTED=HexColor('#586C7F')
BODY=ParagraphStyle('body',fontName='Thai',fontSize=10.5,leading=17,wordWrap='CJK',shaping=True,textColor=INK)
SMALL=ParagraphStyle('small',parent=BODY,fontSize=9,leading=14)
HEAD=ParagraphStyle('head',parent=BODY,fontSize=18,leading=28,textColor=BLUE)
SUB=ParagraphStyle('sub',parent=BODY,fontSize=12,leading=19,textColor=BLUE)

class PDF:
    def __init__(self,name,total):
        self.c=canvas.Canvas(str(OUT/name),pagesize=A4); self.page=0; self.total=total
        self.c.setTitle('RescueLink | Advanced Programming | Week 3 | 10 October 2026')
        self.c.setAuthor('RescueLink project')
    def start(self,title):
        if self.page: self.c.showPage()
        self.page+=1; c=self.c
        c.setFillColor(INK); c.rect(0,H-61,W,61,fill=1,stroke=0)
        c.setFillColor(white); c.setFont('Thai',13)
        c.drawString(42,H-38,'RescueLink | Advanced Programming | Week 3',shaping=True)
        c.setFillColor(MUTED); c.setFont('Thai',8)
        c.drawString(42,26,'ตรวจโค้ด 10 ตุลาคม 2569 | กำหนดส่งวันนี้ 23:59 (เวลาไทย)',shaping=True)
        c.drawRightString(W-42,26,f'{self.page} / {self.total}')
        self.y=H-89; self.p(title,HEAD,17)
    def p(self,text,style=BODY,gap=10):
        p=Paragraph(text,style); _,h=p.wrap(W-84,H)
        if self.y-h<52: raise RuntimeError(f'Overflow page {self.page}: {text[:50]}')
        p.drawOn(self.c,42,self.y-h); self.y-=h+gap
    def table(self,headers,rows,widths):
        data=[[Paragraph(str(v),SMALL) for v in r] for r in [headers]+rows]
        t=Table(data,colWidths=widths,repeatRows=1)
        t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),HexColor('#EAF1F9')),('VALIGN',(0,0),(-1,-1),'TOP'),('GRID',(0,0),(-1,-1),.4,HexColor('#CCD8E3')),('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6)]))
        _,h=t.wrap(W-84,H)
        if self.y-h<52: raise RuntimeError(f'Table overflow {self.page}')
        t.drawOn(self.c,42,self.y-h); self.y-=h+15
    def save(self):
        assert self.page==self.total
        self.c.save()

def report():
    d=PDF('rescuelink-week3-report-latest.pdf',9)
    d.start('1. รายงานความคืบหน้าและขอบเขตงาน')
    d.p('โครงงาน RescueLink: แอปแจ้งเหตุ SOS และสื่อสารระหว่างอุปกรณ์ใกล้เคียง พัฒนาด้วย Flutter / Dart ใช้ Supabase Auth และ PostgreSQL สำหรับสมาชิกและ Cloud Sync ใช้ SQLite สำหรับข้อมูลและคิวบนเครื่อง')
    d.p('รายวิชา Advanced Programming | รายงานสัปดาห์ที่ 3<br/>จัดทำจาก working tree วันที่ 10 ตุลาคม 2569 รวมการแก้ไขที่ยังไม่ commit; commit ฐาน f254434 จึงอาจต่างจากเอกสาร Week 3 รุ่นวันที่ 8 ตุลาคม')
    d.table(['ข้อกำหนดงาน','ส่วนที่เตรียมสาธิต'],[
        ['เชื่อมต่อฐานข้อมูล','เปิดแอปคู่กับ Supabase Dashboard และตรวจ User ID ของบัญชีทดสอบ'],
        ['Create','สมัคร 3 ขั้นตอน: บัญชี / ส่วนตัว / สุขภาพ ยืนยันอีเมลก่อน Login ตามการตั้งค่า'],
        ['Read / Login','เข้าสู่ระบบ แล้วอ่าน profiles ด้วย id ของผู้ใช้ปัจจุบัน'],
        ['Update','แก้ชื่อสมาชิก กดบันทึกข้อมูลสมาชิก แล้ว Refresh profiles ให้เห็นค่าเปลี่ยน'],
        ['Delete','ยืนยันรหัสผ่าน เรียก delete-account แล้วตรวจบัญชีและแถวโปรไฟล์หาย'],
        ['Schema และส่วนอื่น','ER diagram, data dictionary, สถาปัตยกรรม, สิทธิ์, sync, ผลตรวจและข้อจำกัด'],
    ],[115,W-199])
    d.p('ชื่อผู้จัดทำและรหัสนักศึกษาไม่ได้ปรากฏในคำขอ จึงไม่ระบุข้อมูลส่วนนี้โดยคาดเดา สามารถกรอกในคำอธิบายงานส่งและกล่าวตอนเริ่มคลิปได้',SMALL)
    d.p('หลักฐานในรายงานเป็นการตรวจซอร์สและการทดสอบที่ระบุไว้ ไม่ใช่ภาพยืนยัน CRUD จริงบน Cloud ในรอบนี้ ผู้จัดทำต้องอัดผลจริงของบัญชีทดสอบประกอบคลิป',SMALL)

    d.start('2. สถาปัตยกรรมและการเชื่อมต่อ')
    d.table(['ชั้นระบบ','หน้าที่ / ไฟล์หลัก'],[
        ['Flutter UI','register_screen.dart, login_screen.dart, member_screen.dart, emergency_profile_screen.dart'],
        ['Authentication','auth_service.dart สร้าง SupabaseClient จาก SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY; signUp และ signInWithPassword'],
        ['Member repository','member_service.dart อ่านและแก้ profiles โดยกรอง id เท่ากับเจ้าของ session'],
        ['PostgreSQL / RPC','profiles, emergency_medical_profiles, sos_records, chat_records และ RPC save_rescue_profile / sync_sos / sync_chat'],
        ['Edge Function','supabase/functions/delete-account/index.ts ตรวจตัวตนและรหัสผ่านก่อนงานลบบัญชี'],
        ['Local storage','SQLite แยกตามบัญชี; secure storage เก็บ session และสำเนา/คิวข้อมูลส่วนตัวและสุขภาพ'],
        ['Nearby / Media','Android Nearby รับส่งข้อมูลระหว่างเครื่อง; Supabase Storage เก็บไฟล์ที่เลือกอัปโหลด'],
    ],[115,W-199])
    d.p('เส้นทางสมาชิก: UI → AuthService / MemberRepository → Supabase Auth / Data API → PostgreSQL → ผลตอบกลับ → UI')
    d.p('เส้นทางออฟไลน์: UI → SQLite + คิว → เมื่อออนไลน์จึงส่ง RPC → Cloud ตอบกลับ → อัปเดตเวอร์ชันและคิว ส่วนข้อมูลสุขภาพใช้ secure storage และ RPC save_rescue_profile แยกจากคิว SQLite')
    d.p('tool/flutter.ps1 โหลด config/supabase.local.json สำหรับ build/run โดยอัตโนมัติ แสดงเพียงชื่อค่าตั้งค่าในการนำเสนอ ไม่เปิดค่ากุญแจหรือไฟล์บัญชีทดสอบ รหัสผ่านไม่ถูกเก็บในตาราง profiles ของแอป')
    d.p('โค้ด Login ล่าสุดนำไป NearbyTestScreen แล้วเปิดแท็บ “ฉัน” เพื่อเข้าหน้าข้อมูลสมาชิก ไม่มีเงื่อนไขให้ Chrome ไป MemberScreen โดยตรงเหมือนคู่มือเก่า Nearby ต้องใช้ Android จริง',SMALL)

    d.start('3. ER diagram และ Foreign key')
    c=d.c; top=d.y
    def box(x,y,w,label,sub):
        c.setFillColor(HexColor('#EAF1F9')); c.setStrokeColor(BLUE)
        c.roundRect(x,y,w,40,5,fill=1,stroke=1)
        c.setFillColor(INK); c.setFont('Thai',9); c.drawCentredString(x+w/2,y+25,label)
        c.setFont('Thai',7); c.drawCentredString(x+w/2,y+11,sub)
    box(42,top-73,145,'auth.users','PK id');box(42,top-167,145,'profiles','PK / FK id')
    c.setStrokeColor(BLUE);c.line(114,top-73,114,top-127);c.setFont('Thai',8);c.drawString(124,top-103,'1 : 0..1')
    children=[('emergency_medical_profiles','id','1 : 0..1'),('account_devices','user_id','1 : N'),('sos_records','owner_id','1 : N'),('chat_records','owner_id','1 : N'),('media_records','owner_id','1 : N'),('owned_records','owner_id','1 : N')]
    c.line(187,top-147,243,top-147);c.line(243,top-29,243,top-259)
    for i,(label,key,card) in enumerate(children):
        x=307; y=top-49-i*46
        box(x,y,204,label,'FK '+key)
        c.line(243,y+20,x,y+20)
        c.setFillColor(MUTED);c.setFont('Thai',7);c.drawString(252,y+25,card)
    d.y=top-300
    d.table(['ต้นทาง','ปลายทาง / Foreign key'],[
        ['auth.users.id','profiles.id (PK และ FK)'],
        ['profiles.id','emergency_medical_profiles.id (PK และ FK)'],
        ['profiles.id','account_devices.user_id; sos_records / chat_records / media_records / owned_records.owner_id'],
        ['account_devices','owned_records.(owner_id, installation_id) → (user_id, installation_id)'],
        ['profiles.id','sync_private.sos_receipts.owner_id และ chat_receipts.owner_id'],
    ],[130,W-214])
    d.p('FK จากบัญชีไปโปรไฟล์และจากโปรไฟล์ไปข้อมูลลูกข้างต้นใช้ ON DELETE CASCADE ส่วน composite FK ของ owned_records → account_devices ไม่ได้กำหนด cascade แยก ไฟล์ Storage ต้องลบผ่าน API ไม่ได้หายด้วย FK ของตาราง public',SMALL)
    d.p('ความสัมพันธ์ 1 : 0..1 หมายถึงมีได้ไม่เกินหนึ่งแถว โดย trigger สร้าง profiles ตอนสมัคร และตารางสุขภาพอาจไม่มีแถวหากไม่ยินยอมหรือถอนความยินยอม',SMALL)

    d.start('4. Data dictionary: สมาชิกและสุขภาพ')
    d.p('public.profiles',SUB)
    d.table(['คอลัมน์','ชนิด / ข้อกำหนด'],[
        ['id','uuid, PK, FK → auth.users.id, ON DELETE CASCADE'],
        ['display_name','text, NOT NULL, default ว่าง, CHECK ความยาว ≤ 100; หน้าสมาชิกปัจจุบันแก้ได้ 1-80'],
        ['created_at','timestamptz, NOT NULL, default now()'],
        ['full_name / phone','text, NOT NULL, default ว่าง; จำกัด 200 / 30 ตัวอักษร'],
        ['date_of_birth','date, nullable; CHECK ไม่เกิน current_date'],
        ['terms_version / terms_accepted_at','text / timestamptz, nullable; รุ่นนโยบายและเวลารับเงื่อนไข'],
    ],[165,W-249])
    d.p('public.emergency_medical_profiles',SUB)
    d.table(['คอลัมน์','ชนิด / ข้อกำหนด'],[
        ['id','uuid, PK, FK → profiles.id, ON DELETE CASCADE'],
        ['blood_group / rh_factor','text, nullable; A/B/AB/O/ไม่ทราบ และ Positive (+)/Negative (-)/ไม่ทราบ'],
        ['medical_conditions / allergies / medications / medical_notes','text, nullable, แต่ละช่อง ≤ 2000 ตัวอักษร'],
        ['emergency_contact_name / phone / relation','text, nullable, จำกัด 200 / 30 / 100 ตัวอักษรตามลำดับ (ชื่อคอลัมน์มี prefix emergency_contact_)'],
        ['health_consent / consent_at','boolean NOT NULL default false / timestamptz nullable'],
        ['created_at / updated_at','timestamptz NOT NULL default now(); trigger อัปเดต updated_at'],
    ],[165,W-249])
    d.p('emp_consent_required บังคับว่าถ้ามีข้อมูลสุขภาพต้อง health_consent=true และมี consent_at; ถ้าไม่ยินยอม ช่องสุขภาพและผู้ติดต่อทั้งหมดต้อง NULL ข้อมูลสุขภาพแยกจาก Auth metadata และ Nearby payload',SMALL)

    d.start('5. Data dictionary: Cloud และ Storage')
    d.table(['ตาราง','คอลัมน์ / หน้าที่'],[
        ['account_devices','user_id uuid FK; installation_id uuid; radio_identity uuid; linked_at และ last_seen_at timestamptz default now(). PK (user_id, installation_id)'],
        ['sos_records และ chat_records','owner_id uuid FK; id uuid; payload jsonb; version bigint CHECK > 0; deleted boolean default false; updated_at timestamptz default now(). PK (owner_id, id)'],
        ['media_records','owner_id uuid FK; id และ message_id uuid; file_name text 1-255; mime_type text image/* หรือ video/*; file_size bigint 1-52428800; checksum text SHA-256 แบบ hex 64 ตัว; created_at timestamptz. PK (owner_id, id)'],
        ['owned_records','owner_id และ id uuid (composite PK); installation_id uuid (composite FK กับ owner_id); kind text message/sos; payload jsonb object; revision bigint > 0 default 1; created_at timestamptz default now(); deleted_at timestamptz nullable'],
        ['sync_private.sos_receipts และ chat_receipts','owner_id uuid FK; operation_id uuid; request และ response jsonb. PK (owner_id, operation_id). เก็บผลคำสั่งเพื่อป้องกันการทำซ้ำ'],
        ['Storage: chat-media','private bucket; สูงสุด 50 MiB ต่อไฟล์; รูป/วิดีโอตาม MIME ที่ migration อนุญาต; path แยกตาม User ID และมี ownership policy'],
    ],[125,W-209])
    d.p('owned_records เป็นโครงสร้างพื้นฐานที่เตรียมไว้ บริการ sync ปัจจุบันใช้ sos_records และ chat_records โดยเฉพาะ ไม่ควรอธิบาย owned_records ว่าเป็นตารางที่เก็บประวัติแชตจริงในปัจจุบัน',SMALL)
    d.p('payload เป็น JSONB สำหรับรายละเอียดเหตุหรือสำเนาประวัติแชต ส่วน Cloud history เป็นข้อมูลส่วนตัวของเจ้าของ ไม่ใช่ระบบส่งแชตผ่านอินเทอร์เน็ตให้ผู้รับ',SMALL)

    d.start('6. ข้อมูลในเครื่องและคิวออฟไลน์')
    d.table(['ส่วนจัดเก็บ','Schema / หน้าที่สำคัญ'],[
        ['accounts.db','installation(id TEXT PK), owners(owner TEXT PK, file TEXT NOT NULL UNIQUE); เลือกไฟล์ฐานข้อมูลตามบัญชี'],
        ['settings / peers','settings(key TEXT PK, value TEXT); peers(id TEXT PK, name TEXT)'],
        ['messages','id TEXT PK; senderId, senderName, receiverId, text, timestamp, type, status เป็น TEXT; ackFor TEXT nullable. เก็บข้อความรับส่ง Nearby'],
        ['sos_records / chat_records (SQLite)','id TEXT PK; payload TEXT; version INTEGER; deleted INTEGER default 0; conflict TEXT nullable'],
        ['sos_queue / chat_queue','seq INTEGER PK AUTOINCREMENT; operation_id TEXT UNIQUE; record_id TEXT; base_version INTEGER; payload TEXT; deleted INTEGER; attempts default 0; error TEXT; blocked default 0'],
        ['media_files','mediaId TEXT PK; messageId, senderId, senderName, receiverId, fileName, mimeType, checksum, localPath, createdAt, status; fileSize / bytesTransferred / retryCount เป็น INTEGER; errorMessage TEXT'],
        ['relay queues / relay_seen','relay_queue และ relay_ack_queue เก็บ packet / ACK / ปลายทาง / จำนวน retry; relay_seen(id TEXT PK) กันรับ packet ซ้ำ'],
        ['Secure storage','session และ PKCE; สำเนาโปรไฟล์และคิวสุขภาพแยกตาม project / User ID ผ่าน SecureProfileVault'],
    ],[125,W-209])
    d.p('การเปลี่ยนเหตุ SOS / ประวัติแชตบันทึกข้อมูลพร้อมคิวใน transaction แล้วส่ง operation_id และ base_version ไป RPC มี receipt กันซ้ำ ตรวจ version conflict และ tombstone deleted เพื่อป้องกันข้อมูลลบกลับมา',SMALL)
    d.p('Local กับ Cloud เป็นคนละฐานข้อมูล ชื่อ sos_records / chat_records ซ้ำกันแต่ชนิดข้อมูลต่างกัน การแก้หรือลบ Cloud history ไม่แก้ข้อความที่ส่งถึงเครื่องรับไปแล้ว',SMALL)

    d.start('7. CRUD สมาชิกและการควบคุมสิทธิ์')
    d.table(['การทำงาน','ลำดับตามซอร์สปัจจุบัน'],[
        ['Create','Register ตรวจข้อมูล 3 ขั้นตอนและเงื่อนไข → auth.signUp → auth.users → on_auth_user_created / private.create_member_profile สร้าง profiles; สุขภาพที่ยินยอมรอซิงก์หลังมี session'],
        ['Login / Read','signInWithPassword → session → เลือก Local DB → linkInstallation upsert account_devices → หน้าหลัก → ฉัน → ข้อมูลสมาชิก; SELECT profiles(id, display_name) WHERE id=owner'],
        ['Update','trim และตรวจชื่อ 1-80 → UPDATE profiles.display_name WHERE id=owner → SELECT ผลกลับ → อัปเดตชื่อใน settings ของเครื่อง'],
        ['ข้อมูลส่วนตัว / สุขภาพ','EmergencyProfileService เก็บคิวใน vault → RPC save_rescue_profile อัปเดต profiles และ upsert สุขภาพถ้ายินยอม; ถ้าไม่ยินยอม RPC ลบแถวสุขภาพ'],
        ['Delete','functions.invoke(delete-account) ส่ง password และ confirmation=DELETE → ตรวจ token กับ Auth → ยืนยันรหัสผ่านและเทียบ UID → ลบไฟล์เจ้าของ → global logout → Admin API ลบ Auth user → cascade → signOut / ล้าง vault / removeOwner'],
    ],[100,W-184])
    d.p('RLS: profiles_owner ตรวจ auth.uid()=id; emp_owner ตรวจ auth.uid()=id; ตารางที่ใช้ owner_id จำกัดตามเจ้าของทั้ง USING / WITH CHECK ตาม policy. sos_records และ chat_records ให้ client อ่านของตนเอง แต่การเขียนผ่าน RPC ที่ตรวจเวอร์ชัน')
    d.p('กุญแจ service role ใช้ใน Edge runtime เท่านั้น Client ไม่เลือก user_id เป้าหมายของการลบ Logout เป็นการจบ session ส่วน Delete คือการลบบัญชีถาวร การบันทึกชื่อในเครื่อง (ใช้ออฟไลน์) ยังไม่ได้เขียน profiles บน Cloud',SMALL)
    d.p('ลบหลายบริการไม่ใช่ transaction เดียว หากล้มเหลวระหว่างขั้นตอนอาจมีการลบไฟล์สำเร็จไปบางส่วนแล้ว การ global logout เพิกถอน session แต่ไม่ควรกล่าวว่า JWT ที่ออกแล้วหมดอายุทันทีทุกกรณี',SMALL)

    d.start('8. ผลตรวจ ความเสี่ยง และงานถัดไป')
    status=json.loads((ROOT/'output/week3-latest-status.json').read_text(encoding='utf-8'))
    d.p('ผลตรวจรอบนี้ (10 ตุลาคม 2569)',SUB)
    d.p(escape(status['tests']))
    d.p(escape(status['analyze']))
    d.p('ตรวจ schema จาก migrations และเทียบกับ Dart services / หน้าจอ ไม่ได้อ่านฐานข้อมูลจริงหรือทำ signup/delete บน Cloud ในรอบนี้ จึงแยกผลตรวจซอร์สและ automated tests ออกจากหลักฐานในวิดีโอ')
    d.p('ผลเดิมที่ใช้เป็นบริบท',SUB)
    d.p('docs/AUTH_MEDICAL_PROFILE_VERIFICATION.md วันที่ 9 ตุลาคม บันทึก 171 tests ผ่านและ 5 live tests skipped, analyzer / APK build ผ่าน และ SQL ownership / consent ผ่าน แต่ Login บัญชีทดสอบเดิมได้ invalid_credentials และยังไม่ได้ตรวจการรับอีเมลจริง ข้อมูลนี้เป็นผลเดิม ไม่ใช่ผลรันซ้ำวันนี้')
    d.table(['ข้อจำกัด','วิธีจัดการก่อนส่ง'],[
        ['อีเมล / Login จริง','ใช้บัญชีทดสอบใหม่ที่เข้ากล่องจดหมายได้ ยืนยันอีเมล และซ้อมให้ครบก่อนอัด'],
        ['Chrome / Android','โค้ด route ล่าสุดใช้ NearbyTestScreen เหมือนกัน ต้องซ้อม Chrome ปัจจุบันก่อน; หาก plugin ขัดขวาง ใช้ Android และบันทึก Dashboard บนคอมพิวเตอร์'],
        ['ลบไฟล์ในเครื่อง','โค้ดลบ Local DB และ vault ของบัญชี ไม่ได้ยืนยันว่าลบไฟล์สื่อที่ดาวน์โหลดบน Android ครบทุกไฟล์'],
        ['ข้อมูลลับในวิดีโอ','ใช้ข้อมูลสมมติ กรองเฉพาะ UID ทดสอบ ไม่เปิด keys, token, รหัสผ่าน หรือข้อมูลบัญชีอื่น'],
        ['ความยาวชื่อไม่ตรงกัน','schema / Register อนุญาต 100 แต่ Member update อนุญาต 80; ใช้ชื่อสั้นในการสาธิต และปรับเกณฑ์ให้สอดคล้องในงานถัดไป'],
    ],[115,W-199])
    d.p('งานถัดไป: ซ้อม CRUD จริง, ตรวจ OTP/email delivery, ทดสอบการซิงก์กลับออนไลน์และ Nearby ด้วย Android สองเครื่อง และตรวจ cleanup ไฟล์ในเครื่องให้ครบ',SMALL)

    d.start('9. หลักฐานในคลิปและแหล่งที่ตรวจ')
    d.table(['ก่อน / หลัง','หลักฐานที่ควรบันทึก'],[
        ['สมัคร','อีเมลทดสอบปรากฏใน Authentication → Users; profiles.id ตรงกับ UID และชื่อเป็น Week3 Demo'],
        ['เข้าสู่ระบบ / อ่าน','แอปแสดงชื่อเดียวกับ profiles; อีเมลอ่านจาก session ไม่ใช่คอลัมน์ใน profiles'],
        ['แก้ไข','display_name เปลี่ยนเป็น Week3 Updated หลัง Refresh Dashboard; id เดิมและแอปรีเฟรชแล้วยังได้ค่าที่แก้'],
        ['สุขภาพ (เสริม)','หากยินยอมและซิงก์สำเร็จ emergency_medical_profiles.id ตรงกับ profiles.id; หากข้ามสุขภาพอาจไม่มีแถว'],
        ['ลบบัญชี','แอปกลับหน้า Login; ค้น UID เดิมใน Users / profiles / account_devices แล้วไม่พบแถว'],
    ],[105,W-189])
    d.p('แหล่งข้อมูลภายในโปรเจกต์',SUB)
    for line in [
        'lib/services/auth_service.dart, member_service.dart, account_storage.dart',
        'lib/services/emergency_profile_service.dart, emergency_profile_store.dart',
        'lib/services/local_database_service.dart, sos_store.dart, chat_store.dart',
        'lib/screens/register_screen.dart, login_screen.dart, member_screen.dart, settings_panel.dart',
        'supabase/migrations/20260928152738_membership_foundation.sql',
        'supabase/migrations/20260929060828_sos_cloud_sync_verified.sql และ 20260930082212_sos_payload_validation.sql',
        'supabase/migrations/20260930153219_media_private_storage.sql',
        'supabase/migrations/20261008054140_chat_history_cloud_sync.sql',
        'supabase/migrations/20261009070000_emergency_medical_profiles.sql',
        'supabase/functions/delete-account/index.ts; docs/AUTH_MEDICAL_PROFILE_VERIFICATION.md',
        'output/week3-latest-tests.log และ output/week3-latest-analyze.log (ผลตรวจรอบนี้)',
    ]: d.p(escape(line),SMALL,5)
    d.p('PDF นี้เป็นรายงานประกอบส่ง ส่วนบทพูดและการเปิดหน้าจออยู่ใน rescuelink-week3-recording-guide.pdf และ docs/WEEK3_RECORDING_GUIDE_LATEST_TH.md',SMALL)
    d.save()

SCENES=[
('00:00-00:35 | แนะนำโครงงาน',
 'เปิดหน้า Login ของ RescueLink และ PDF รายงานหน้า 1 ก่อนเริ่มกล่าวชื่อและรหัสนักศึกษาของตนเอง',
 'สวัสดีครับ/ค่ะ วันนี้จะนำเสนอความคืบหน้าสัปดาห์ที่ 3 ของโครงงาน RescueLink ในวิชา Advanced Programming ครับ/ค่ะ แอปนี้ใช้แจ้งเหตุ SOS และสื่อสารกับอุปกรณ์ใกล้เคียง พัฒนาด้วย Flutter ใช้ SQLite เก็บข้อมูลในเครื่อง และใช้ Supabase สำหรับระบบสมาชิกและฐานข้อมูลบน Cloud วันนี้จะสาธิตสมัครสมาชิก เข้าสู่ระบบ อ่านและแก้ไขข้อมูลสมาชิก และลบบัญชี พร้อมแสดงข้อมูลจริงในฐานข้อมูลครับ/ค่ะ'),
('00:35-01:15 | แสดงการเชื่อมต่อฐานข้อมูล',
 'แบ่งหน้าจอแอปกับ Supabase Dashboard ของโครงงาน เปิด Table Editor → profiles; เปิดโค้ด auth_service.dart เฉพาะส่วน SupabaseClient และ member_service.dart เฉพาะ read/update ไม่เปิด config จริง',
 'ส่วนนี้คือการสร้าง SupabaseClient จาก URL และ public key ที่ตั้งค่าไว้ และส่วนนี้คือ repository ที่อ่านตาราง profiles โดยกรอง id ให้ตรงกับบัญชีที่เข้าสู่ระบบครับ/ค่ะ เดี๋ยวจะเปรียบเทียบข้อมูลในแอปกับ Dashboard ก่อนและหลังแต่ละรายการ เพื่อยืนยันว่าแอปเชื่อมต่อกับฐานข้อมูลจริง'),
('01:15-02:35 | Create: สมัคร 3 ขั้นตอน',
 'กดสมัครสมาชิก → กรอกอีเมลที่เปิดกล่องจดหมายได้และรหัสผ่านส่วนตัว → ถัดไป → กรอกชื่อ-นามสกุลสมมติและชื่อที่แสดง Week3 Demo → ถัดไป → ข้ามข้อมูลสุขภาพ หรือยินยอมพร้อมข้อมูลสมมติ → ยอมรับข้อกำหนด → สมัครสมาชิก; ไป Authentication → Users และ profiles กรองบัญชีใหม่',
 'การสมัครในรุ่นล่าสุดมีสามขั้นตอน คือข้อมูลบัญชี ข้อมูลส่วนตัว และข้อมูลสุขภาพฉุกเฉินครับ/ค่ะ ช่องรหัสผ่านตรวจอย่างน้อยแปดตัวอักษร มีตัวพิมพ์ใหญ่ พิมพ์เล็ก และอักขระพิเศษ ส่วนความยินยอมสุขภาพแยกจากข้อกำหนดทั่วไปและสามารถข้ามสุขภาพได้ เมื่อสมัคร ระบบเรียก Supabase Auth และ trigger สร้าง profiles ด้วย User ID เดียวกัน ตอนนี้ใน Dashboard จะเห็นบัญชีใหม่และชื่อ Week3 Demo ในตาราง profiles ครับ/ค่ะ'),
('02:35-03:35 | ยืนยันอีเมล / Login / Read',
 'เปิดอีเมลยืนยันเฉพาะข้อความที่จำเป็น ซ่อนลิงก์/OTP → กลับแอปเดิมแล้ว Login → แท็บฉัน → แตะการ์ดข้อมูลสมาชิก → เปิด profiles ที่ id ตรงกับ UID ของบัญชี; หากหน้าเล็กให้เลื่อน',
 'บัญชีนี้ต้องยืนยันอีเมลก่อนใช้งานครับ/ค่ะ ผม/ดิฉันยืนยันเรียบร้อยแล้วและจะเข้าสู่ระบบด้วยอีเมลกับรหัสผ่านเดิม หลังเข้าสู่ระบบให้เปิดแท็บฉันแล้วเข้าข้อมูลสมาชิก หน้านี้อ่านชื่อจาก profiles บน Supabase ส่วนอีเมลมาจาก session ครับ/ค่ะ เราจะเห็นว่าชื่อในแอปตรงกับ Dashboard และใช้ User ID เดียวกัน นี่คือส่วน Read ของ CRUD'),
('03:35-04:25 | Update: แก้ชื่อแล้วพิสูจน์ค่าที่บันทึก',
 'แก้ชื่อเป็น Week3 Updated → กดบันทึกข้อมูลสมาชิก (ปุ่ม Cloud) → รอผลสำเร็จ → Refresh ตาราง profiles → เทียบ id เดิมและ display_name ใหม่ → กดรีเฟรชข้อมูลในแอป',
 'ต่อไปจะเปลี่ยนชื่อจาก Week3 Demo เป็น Week3 Updated แล้วกดบันทึกข้อมูลสมาชิกครับ/ค่ะ ปุ่มนี้เรียก UPDATE ไปยัง profiles ของเจ้าของบัญชี และรอฐานข้อมูลตอบกลับก่อนแจ้งสำเร็จ เมื่อรีเฟรช Dashboard จะเห็นว่าชื่อเปลี่ยนแต่ id ยังเป็นค่าเดิม และโหลดข้อมูลในแอปใหม่ก็ยังได้ชื่อที่แก้ จึงยืนยันว่าค่าถูกบันทึกบนฐานข้อมูลแล้ว หน้าสมาชิกปัจจุบันจำกัดชื่อหนึ่งถึงแปดสิบตัวอักษรครับ/ค่ะ'),
('04:25-05:25 | Schema และส่วนที่พัฒนาเพิ่ม',
 'เปิด PDF หน้า 3-5 ชี้ auth.users → profiles → emergency_medical_profiles / account_devices / sos_records / chat_records / media_records; ถ้ามีเวลาเปิดข้อมูลส่วนตัวและสุขภาพฉุกเฉินจากหน้าสมาชิก',
 'โครงสร้างหลักคือ auth.users เชื่อมกับ profiles ด้วย UUID ครับ/ค่ะ หนึ่งบัญชีมีโปรไฟล์หนึ่งรายการและมีข้อมูลสุขภาพได้ไม่เกินหนึ่งรายการ ส่วนอุปกรณ์ เหตุ SOS ประวัติแชต และสื่อมีได้หลายรายการต่อบัญชี ข้อมูลสุขภาพแยกตารางและจำกัดให้เจ้าของเข้าถึงด้วย RLS ปัจจุบันเพิ่ม Cloud Sync สำหรับประวัติข้อความแล้ว แต่ข้อความระหว่างอุปกรณ์ยังรับส่งผ่าน Nearby การแก้หรือลบประวัติของเราไม่เปลี่ยนข้อความที่อีกเครื่องได้รับไปแล้วครับ/ค่ะ'),
('05:25-06:35 | Delete: ลบบัญชีทดสอบ',
 'กลับข้อมูลสมาชิก → ลบบัญชีถาวร → กรอกรหัสผ่านแบบปิดบัง → ยืนยันลบบัญชี → รอหน้า Login → Refresh Authentication → Users ค้นอีเมลทดสอบ → profiles และ account_devices กรอง UID เดิม',
 'ขั้นตอนสุดท้ายจะลบบัญชีทดสอบนี้ครับ/ค่ะ ระบบขอรหัสผ่านปัจจุบันเพื่อยืนยัน แล้วเรียก Edge Function delete-account ฝั่งเซิร์ฟเวอร์ตรวจตัวตนและรหัสผ่านก่อนลบไฟล์ Cloud ของเจ้าของ เพิกถอน session และลบบัญชี Auth จากนั้น Foreign key แบบ cascade ลบโปรไฟล์และข้อมูลลูก ตอนนี้แอปกลับหน้า Login แล้ว และเมื่อรีเฟรช Dashboard จะไม่พบบัญชีและโปรไฟล์ของ UID เดิมครับ/ค่ะ'),
('06:35-07:05 | ปิดการนำเสนอ',
 'เปิด PDF หน้า 8-9 หรือหน้าปก พร้อมแสดงไฟล์รายงานที่จะส่ง',
 'การสาธิตวันนี้แสดงการเชื่อมต่อฐานข้อมูลและ CRUD สมาชิกครบทั้งสร้าง อ่าน แก้ไข และลบครับ/ค่ะ ส่วนที่พัฒนาเพิ่มคือข้อมูลสุขภาพฉุกเฉินและการซิงก์ข้อมูล สำหรับ SOS และประวัติแชตจะเก็บคิวในเครื่องแล้วซิงก์เมื่อออนไลน์ งานถัดไปคือทดสอบการรับอีเมล การกลับมาออนไลน์ และการเชื่อมต่อ Nearby ด้วยโทรศัพท์จริงสองเครื่อง รายละเอียด schema และผลตรวจอยู่ใน PDF ที่ส่งประกอบครับ/ค่ะ ขอบคุณครับ/ค่ะ'),
]

def guide():
    d=PDF('rescuelink-week3-recording-guide.pdf',6)
    d.start('คู่มืออัดคลิป | เตรียมก่อนเริ่ม')
    d.p('ระยะเวลาประมาณ 7-8 นาที เลือกอ่าน “ครับ” หรือ “ค่ะ” ตามถนัด ปรับชื่อผู้พูดและรหัสนักศึกษาเอง เวลาที่กำหนดเป็นจังหวะคร่าว ๆ สามารถตัดช่วงรออีเมลได้แต่ต้องเล่าและแสดงผลจริง')
    d.p('1. เปิดแอปจากโค้ดล่าสุด ไม่ใช้ APK เก่าที่หน้าจอไม่ตรงกัน ถ้าใช้ Chrome ให้ซ้อมเส้นทางหน้า Login → ฉัน → ข้อมูลสมาชิกก่อน หาก Nearby plugin ขัดขวางให้ใช้ Android แทน')
    d.p('2. เปิด Supabase Dashboard ของโครงงานไว้: Authentication → Users, Table Editor → profiles และ account_devices; ตารางสุขภาพเป็นส่วนเสริม เตรียม PDF รายงานหน้า 3 ไว้สำหรับ schema')
    d.p('3. ใช้บัญชีทดสอบที่เข้ากล่องจดหมายได้และยอมลบได้เท่านั้น ชื่อเริ่มต้น Week3 Demo แล้วแก้เป็น Week3 Updated ใช้ชื่อจริง/เบอร์/สุขภาพสมมติ ไม่ใช้ข้อมูลส่วนตัวจริงในการอัด')
    d.p('4. ซ้อมด้วยบัญชีหนึ่งรอบก่อน แล้วใช้บัญชีทดสอบใหม่สำหรับคลิป หากทำชื่อเดิมซ้ำให้ตรวจว่าเป็น UID ของรอบใหม่ รอคำตอบ Cloud ก่อนพูดว่าสำเร็จ')
    d.p('5. เปิดไมโครโฟน อัดให้ข้อความแอปและตารางอ่านออก บันทึก UID ของบัญชีทดสอบไว้เทียบและกรอง ใช้ debug run หากต้องการให้หน้า Member แสดง User UID')
    d.p('คำสั่งเปิดแอป',SUB)
    d.p('Chrome: .\\tool\\flutter.ps1 run -d chrome --web-port=8090<br/>Android: .\\tool\\flutter.ps1 devices แล้ว run -d ตาม ID ของเครื่องที่แสดง',SMALL)
    d.p('อย่าโชว์ config/supabase.local.json, config/test-account.local.json, API keys, service role, access/refresh token, OTP หรือลิงก์ยืนยันเต็ม กรอง Dashboard ให้เหลือบัญชีทดสอบ โชว์ UID ทดสอบเท่าที่ต้องใช้เทียบข้อมูล',SMALL)
    for start_index in range(0,len(SCENES),2):
        d.start(f'บทพูดและหน้าจอ | ช่วงที่ {start_index+1}-{start_index+2}')
        for title,screen,speech in SCENES[start_index:start_index+2]:
            d.p(title,SUB)
            d.p('<b>เปิด / ทำ:</b> '+escape(screen),SMALL)
            d.p('<b>พูด:</b> “'+escape(speech)+'”')
            d.p('กล่าวว่าสำเร็จเฉพาะเมื่อหน้าจอและ Dashboard แสดงผลตามจริง หากยังไม่สำเร็จให้หยุดแก้ก่อนอัดต่อ',SMALL,14)
    d.start('เช็กลิสต์หลักฐานและทางแก้ตอนซ้อม')
    d.table(['อาการ / จุดตรวจ','สิ่งที่ต้องทำ'],[
        ['สมัครแล้วเข้าไม่ได้','ยืนยันอีเมลก่อน กลับ Login ในแอป/เบราว์เซอร์ที่สมัคร; หากลิงก์ redirect เปิดไม่ได้แต่ยืนยันสำเร็จแล้วให้กลับ Login เอง'],
        ['อีเมลไม่มา','ตรวจ spam / resend และรอ cooldown 60 วินาที ถ้ายังไม่ได้ให้ตรวจ email delivery ก่อนอัด อย่าสร้างบัญชีรัว ๆ'],
        ['ไม่พบข้อมูลสมาชิก','Login ล่าสุดเปิดหน้าหลัก → แท็บ “ฉัน” → แตะการ์ดสมาชิก; คำอธิบาย Chrome ที่เปิด Member โดยตรงเป็นพฤติกรรมเก่า'],
        ['ชื่อไม่เปลี่ยนใน Cloud','ใช้ปุ่ม “บันทึกข้อมูลสมาชิก”; ปุ่ม “บันทึกชื่อในเครื่อง (ใช้ออฟไลน์)” ไม่อัปเดต Cloud ตรวจอินเทอร์เน็ตและ Refresh Dashboard'],
        ['ไม่มีแถวสุขภาพ','หากข้ามสุขภาพเป็นพฤติกรรมที่ถูกต้อง; หากกรอกและยินยอมให้ Login เครื่องเดิมและรอซิงก์'],
        ['ลบไม่ได้','ตรวจรหัสผ่านปัจจุบัน / session / อินเทอร์เน็ต อย่าลบตรง Dashboard แทนขั้นตอนแอปในการสาธิต'],
        ['หลักฐานต้องครบ','Create: Users+profiles; Read: ค่าในแอปตรงตาราง; Update: id เดิมชื่อใหม่; Delete: แอป Login และค้น UID เดิมไม่พบ'],
    ],[125,W-209])
    d.p('ก่อนส่ง: ฟังเสียงครบทุกช่วง ตรวจว่าคลิปเปิดได้ PDF อ่านภาษาไทยได้ และแนบทั้งวิดีโอกับรายงาน schema ชื่อผู้จัดทำให้กล่าวในคลิป/กรอกคำอธิบายงานส่ง กำหนดส่ง 10 ตุลาคม 2569 เวลา 23:59 ประเทศไทย',SMALL)
    d.save()
    md=['# RescueLink: สคริปต์พูด Week 3 (โค้ดล่าสุด 10 ตุลาคม 2569)','',
        'เวลาประมาณ 7-8 นาที ใช้ข้อมูลสมมติและบัญชีทดสอบที่ยอมลบได้ เลือกคำลงท้ายครับ/ค่ะตามถนัด', '',
        'เปิดแอปคู่กับ Supabase Dashboard: Authentication → Users; Table Editor → profiles, account_devices และ emergency_medical_profiles (เสริม)', '',
        'Login รุ่นล่าสุดไปหน้าหลัก แล้วเปิดแท็บ **ฉัน** → การ์ดสมาชิก → **ข้อมูลสมาชิก**; Chrome ต้องซ้อมก่อน ถ้า plugin ขัดขวางใช้ Android', '',
        'คำสั่ง Chrome: `.\\tool\\flutter.ps1 run -d chrome --web-port=8090`', '',
        'ซ่อนรหัสผ่าน, keys, token, OTP และลิงก์ยืนยันเต็ม กรองเฉพาะบัญชีทดสอบ อย่าเปิด config จริง', '']
    for title,screen,speech in SCENES:
        md += ['## '+title,'','**เปิด / ทำ:** '+screen,'','**พูด:**','', '> '+speech,'']
    md += ['## ข้อควรตรวจ','',
        '- ปุ่มบันทึก Cloud คือ “บันทึกข้อมูลสมาชิก”; ปุ่มบันทึกชื่อในเครื่องไม่ได้เขียน Cloud',
        '- รอ Refresh Dashboard แล้วเห็นค่าจริงก่อนพูดว่าสำเร็จ UID ต้องตรงกันทุกขั้น',
        '- หากข้ามสุขภาพ ไม่มีแถวสุขภาพได้; หากกรอกให้ Login เครื่องเดิมเพื่อซิงก์',
        '- ต้องลบบัญชีผ่านแอปพร้อมยืนยันรหัสผ่าน ไม่ลบตรง Dashboard แทนการสาธิต',
        '- ใส่ชื่อผู้จัดทำและรหัสนักศึกษาในคำกล่าวเริ่มต้น/คำอธิบายงานส่ง',
        '- แนบคลิปและ output/pdf/rescuelink-week3-report-latest.pdf ก่อน 23:59 วันที่ 10 ตุลาคม 2569', '']
    (ROOT/'docs/WEEK3_RECORDING_GUIDE_LATEST_TH.md').write_text('\n'.join(md),encoding='utf-8')

if __name__=='__main__':
    report(); guide(); print('Created report (9 pages), recording guide (6 pages), editable Thai script.')
