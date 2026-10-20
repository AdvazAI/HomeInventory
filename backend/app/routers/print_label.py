from fastapi import APIRouter, HTTPException, Response
from app.schemas import DirectPrintRequest
from app.printing import brother_printer
import io

router = APIRouter(prefix="/api/print", tags=["Brother Label Printer"])

@router.post("/direct")
def direct_print_label(req: DirectPrintRequest):
    subtitle = f"ID: {req.item_id}" if req.item_id else f"LOC: {req.location_id}"
    res = brother_printer.print_direct(
        qr_payload=req.qr_payload,
        title=req.title,
        subtitle=subtitle
    )
    if res.get("status") == "error":
        raise HTTPException(status_code=500, detail=res.get("message"))
    return res

@router.get("/preview-image")
def get_label_preview_image(payload: str, title: str, subtitle: str = ""):
    img = brother_printer.generate_label_image(payload, title, subtitle)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return Response(content=buf.getvalue(), media_type="image/png")
