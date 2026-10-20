from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models import ActivityLog
from app.schemas import ActivityLogResponse
from app.routers.locations import get_location_breadcrumbs

router = APIRouter(prefix="/api", tags=["Activity History"])

@router.get("/families/{family_id}/logs", response_model=List[ActivityLogResponse])
def get_activity_logs(family_id: int, db: Session = Depends(get_db)):
    logs = db.query(ActivityLog).filter(
        ActivityLog.family_id == family_id
    ).order_by(ActivityLog.created_at.desc()).limit(100).all()

    result = []
    for log in logs:
        loc_name = get_location_breadcrumbs(db, log.location_id)
        result.append(ActivityLogResponse(
            id=log.id,
            family_id=log.family_id,
            item_id=log.item_id,
            item_name=log.item.name if log.item else "已刪除物品",
            member_id=log.member_id,
            member_name=log.member.name if log.member else "未知成員",
            location_id=log.location_id,
            location_name=loc_name,
            action=log.action,
            created_at=log.created_at
        ))
    return result
