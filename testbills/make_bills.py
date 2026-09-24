"""Generates realistic test medical bills as PNGs for Billshield testing.

Each bill has known, deliberate contents so we can verify exactly what the app
should and should not flag.
"""
from PIL import Image, ImageDraw, ImageFont
import os

OUT = os.path.dirname(os.path.abspath(__file__))
W, H = 1275, 1650  # ~150 dpi letter

REG = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
BOLD = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
MONO = "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf"

f_title = ImageFont.truetype(BOLD, 40)
f_sub = ImageFont.truetype(REG, 24)
f_head = ImageFont.truetype(BOLD, 22)
f_body = ImageFont.truetype(REG, 23)
f_mono = ImageFont.truetype(MONO, 22)
f_small = ImageFont.truetype(REG, 19)
f_big = ImageFont.truetype(BOLD, 30)

INK = (17, 17, 17)
GREY = (95, 95, 95)
RULE = (170, 170, 170)


def new_page():
    img = Image.new("RGB", (W, H), "white")
    return img, ImageDraw.Draw(img)


def header(d, provider, addr, city, doc_title):
    d.text((70, 70), provider, font=f_title, fill=INK)
    d.text((70, 122), addr, font=f_small, fill=GREY)
    d.text((70, 148), city, font=f_small, fill=GREY)
    d.text((70, 205), doc_title, font=f_head, fill=INK)
    d.line([(70, 240), (W - 70, 240)], fill=RULE, width=2)


def meta_block(d, y, rows):
    for label, value in rows:
        d.text((70, y), label, font=f_small, fill=GREY)
        d.text((330, y), value, font=f_body, fill=INK)
        y += 34
    return y


def table_header(d, y):
    d.line([(70, y - 8), (W - 70, y - 8)], fill=RULE, width=2)
    d.text((70, y + 4), "DATE", font=f_head, fill=INK)
    d.text((215, y + 4), "DESCRIPTION", font=f_head, fill=INK)
    d.text((790, y + 4), "CODE", font=f_head, fill=INK)
    d.text((940, y + 4), "QTY", font=f_head, fill=INK)
    d.text((1060, y + 4), "AMOUNT", font=f_head, fill=INK)
    d.line([(70, y + 38), (W - 70, y + 38)], fill=RULE, width=2)
    return y + 54


def row(d, y, date, desc, code, qty, amount):
    d.text((70, y), date, font=f_mono, fill=INK)
    d.text((215, y), desc, font=f_body, fill=INK)
    if code:
        d.text((790, y), code, font=f_mono, fill=INK)
    if qty:
        d.text((955, y), qty, font=f_mono, fill=INK)
    txt = amount
    bbox = d.textbbox((0, 0), txt, font=f_mono)
    d.text((W - 70 - (bbox[2] - bbox[0]), y), txt, font=f_mono, fill=INK)
    return y + 40


def total_row(d, y, label, amount, bold=False, big=False):
    font = f_big if big else (f_head if bold else f_body)
    d.text((640, y), label, font=font, fill=INK)
    bbox = d.textbbox((0, 0), amount, font=font)
    d.text((W - 70 - (bbox[2] - bbox[0]), y), amount, font=font, fill=INK)
    return y + (46 if big else 36)


def footer(d, lines, y=None):
    y = y or H - 150
    for line in lines:
        d.text((70, y), line, font=f_small, fill=GREY)
        y += 26


# ---------------------------------------------------------------- BILL A
# Error-laden ER bill. Should flag: duplicate ECG, unbundled glucose,
# vague MISC SUPPLIES, math mismatch (lines sum 1190 vs stated 1040).
def bill_a():
    img, d = new_page()
    header(d, "CITY GENERAL HOSPITAL", "1400 Medical Center Drive",
           "Springfield, IL 62704", "EMERGENCY DEPARTMENT — PATIENT STATEMENT")
    y = meta_block(d, 265, [
        ("Patient", "SAMPLE PATIENT"),
        ("Account Number", "BH-204981"),
        ("Statement Date", "08/15/2026"),
        ("Date of Service", "08/02/2026"),
    ])
    y = table_header(d, y + 20)
    y = row(d, y, "08/02/26", "EMERGENCY DEPT VISIT LEVEL 3", "99283", "1", "$390.00")
    y = row(d, y, "08/02/26", "ECG ROUTINE 12 LEADS", "93000", "1", "$150.00")
    y = row(d, y, "08/02/26", "ECG ROUTINE 12 LEADS", "93000", "1", "$150.00")
    y = row(d, y, "08/02/26", "COMPREHEN METABOLIC PANEL", "80053", "1", "$120.00")
    y = row(d, y, "08/02/26", "GLUCOSE BLOOD TEST", "82947", "1", "$40.00")
    y = row(d, y, "08/02/26", "MISC SUPPLIES", "", "1", "$340.00")
    d.line([(640, y + 10), (W - 70, y + 10)], fill=RULE, width=2)
    y = total_row(d, y + 26, "Total Charges", "$1,040.00", bold=True)
    y = total_row(d, y, "Insurance Payments", "$0.00")
    y = total_row(d, y + 10, "Amount Due", "$1,040.00", big=True)
    footer(d, ["Please remit payment within 30 days.",
               "Questions about your bill? Call 1-800-555-0142."])
    img.save(os.path.join(OUT, "bill-A-errors.png"))


