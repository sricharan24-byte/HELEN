from pathlib import Path

from docx import Document
from docx.oxml import OxmlElement


report = Path(__file__).resolve().parents[1] / "BusBuddy_Project_Report_Updated.docx"
document = Document(report)
table = document.tables[-1]
tr_pr = table.rows[0]._tr.get_or_add_trPr()
if tr_pr.find("{http://schemas.openxmlformats.org/wordprocessingml/2006/main}tblHeader") is None:
    tr_pr.append(OxmlElement("w:tblHeader"))
document.save(report)
