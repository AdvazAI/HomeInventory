from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from datetime import datetime
import uuid
from app.storage import r2_storage
import logging

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/upload", tags=["Upload & Cloudflare R2"])

@router.post("/item-photo")
async def upload_item_photo(
    file: UploadFile = File(...),
    family_id: int = Form(...),
    item_id: str = Form("new"),
    photo_index: int = Form(0)
):
    try:
        content = await file.read()
        ts = int(datetime.utcnow().timestamp())
        random_suffix = uuid.uuid4().hex[:4]
        filename_key = f"items/{family_id}/item_{item_id}_{ts}_{photo_index}_{random_suffix}.jpg"
        
        saved_key, public_url = r2_storage.upload_image(
            file_bytes=content,
            filename_key=filename_key,
            content_type=file.content_type or "image/jpeg"
        )
        
        return {
            "status": "success",
            "photo_key": saved_key,
            "url": public_url,
            "size_bytes": len(content)
        }
    except Exception as e:
        logger.error(f"[Upload] Failed to upload item photo: {e}")
        raise HTTPException(status_code=500, detail=f"Image upload failed: {str(e)}")

@router.post("/location-photo")
async def upload_location_photo(
    file: UploadFile = File(...),
    family_id: int = Form(...),
    location_id: str = Form("new"),
    photo_index: int = Form(0)
):
    try:
        content = await file.read()
        ts = int(datetime.utcnow().timestamp())
        random_suffix = uuid.uuid4().hex[:4]
        filename_key = f"locations/{family_id}/loc_{location_id}_{ts}_{photo_index}_{random_suffix}.jpg"
        
        saved_key, public_url = r2_storage.upload_image(
            file_bytes=content,
            filename_key=filename_key,
            content_type=file.content_type or "image/jpeg"
        )
        
        return {
            "status": "success",
            "photo_key": saved_key,
            "url": public_url,
            "size_bytes": len(content)
        }
    except Exception as e:
        logger.error(f"[Upload] Failed to upload location photo: {e}")
        raise HTTPException(status_code=500, detail=f"Location photo upload failed: {str(e)}")
