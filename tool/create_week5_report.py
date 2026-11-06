"""Build the Week 5 report from actual test sources and captured output."""
from pathlib import Path
import sys
from datetime import datetime
from zoneinfo import ZoneInfo
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tmp/pdf-deps'))
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.pagesizes import A4
from reportlab.lib.colors import HexColor
from reportlab.platypus import Paragraph, Table, TableStyle
from reportlab.lib.styles import ParagraphStyle

OUT = ROOT / 'output/pdf/rescuelink-week5.pdf'
OUT.parent.mkdir(parents=True, exist_ok=True)
pdfmetrics.registerFont(TTFont('Thai', str(ROOT / 'assets/fonts/NotoSansThai.ttf')))
W, H = A4
M = 45
WIDTH = W - 2*M
INK = HexColor('#182632')
BLUE = HexColor('#EAF1F9')
BODY = ParagraphStyle('body', fontName='Thai', fontSize=10.3, leading=17,
                      wordWrap='CJK', shaping=True, textColor=INK)
SMALL = ParagraphStyle('small', parent=BODY, fontSize=9, leading=14)
TITLE = ParagraphStyle('title', parent=BODY, fontSize=19, leading=30, alignment=1)
HEAD = ParagraphStyle('heading', parent=BODY, fontSize=14, leading=23)
log = (ROOT / 'output/week5-unit-tests.txt').read_text(encoding='utf-8-sig')
assert '+12: All tests passed!' in log, 'Expected 12 passing tests in real log'
sources = ['test/sos_location_service_test.dart', 'test/week5_sos_location_edge_test.dart']
command = 'flutter test test/sos_location_service_test.dart test/week5_sos_location_edge_test.dart --reporter expanded --concurrency=1'
cases = [
 ('TC01','รับพิกัดใหม่จาก native','lat=14, lon=100, accuracy=12 และเวลาปัจจุบัน','latitude=14, accuracy=12 และ capturedAt ตรงกับต้นฉบับ'),
 ('TC02','ข้อมูลวิเคราะห์ GPS เมื่อ timeout','PlatformException(timeout), GPS เปิด, ดาวเทียม 7 ดวง ใช้คำนวณ 0 ดวง','StateError มีข้อความ GPS เปิด / ดาวเทียม 7 ดวง / ใช้คำนวณ 0 ดวง'),
 ('TC03','ผู้ใช้ไม่อนุญาตตำแหน่ง','requestPermission คืน false','เกิด StateError ที่มีคำว่าสิทธิ์ และไม่เรียก native GPS'),
 ('TC04','แปลงข้อผิดพลาด timeout','PlatformException(code: timeout)','เกิด StateError และข้อความไม่แสดงคำว่า PlatformException'),
 ('TC05','แปลงข้อผิดพลาด disabled','PlatformException(code: disabled)','เกิด StateError และข้อความไม่แสดงคำว่า PlatformException'),
 ('TC06','แปลงข้อผิดพลาด permission','PlatformException(code: permission)','เกิด StateError และข้อความไม่แสดงคำว่า PlatformException'),
 ('TC07','แปลงข้อผิดพลาด canceled','PlatformException(code: canceled)','เกิด StateError และข้อความไม่แสดงคำว่า PlatformException'),
 ('TC08','Dart timeout ยกเลิกแล้วลองใหม่ได้','native ไม่คืนผลภายใน 10 ms จากนั้นเปลี่ยนเป็นพิกัดใหม่','แจ้ง timeoutMessage, เรียก cancel และลองใหม่ได้ longitude=100'),
 ('TC09','ปฏิเสธพิกัดเก่า','capturedAt ย้อนหลัง 1 ชั่วโมง','เกิด StateError แทนการใช้พิกัดเก่าเป็นพิกัดใหม่'),
 ('TC10','ปฏิเสธผลพิกัดว่าง','native คืน null','เกิด StateError พร้อมข้อความพิกัดไม่สมบูรณ์หรือเก่าเกินไป'),
 ('TC11','ปฏิเสธพิกัดเวลาอนาคต','capturedAt ล่วงหน้า 1 ชั่วโมง','เกิด StateError แทนการยอมรับเป็นพิกัดใหม่'),
 ('TC12','แจ้งเมื่อมีคำขอพิกัดกำลังทำงาน','PlatformException(code: busy)','StateError มีข้อความตรงกับ กำลังอ่านตำแหน่ง กรุณารอสักครู่'),
]

