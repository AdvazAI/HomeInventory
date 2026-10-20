import sys
import io
import qrcode
from PIL import Image, ImageDraw, ImageFont
import logging
from app.config import settings

logger = logging.getLogger(__name__)

class BrotherPrintService:
    def __init__(self):
        self.printer_name = settings.BROTHER_PRINTER_NAME

    def generate_label_image(self, qr_payload: str, title: str, subtitle: str = "") -> Image.Image:
        clean_payload = qr_payload[:80]
        
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=8,
            border=2,
        )
        qr.add_data(clean_payload)
        qr.make(fit=True)
        qr_img = qr.make_image(fill_color="black", back_color="white").convert("RGB")
        
        lbl_w = 480
        lbl_h = 240
        label_img = Image.new("RGB", (lbl_w, lbl_h), "white")
        draw = ImageDraw.Draw(label_img)
        
        qr_resized = qr_img.resize((210, 210), Image.Resampling.NEAREST)
        label_img.paste(qr_resized, (15, 15))
        
        font_large = None
        font_small = None
        try:
            font_large = ImageFont.truetype("msyh.ttc", 28)
            font_small = ImageFont.truetype("msyh.ttc", 18)
        except Exception:
            try:
                font_large = ImageFont.truetype("arial.ttf", 26)
                font_small = ImageFont.truetype("arial.ttf", 16)
            except Exception:
                font_large = ImageFont.load_default()
                font_small = ImageFont.load_default()

        text_x = 240
        draw.text((text_x, 30), title[:25], fill="black", font=font_large)
        if subtitle:
            draw.text((text_x, 80), subtitle[:35], fill="#333333", font=font_small)
            
        draw.text((text_x, 140), "Home Inventory", fill="#666666", font=font_small)
        draw.text((text_x, 175), f"Tag: {clean_payload[:24]}", fill="#444444", font=font_small)
        
        return label_img.convert("1")

    def print_direct(self, qr_payload: str, title: str, subtitle: str = "") -> dict:
        img = self.generate_label_image(qr_payload, title, subtitle)
        
        if sys.platform != "win32":
            logger.warning("[Print] Direct Windows GDI printing is only available on Windows host.")
            return {"status": "skipped", "message": "Direct print spooler is only supported on Windows host"}

        try:
            import win32print
            import win32ui
            from PIL import ImageWin

            printers = [p[2] for p in win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]
            target_printer = self.printer_name
            
            if target_printer not in printers:
                brother_candidates = [p for p in printers if "brother" in p.lower() or "ql" in p.lower()]
                if brother_candidates:
                    target_printer = brother_candidates[0]
                    logger.info(f"[Print] '{self.printer_name}' not found, auto-fallback to: '{target_printer}'")
                else:
                    return {
                        "status": "error",
                        "message": f"Printer '{self.printer_name}' not found in Windows printers: {printers}"
                    }

            hDC = win32ui.CreateDC()
            hDC.CreatePrinterDC(target_printer)
            hDC.StartDoc(f"Label - {title}")
            hDC.StartPage()

            dib = ImageWin.Dib(img)
            dib.draw(hDC.GetHandleOutput(), (0, 0, img.size[0] * 2, img.size[1] * 2))

            hDC.EndPage()
            hDC.EndDoc()
            hDC.DeleteDC()

            logger.info(f"[Print] Label directly printed to '{target_printer}' successfully.")
            return {"status": "success", "printer": target_printer, "message": f"Printed to {target_printer}"}

        except Exception as e:
            logger.error(f"[Print] Failed to print to Brother printer: {e}")
            return {"status": "error", "message": str(e)}

brother_printer = BrotherPrintService()