# ---------------------------------------------------------------- BILL B
# Clean office visit. MUST produce ZERO flags. This is the most important test.
def bill_b():
    img, d = new_page()
    header(d, "RIVERSIDE FAMILY MEDICINE", "88 Oak Street, Suite 210",
           "Springfield, IL 62704", "PATIENT STATEMENT")
    y = meta_block(d, 265, [
        ("Patient", "SAMPLE PATIENT"),
        ("Account Number", "RF-33120"),
        ("Statement Date", "08/12/2026"),
        ("Date of Service", "08/05/2026"),
    ])
    y = table_header(d, y + 20)
    y = row(d, y, "08/05/26", "OFFICE VISIT ESTABLISHED LVL 3", "99213", "1", "$180.00")
    y = row(d, y, "08/05/26", "VENIPUNCTURE", "36415", "1", "$25.00")
    y = row(d, y, "08/05/26", "CBC WITH AUTO DIFFERENTIAL", "85025", "1", "$85.00")
    d.line([(640, y + 10), (W - 70, y + 10)], fill=RULE, width=2)
    y = total_row(d, y + 26, "Total Charges", "$290.00", bold=True)
    y = total_row(d, y, "Insurance Adjustments", "$0.00")
    y = total_row(d, y + 10, "Amount Due", "$290.00", big=True)
    footer(d, ["Thank you for choosing Riverside Family Medicine.",
               "Pay online at riversidefm.example / 1-800-555-0199."])
    img.save(os.path.join(OUT, "bill-B-clean.png"))


# ---------------------------------------------------------------- BILL C
# Unitemized summary bill. Should flag: not itemized -> request itemized bill.
def bill_c():
    img, d = new_page()
    header(d, "REGIONAL MEDICAL CENTER", "500 Hospital Way",
           "Springfield, IL 62703", "SUMMARY STATEMENT")
    y = meta_block(d, 265, [
        ("Patient", "SAMPLE PATIENT"),
        ("Account Number", "RMC-778201"),
        ("Statement Date", "08/18/2026"),
        ("Admission", "07/28/2026 - 07/30/2026"),
    ])
    d.line([(70, y + 20), (W - 70, y + 20)], fill=RULE, width=2)
    y += 60
    d.text((70, y), "SUMMARY OF ACCOUNT", font=f_head, fill=INK)
    y += 60
    y = total_row(d, y, "Hospital Services", "$8,420.00")
    y = total_row(d, y, "Insurance Payments", "$6,020.00")
    y = total_row(d, y + 20, "Amount Due", "$2,400.00", big=True)
    y += 60
    d.text((70, y), "This statement reflects the balance remaining after insurance.",
           font=f_body, fill=INK)
    d.text((70, y + 34), "A detailed listing of charges is available upon request.",
           font=f_body, fill=INK)
    footer(d, ["Payment is due within 30 days of the statement date.",
               "Financial assistance may be available — call 1-800-555-0170."])
    img.save(os.path.join(OUT, "bill-C-unitemized.png"))


# ---------------------------------------------------------------- BILL D
# EOB. Should short-circuit: "this is not a bill — don't pay".
def bill_d():
    img, d = new_page()
    header(d, "BLUE MERIDIAN HEALTH PLAN", "PO Box 4400",
           "Chicago, IL 60602", "EXPLANATION OF BENEFITS")
    d.rectangle([70, 258, W - 70, 316], outline=INK, width=3)
    d.text((96, 270), "THIS IS NOT A BILL — DO NOT PAY FROM THIS DOCUMENT",
           font=f_head, fill=INK)
    y = meta_block(d, 340, [
        ("Member", "SAMPLE PATIENT"),
        ("Member ID", "BM-99120043"),
        ("Claim Number", "CLM-2026-884120"),
        ("Processed Date", "08/10/2026"),
    ])
    y = table_header(d, y + 20)
    y = row(d, y, "08/01/26", "CT HEAD WITHOUT CONTRAST", "70450", "1", "$1,700.00")
    y = row(d, y, "08/01/26", "RADIOLOGY INTERPRETATION", "70450", "1", "$210.00")
    d.line([(640, y + 10), (W - 70, y + 10)], fill=RULE, width=2)
    y = total_row(d, y + 26, "Billed by Provider", "$1,910.00")
    y = total_row(d, y, "Plan Discount", "$1,190.00")
    y = total_row(d, y, "Plan Paid", "$576.00")
    y = total_row(d, y + 10, "Your Estimated Responsibility", "$144.00", bold=True)
    footer(d, ["The provider will send you a separate bill for any amount you owe.",
               "Questions? Call member services at 1-800-555-0100."])
    img.save(os.path.join(OUT, "bill-D-eob.png"))


