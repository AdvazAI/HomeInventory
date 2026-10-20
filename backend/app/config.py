import os
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

root_dir = Path(__file__).resolve().parent.parent.parent
backend_dir = Path(__file__).resolve().parent.parent

env_files = [
    str(backend_dir / ".env"),
    str(root_dir / ".env"),
]

class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql://postgres:postgres@localhost:5432/home_inventory"
    DB_SCHEMA: str = "public"
    SUPABASE_PROJECT_REF: str = "nandhpzabmbrtiigyhhc"
    SUPABASE_URL: str = "https://nandhpzabmbrtiigyhhc.supabase.co"

    CF_ACCOUNT_ID: str = ""
    CF_ZONE_DOMAIN: str = "advaz.au"
    CUSTOM_DOMAIN: str = "homeinv.advaz.au"

    R2_ACCESS_KEY_ID: str = ""
    R2_SECRET_ACCESS_KEY: str = ""
    R2_BUCKET_NAME: str = "homeinventory"
    R2_PUBLIC_DOMAIN: str = "https://pub-r2.dev"
    
    CF_API_TOKEN: str = ""
    CF_API_EMAIL: str = ""
    CF_GLOBAL_API_KEY: str = ""

    GCP_PROJECT_ID: str = "project-c5416966-d0c7-49c5-add"
    GCP_REGION: str = "australia-southeast1"
    CLOUD_RUN_SERVICE_NAME: str = "home-inventory-backend"
    CLOUD_RUN_URL: str = ""

    PLAY_DEVELOPER_ID: str = ""
    PLAY_APP_ID: str = ""
    ANDROID_PACKAGE_NAME: str = "com.freedom.homeinventory.home_inventory"

    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-3.5-flash-lite"
    GEMINI_EMBEDDING_MODEL: str = "gemini-embedding-001"

    BROTHER_PRINTER_NAME: str = "BrotherLabelPtr"

    APP_ENV: str = "development"
    PORT: int = 8000
    HOST: str = "0.0.0.0"

    model_config = SettingsConfigDict(
        env_file=env_files,
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()