class Report:
 def __init__(self):
  self.c = canvas.Canvas(str(OUT), pagesize=A4)
  self.c.setTitle('รายงานความคืบหน้า RescueLink สัปดาห์ที่ 5 - Unit Test')
  self.c.setAuthor('นางสาว เอกวลี ชรินทร์')
  self.page = 0
 def start(self, title):
  if self.page: self.c.showPage()
  self.page += 1
  self.c.setFont('Thai',8)
  self.c.setFillColor(INK)
  self.c.drawString(M,H-29,'RescueLink   Advanced Programming   Week 5',shaping=True)
  self.c.drawRightString(W-M,25,f'หน้า {self.page}',shaping=True)
  self.y = H-65
  self.p(title,HEAD,14)
 def p(self, text, style=BODY, gap=10):
  p = Paragraph(text,style)
  _,h = p.wrap(WIDTH,H)
  if self.y-h < 49: raise RuntimeError(f'Page overflow {self.page}: {text[:35]}')
  p.drawOn(self.c,M,self.y-h)
  self.y -= h+gap
 def table(self, rows):
  data = [[Paragraph(escape(v),SMALL) for v in row] for row in rows]
  t = Table(data, colWidths=[40,103,144,166,WIDTH-453])
  t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),BLUE),('GRID',(0,0),(-1,-1),.4,HexColor('#C9CED4')),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),5),('RIGHTPADDING',(0,0),(-1,-1),5),('TOPPADDING',(0,0),(-1,-1),7),('BOTTOMPADDING',(0,0),(-1,-1),7)]))
  _,h = t.wrap(WIDTH,H)
  if self.y-h < 49: raise RuntimeError('Table overflow')
  t.drawOn(self.c,M,self.y-h)
  self.y -= h+13
 def lines(self, lines, size=8.3, leading=12):
  self.c.setFont('Thai',size)
  for line in lines:
   if self.y-leading < 49: raise RuntimeError('Code overflow')
   self.c.drawString(M,self.y-leading,line,shaping=True)
   self.y -= leading
 def save(self): self.c.save()

def wrapped(lines, size=8.3):
 result=[]
 for line in lines:
  while pdfmetrics.stringWidth(line,'Thai',size)>WIDTH:
   n=len(line)
   while pdfmetrics.stringWidth(line[:n],'Thai',size)>WIDTH: n-=1
   result.append(line[:n])
   line='    '+line[n:]
  result.append(line)
 return result

d=Report()
d.start('รายงานความคืบหน้าโครงงาน สัปดาห์ที่ 5')
d.y-=45
d.p('RescueLink',TITLE,14)
d.p('ผลการทดสอบหน่วยโปรแกรม (Unit Test)',TITLE,36)
d.p('รายวิชา Advanced Programming',TITLE,45)
d.p('จัดทำโดย',TITLE,14)
d.p('นางสาว เอกวลี ชรินทร์',TITLE,48)
d.p('กำหนดส่ง 30 ตุลาคม 2569',TITLE,16)
d.p('ทดสอบบริการอ่านพิกัด SOS จำนวน 12 เคส',TITLE,15)
d.p('ผ่าน 12 เคส | ไม่ผ่าน 0 เคส | ข้าม 0 เคส',TITLE)

d.start('1 วัตถุประสงค์และวิธีทดสอบ')
d.p('โครงงาน RescueLink เป็นแอปแจ้งเหตุ SOS และสื่อสารระหว่างอุปกรณ์ใกล้เคียง พัฒนาด้วย Flutter / Dart รายงานสัปดาห์ที่ 5 นี้เลือกทดสอบ SosLocationService ซึ่งจัดการการอ่านพิกัด การขอสิทธิ์ ข้อผิดพลาดจาก native และการยกเลิกคำขอที่หมดเวลา')
d.p('วัตถุประสงค์: ตรวจว่าบริการรับข้อมูลพิกัดที่ถูกต้อง ปฏิเสธข้อมูลที่ไม่เหมาะสม จัดการกรณีผู้ใช้ไม่อนุญาตสิทธิ์ และรายงานข้อผิดพลาดตามเงื่อนไขที่กำหนด')
d.p('ขอบเขตการทดสอบ',HEAD)
d.p('ใช้ flutter_test และ test(...) เรียก logic ของบริการโดยตรง จำลอง MethodChannel และผลการอนุญาตสิทธิ์ จึงไม่ต้องเชื่อม GPS จริง ไม่ใช้บัญชี Cloud และไม่ใช้ฐานข้อมูลในชุด 12 เคสนี้ การเรียก TestWidgetsFlutterBinding ใช้สำหรับ mock platform channel โดยไม่มีการ pump หน้าจอ')
d.p('TC01-TC09 มาจากไฟล์ทดสอบเดิม ส่วน TC10-TC12 เพิ่มการตรวจข้อมูลว่าง เวลาในอนาคต และสถานะ busy โดย TC04-TC07 สร้างจาก for loop เดียว แต่ test runner ลงทะเบียนและรันเป็น 4 เคสแยกกัน')
d.p('ไฟล์ที่ใช้',HEAD)
for path in ['lib/services/sos_location_service.dart']+sources: d.p(escape(path),SMALL,5)
d.p('คำสั่งรันจริง',HEAD)
d.lines(wrapped([command]),8.3,13)
d.y-=16
d.p('แต่ละเคสเตรียมข้อมูลจำลอง เรียก capture() แล้วตรวจค่าหรือข้อผิดพลาดด้วย expect / expectLater ส่วน tearDown ล้าง mock handler เพื่อไม่ให้ข้อมูลจำลองค้างไปยังเคสถัดไป')
d.p('วันที่รัน: 30 ตุลาคม 2569 | ระบบ Windows / PowerShell | ผลคำสั่ง exit code 0',SMALL)