# ---------------------------------------------------------------- BILL E
# Extreme price outlier + supplies + impossible room-days quantity.
def bill_e():
    img, d = new_page()
    header(d, "SUMMIT IMAGING & SURGICAL CENTER", "9 Parkway North",
           "Springfield, IL 62711", "ITEMIZED PATIENT STATEMENT")
    y = meta_block(d, 265, [
        ("Patient", "SAMPLE PATIENT"),
        ("Account Number", "SI-551209"),
        ("Statement Date", "08/19/2026"),
        ("Date of Service", "08/03/2026"),
    ])
    y = table_header(d, y + 20)
    y = row(d, y, "08/03/26", "CT HEAD WITHOUT CONTRAST", "70450", "1", "$9,500.00")
    y = row(d, y, "08/03/26", "SEMI-PRIVATE ROOM DAILY RATE", "", "45", "$2,250.00")
    y = row(d, y, "08/03/26", "VENIPUNCTURE", "36415", "1", "$25.00")
    y = row(d, y, "08/03/26", "STERILE GLOVES", "", "4", "$62.00")
    y = row(d, y, "08/03/26", "WARMING BLANKET", "", "1", "$118.00")
    y = row(d, y, "08/03/26", "RADIOLOGY READING FEE", "", "1", "$90.00")
    d.line([(640, y + 10), (W - 70, y + 10)], fill=RULE, width=2)
    y = total_row(d, y + 26, "Total Charges", "$12,045.00", bold=True)
    y = total_row(d, y + 10, "Amount Due", "$12,045.00", big=True)
    footer(d, ["Self-pay discounts may be available upon request.",
               "Billing questions: 1-800-555-0188."])
    img.save(os.path.join(OUT, "bill-E-outlier.png"))


# ---------------------------------------------------------------- BILL F
# Exercises the v7 rules: OTC drug markup, after-hours fee, missed appointment fee,
# interest charge, observation status, preventive care with a balance, a late
# statement, and collections language.
def bill_f():
    img, d = new_page()
    header(d, "LAKEVIEW HEALTH PARTNERS", "220 Clinic Road",
           "Springfield, IL 62702", "PATIENT STATEMENT - PAST DUE")
    y = meta_block(d, 265, [
        ("Patient", "SAMPLE PATIENT"),
        ("Account Number", "LH-660412"),
        ("Statement Date", "08/20/2026"),
        ("Notice", "FINAL NOTICE - PAST DUE"),
    ])
    y = table_header(d, y + 20)
    y = row(d, y, "06/14/25", "ANNUAL WELLNESS VISIT", "99395", "1", "$310.00")
    y = row(d, y, "06/14/25", "OBSERVATION CARE PER HOUR", "", "6", "$1,420.00")
    y = row(d, y, "06/14/25", "ACETAMINOPHEN 500MG TABLET", "", "2", "$48.00")
    y = row(d, y, "06/14/25", "AFTER HOURS SERVICE FEE", "", "1", "$175.00")
    y = row(d, y, "06/20/25", "MISSED APPOINTMENT FEE", "", "1", "$75.00")
    y = row(d, y, "07/01/26", "INTEREST ON UNPAID BALANCE", "", "1", "$92.00")
    d.line([(640, y + 10), (W - 70, y + 10)], fill=RULE, width=2)
    y = total_row(d, y + 26, "Total Charges", "$2,120.00", bold=True)
    y = total_row(d, y + 10, "Amount Due", "$2,120.00", big=True)
    footer(d, ["This account is past due and may be referred to a collection agency.",
               "Billing questions: 1-800-555-0155."])
    img.save(os.path.join(OUT, "bill-F-newrules.png"))


for fn in (bill_a, bill_b, bill_c, bill_d, bill_e, bill_f):
    fn()
print("wrote:", sorted(f for f in os.listdir(OUT) if f.endswith(".png")))
