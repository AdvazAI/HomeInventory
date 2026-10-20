import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path

from app.config import settings
from app.database import init_db
from app.routers import families, members, locations, items, activity, upload, print_label

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing Home Inventory Database schema...")
    try:
        init_db()
        logger.info("Database schema initialized successfully.")
    except Exception as e:
        logger.error(f"Error initializing database: {e}")
    yield
    logger.info("Shutting down Home Inventory API.")

app = FastAPI(
    title="Home Inventory API (家庭庫存管理系統)",
    description="Backend API powered by FastAPI, PostgreSQL, Cloudflare R2, Google Gemini & Brother QL-700",
    version="2.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

uploads_dir = Path(__file__).resolve().parent.parent / "static" / "uploads"
uploads_dir.mkdir(parents=True, exist_ok=True)
app.mount("/static/uploads", StaticFiles(directory=str(uploads_dir)), name="uploads")

app.include_router(families.router)
app.include_router(members.router)
app.include_router(locations.router)
app.include_router(items.router)
app.include_router(activity.router)
app.include_router(upload.router)
app.include_router(print_label.router)

@app.get("/")
def root():
    return {
        "status": "online",
        "service": "Home Inventory API",
        "version": "2.0.0",
        "docs_url": "/docs",
        "db": settings.DATABASE_URL.split("@")[-1] if "@" in settings.DATABASE_URL else "configured"
    }

@app.get("/healthz")
def healthz():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=True)