for part in range(2):
 d.start(f'2 ตารางสรุปผลทดสอบ ({part+1}/2)')
 rows=[['รหัส','สิ่งที่ทดสอบ / ข้อมูลนำเข้า','ผลที่คาดหวัง','ผลจริงจากการตรวจ assertion','สถานะ']]
 for id,title,inputs,expected in cases[part*6:(part+1)*6]:
  rows.append([id,title+'\n'+inputs,expected,'assertion ผ่าน: '+expected,'ผ่าน'])
 d.table(rows)
 d.p('ผลจริงอ้างอิงการผ่าน assertion ของแต่ละเคสจาก test runner ไม่ใช่การบันทึกค่าตัวแปรทุกตัวลง Terminal',SMALL)
 if part==0: d.p('TC04-TC07 ตรวจชนิด StateError และตรวจว่าไม่มีคำว่า PlatformException เท่านั้น ไม่ได้ตรวจข้อความภาษาไทยแบบตรงตัวทุกตัวอักษร',SMALL)

for file in sources:
 lines=(ROOT/file).read_text(encoding='utf-8').splitlines()
 numbered=wrapped([f'{i:03}  {line}' for i,line in enumerate(lines,1)])
 chunks=[numbered[i:i+48] for i in range(0,len(numbered),48)]
 for i,chunk in enumerate(chunks):
  d.start(f'3 โค้ดทดสอบฉบับเต็ม ({i+1}/{len(chunks)})')
  d.p(escape(file),SMALL,6)
  d.p('TC01-TC09; TC04-TC07 ใช้ for loop' if file==sources[0] else 'TC10-TC12 เรียงตามลำดับ test ในไฟล์',SMALL,6)
  d.lines(chunk)

excerpt=log[log.index('00:00 +0: loading'):].strip()
output_lines=wrapped(excerpt.splitlines(),8.2)
chunks=[output_lines[i:i+46] for i in range(0,len(output_lines),46)]
for i,chunk in enumerate(chunks):
 d.start(f'4 หลักฐาน output จากการรันจริง ({i+1}/{len(chunks)})')
 d.p('คัดลอกช่วงเริ่มโหลดไฟล์ทดสอบจนถึงผลสรุปจาก output/week5-unit-tests.txt โดยตัดบรรทัดยาวให้พอดีหน้ากระดาษ ไฟล์ .txt ที่แนบมี output ครบ รวมข้อความ dependency ก่อนเริ่มเทส',SMALL,12)
 d.lines(chunk,8.2,12)

d.start('5 สรุปผล ปัญหาที่พบ และข้อจำกัด')
d.p('ทดสอบทั้งหมด 12 เคส ผ่าน 12 เคส ไม่ผ่าน 0 เคส และข้าม 0 เคส คิดเป็นอัตราผ่าน 100% ของชุดทดสอบที่เลือก โดย Terminal สรุปว่า +12: All tests passed! และคำสั่งจบด้วย exit code 0')
d.p('ผลที่ได้',HEAD)
d.p('บริการส่งคืนพิกัดและข้อมูลประกอบตามที่ตรวจใน TC01 ปฏิเสธพิกัดเก่า พิกัดอนาคต และข้อมูลว่าง รวมถึงจัดการการปฏิเสธสิทธิ์ ข้อผิดพลาดจาก native และ timeout ได้ตาม assertion ที่ระบุ เมื่อคำขอหมดเวลา สามารถสั่งยกเลิกและลองใหม่สำเร็จในสภาพแวดล้อมจำลอง')
d.p('ปัญหาที่พบ',HEAD)
d.p('ไม่พบเคสล้มเหลวในชุดสุดท้าย ระหว่างเตรียมการรันต้องให้ Flutter เข้าถึง SDK cache นอกโฟลเดอร์โปรเจกต์ก่อนจึงรันได้ และมีข้อความแจ้งแพ็กเกจรุ่นใหม่ที่ไม่ตรง dependency constraints ซึ่งไม่ทำให้ชุดทดสอบล้มเหลว')
d.p('ข้อจำกัดและงานต่อไป',HEAD)
d.p('ผลนี้ยืนยันเฉพาะ 12 unit tests ที่เลือก ไม่ใช่ผลทดสอบทั้งโปรเจกต์หรือค่า code coverage การจำลอง MethodChannel ไม่ยืนยันความแม่นยำของ GPS จริง จึงควรทดสอบเพิ่มเติมบน Android สำหรับการขอสิทธิ์ การอ่านตำแหน่ง การปิด GPS และการส่ง SOS พร้อมพิกัด')
d.p('รายการส่งงาน',HEAD)
d.p('1. รายงาน PDF ฉบับนี้ พร้อมตารางผล โค้ดครบทุกเคส และ output จริง<br/>2. ไฟล์ทดสอบ Dart จำนวน 2 ไฟล์ ตามพาธในหัวข้อ 1<br/>3. output/week5-unit-tests.txt เป็นหลักฐาน output ฉบับเต็ม<br/>4. ไฟล์ ZIP รวมรายงาน โค้ดทดสอบ และ output สำหรับส่งงาน')
d.save()
print(f'Created {OUT} ({d.page} pages)')
