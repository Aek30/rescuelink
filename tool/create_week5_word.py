"""Create editable Word version using the same verified report content."""
from pathlib import Path
import ast

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'tool/create_week5_report.py').read_text(encoding='utf-8')
tree = ast.parse(source)
node = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == 'Report')
adapter = r'''
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
import html, re

class Report:
 def __init__(self):
  self.doc=Document()
  section=self.doc.sections[0]
  section.page_width=Cm(21); section.page_height=Cm(29.7)
  section.top_margin=section.bottom_margin=Cm(1.6)
  section.left_margin=section.right_margin=Cm(1.6)
  section.header_distance=section.footer_distance=Cm(.7)
  self.doc.core_properties.title='รายงานความคืบหน้า RescueLink สัปดาห์ที่ 5'
  self.doc.core_properties.author='นางสาว เอกวลี ชรินทร์'
  for name in ['Normal','Title','Heading 1','Heading 2']:
   style=self.doc.styles[name]
   style.font.name='Tahoma'; style.font.size=Pt(10.3)
   style.font.color.rgb=RGBColor(0,0,0)
   props=style.element.get_or_add_rPr()
   fonts=OxmlElement('w:rFonts')
   for key in ['ascii','hAnsi','eastAsia','cs']: fonts.set(qn('w:'+key),'Tahoma')
   props.insert(0,fonts)
   style.paragraph_format.space_after=Pt(8)
   style.paragraph_format.line_spacing=1.15
  self.doc.styles['Title'].font.size=Pt(18)
  self.doc.styles['Heading 1'].font.size=Pt(14)
  for border in list(self.doc.styles.element.iter(qn('w:pBdr'))):
   border.getparent().remove(border)
  h=section.header.paragraphs[0]
  h.add_run('RescueLink   Advanced Programming   Week 5').font.size=Pt(8)
  f=section.footer.paragraphs[0]; f.alignment=WD_ALIGN_PARAGRAPH.RIGHT
  f.add_run('หน้า ').font.size=Pt(8)
  field=OxmlElement('w:fldSimple'); field.set(qn('w:instr'),'PAGE'); f._p.append(field)
  self.page=0; self.y=0
 def start(self,title):
  if self.page: self.doc.add_page_break()
  self.page+=1
  p=self.doc.add_paragraph(title, 'Title' if self.page==1 else 'Heading 1')
  if self.page==1:
   p.alignment=WD_ALIGN_PARAGRAPH.CENTER
   p.paragraph_format.space_after=Pt(45)
 def p(self,text,style=BODY,gap=10):
  text=text.replace('รายงาน PDF ฉบับนี้','รายงาน Word ฉบับนี้')
  text=html.unescape(re.sub(r'<[^>]*>','',text.replace('<br/>','\n')))
  p=self.doc.add_paragraph(text, 'Heading 2' if style==HEAD else 'Normal')
  fmt=p.paragraph_format; fmt.space_after=Pt(gap)
  if style==TITLE:
   p.alignment=WD_ALIGN_PARAGRAPH.CENTER
   for r in p.runs: r.font.size=Pt(16)
  elif style==SMALL:
   for r in p.runs: r.font.size=Pt(9)
  elif style==HEAD:
   for r in p.runs: r.font.size=Pt(13)
 def table(self,rows):
  table=self.doc.add_table(rows=0,cols=5)
  table.alignment=WD_TABLE_ALIGNMENT.CENTER; table.autofit=False
  widths=[1.35,3.65,5.05,6.0,1.75]
  for col,w in zip(table.columns,widths): col.width=Cm(w)
  for index,row in enumerate(rows):
   cells=table.add_row().cells
   for cell,value,w in zip(cells,row,widths):
    cell.width=Cm(w); cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
    p=cell.paragraphs[0]; p.paragraph_format.space_after=Pt(4)
    p.paragraph_format.space_before=Pt(4); p.paragraph_format.line_spacing=1.12
    p.add_run(value).font.size=Pt(9)
    tcPr=cell._tc.get_or_add_tcPr()
    borders=OxmlElement('w:tcBorders')
    for edge in ['top','left','bottom','right']:
     b=OxmlElement('w:'+edge); b.set(qn('w:val'),'single'); b.set(qn('w:sz'),'4'); b.set(qn('w:color'),'D9D9D9'); borders.append(b)
    tcPr.append(borders)
    if index==0:
     sh=OxmlElement('w:shd'); sh.set(qn('w:fill'),'EAF1F9'); tcPr.append(sh)
   no_split=OxmlElement('w:cantSplit'); table.rows[-1]._tr.get_or_add_trPr().append(no_split)
  table.rows[0]._tr.get_or_add_trPr().append(OxmlElement('w:tblHeader'))
  self.doc.add_paragraph().paragraph_format.space_after=Pt(4)
 def lines(self,lines,size=8.3,leading=12):
  for line in lines:
   p=self.doc.add_paragraph()
   p.paragraph_format.space_before=Pt(0); p.paragraph_format.space_after=Pt(0)
   p.paragraph_format.line_spacing=Pt(leading)
   p.paragraph_format.widow_control=False
   r=p.add_run(line); r.font.size=Pt(size)
 def save(self):
  out=ROOT/'output/docx/rescuelink-week5.docx'
  out.parent.mkdir(parents=True,exist_ok=True)
  self.doc.save(out)
  print('Created',out)
'''
lines=source.splitlines()
lines[node.lineno-1:node.end_lineno]=adapter.splitlines()
source='\n'.join(lines)
source=source.replace("d.p('รายการส่งงาน',HEAD)","d.p('รายการส่งงาน',HEAD)")
exec(compile(source,str(ROOT/'tool/create_week5_report.py'),'exec'), {'__file__':str(ROOT/'tool/create_week5_report.py')})
