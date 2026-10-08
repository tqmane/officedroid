#!/usr/bin/env python3
"""Regenerate MIT-licensed test documents; no Microsoft software or artwork is included.
Requires python-docx==1.2.0, openpyxl==3.1.5, python-pptx==1.0.2.
CI uses the committed fixtures, so these packages are needed only for regeneration.
"""
from pathlib import Path
from docx import Document
from docx.shared import Pt
from openpyxl import Workbook
from openpyxl.styles import Font
from pptx import Presentation
from pptx.util import Inches, Pt as SlidePt

output = Path(__file__).resolve().parent / 'fixtures'
output.mkdir(exist_ok=True)
document = Document()
# Drop the libraries' template thumbnails and printer settings from our fixtures.
for rel_id, rel in list(document.part.package.rels.items()):
    if rel.reltype.endswith('/thumbnail'):
        del document.part.package.rels[rel_id]
run = document.add_paragraph().add_run('INITIALWORD')
run.font.size = Pt(18)
document.save(output / 'office-edit-word.docx')
workbook = Workbook()
sheet = workbook.active
sheet['A1'] = 'INITIALEXCEL'
sheet['A1'].font = Font(size=20)
sheet.column_dimensions['A'].width = 50
workbook.save(output / 'office-edit-excel.xlsx')
presentation = Presentation()
for rel_id, rel in list(presentation.part.package._rels.items()):
    if rel.reltype.endswith('/thumbnail'):
        presentation.part.package.drop_rel(rel_id)
for rel_id, rel in list(presentation.part.rels.items()):
    if rel.reltype.endswith('/printerSettings'):
        presentation.part.drop_rel(rel_id)
slide = presentation.slides.add_slide(presentation.slide_layouts[6])
textbox = slide.shapes.add_textbox(Inches(1), Inches(2), Inches(8), Inches(1))
run = textbox.text_frame.paragraphs[0].add_run()
run.text = 'INITIALPPT'
run.font.size = SlidePt(28)
presentation.save(output / 'office-edit-powerpoint.pptx')
