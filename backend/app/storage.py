import os
import boto3
from botocore.config import Config
from pathlib import Path
import logging
from typing import Tuple
from app.config import settings

logger = logging.getLogger(__name__)

class CloudflareR2Storage:
    def __init__(self):
        self.account_id = settings.CF_ACCOUNT_ID
        self.access_key = settings.R2_ACCESS_KEY_ID
        self.secret_key = settings.R2_SECRET_ACCESS_KEY
        self.bucket_name = settings.R2_BUCKET_NAME
        self.is_configured = bool(
            self.account_id and 
            self.access_key and 
            self.secret_key and 
            self.account_id != "your_cloudflare_account_id_here"
        )
        
        self.client = None
        if self.is_configured:
            try:
                self.client = boto3.client(
                    "s3",
                    endpoint_url=f"https://{self.account_id}.r2.cloudflarestorage.com",
                    aws_access_key_id=self.access_key,
                    aws_secret_access_key=self.secret_key,
                    region_name="auto",
                    config=Config(signature_version="s3v4")
                )
                logger.info(f"[Storage] Cloudflare R2 client initialized for bucket '{self.bucket_name}'.")
            except Exception as e:
                logger.error(f"[Storage] Failed to initialize R2 client: {e}")
                self.client = None
                self.is_configured = False
        else:
            logger.warning("[Storage] Cloudflare R2 credentials not fully set. Using local fallback directory for uploads.")

        self.local_upload_dir = Path(__file__).resolve().parent.parent / "static" / "uploads"
        self.local_upload_dir.mkdir(parents=True, exist_ok=True)

    def upload_image(self, file_bytes: bytes, filename_key: str, content_type: str = "image/jpeg") -> Tuple[str, str]:
        if self.is_configured and self.client:
            try:
                self.client.put_object(
                    Bucket=self.bucket_name,
                    Key=filename_key,
                    Body=file_bytes,
                    ContentType=content_type
                )
                domain = settings.R2_PUBLIC_DOMAIN.rstrip("/")
                public_url = f"{domain}/{filename_key}"
                logger.info(f"[Storage] Uploaded to R2: {filename_key} ({len(file_bytes)} bytes)")
                return filename_key, public_url
            except Exception as e:
                logger.error(f"[Storage] Failed to upload to R2, falling back to local: {e}")

        local_path = self.local_upload_dir / filename_key
        local_path.parent.mkdir(parents=True, exist_ok=True)
        with open(local_path, "wb") as f:
            f.write(file_bytes)
            
        logger.info(f"[Storage] Saved to local storage: {local_path} ({len(file_bytes)} bytes)")
        local_url = f"/static/uploads/{filename_key}"
        return filename_key, local_url

    def delete_image(self, filename_key: str):
        if self.is_configured and self.client:
            try:
                self.client.delete_object(Bucket=self.bucket_name, Key=filename_key)
                logger.info(f"[Storage] Deleted from R2: {filename_key}")
            except Exception as e:
                logger.error(f"[Storage] Failed to delete from R2: {e}")
                
        local_path = self.local_upload_dir / filename_key
        if local_path.exists():
            try:
                local_path.unlink()
                logger.info(f"[Storage] Deleted local file: {local_path}")
            except Exception as e:
                logger.error(f"[Storage] Failed to delete local file: {e}")

r2_storage = CloudflareR2Storage()
