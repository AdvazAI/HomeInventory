from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List
from app.database import get_db
from app.models import Item, ActivityLog, Member
from app.schemas import (
    ItemCreate, ItemUpdate, ItemResponse,
    CheckOutRequest, CheckInRequest, SearchResultItem
)
from app.routers.locations import get_location_breadcrumbs
from app.search import embedding_service
import logging

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["Items & Check-in/out"])

def trigger_parasitic_cleanup(db: Session, family_id: int):
    one_month_ago = datetime.utcnow() - timedelta(days=30)
    try:
        deleted = db.query(ActivityLog).filter(
            ActivityLog.family_id == family_id,
            ActivityLog.created_at < one_month_ago
        ).delete(synchronize_session=False)
        db.commit()
        if deleted > 0:
            logger.info(f"[Parasitic Cleanup] Removed {deleted} activity logs older than 30 days for family {family_id}.")
    except Exception as e:
        db.rollback()
        logger.error(f"[Parasitic Cleanup] Error: {e}")

def check_and_debounce(db: Session, family_id: int, item_id: int, member_id: int, action: str) -> bool:
    five_sec_ago = datetime.utcnow() - timedelta(seconds=5)
    recent_log = db.query(ActivityLog).filter(
        ActivityLog.family_id == family_id,
        ActivityLog.item_id == item_id,
        ActivityLog.member_id == member_id,
        ActivityLog.action == action,
        ActivityLog.created_at >= five_sec_ago
    ).order_by(ActivityLog.created_at.desc()).first()

    if recent_log:
        recent_log.created_at = datetime.utcnow()
        db.commit()
        return True
    return False

@router.get("/families/{family_id}/items", response_model=List[ItemResponse])
def get_items(family_id: int, db: Session = Depends(get_db)):
    return db.query(Item).filter(Item.family_id == family_id).order_by(Item.id.desc()).all()

@router.get("/items/{item_id}", response_model=ItemResponse)
def get_item(item_id: int, db: Session = Depends(get_db)):
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item

@router.post("/families/{family_id}/items", response_model=ItemResponse, status_code=201)
def create_item(family_id: int, item_in: ItemCreate, db: Session = Depends(get_db)):
    photos = (item_in.photos or [])[:4]
    vector = embedding_service.get_embedding(f"{item_in.name} {item_in.description or ''}")
    
    item = Item(
        family_id=family_id,
        location_id=item_in.location_id,
        name=item_in.name.strip(),
        description=item_in.description,
        status="checked_in",
        photos=photos,
        search_vector=vector
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item

@router.put("/items/{item_id}", response_model=ItemResponse)
def update_item(item_id: int, item_in: ItemUpdate, db: Session = Depends(get_db)):
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
        
    item.name = item_in.name.strip()
    item.description = item_in.description
    item.location_id = item_in.location_id
    item.photos = (item_in.photos or [])[:4]
    
    vector = embedding_service.get_embedding(f"{item.name} {item.description or ''}")
    if vector:
        item.search_vector = vector
        
    db.commit()
    db.refresh(item)
    return item

@router.delete("/items/{item_id}", status_code=204)
def delete_item(item_id: int, db: Session = Depends(get_db)):
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    db.delete(item)
    db.commit()
    return None

@router.post("/items/{item_id}/check-out", response_model=ItemResponse)
def check_out_item(item_id: int, req: CheckOutRequest, db: Session = Depends(get_db)):
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
        
    now = datetime.utcnow()
    item.status = "checked_out"
    item.checked_out_by_member_id = req.member_id
    item.checked_out_at = now
    
    is_debounced = check_and_debounce(db, item.family_id, item.id, req.member_id, "check_out")
    if not is_debounced:
        log = ActivityLog(
            family_id=item.family_id,
            item_id=item.id,
            member_id=req.member_id,
            location_id=item.location_id,
            action="check_out",
            created_at=now
        )
        db.add(log)
        
    db.commit()
    db.refresh(item)
    trigger_parasitic_cleanup(db, item.family_id)
    return item

@router.post("/items/{item_id}/check-in", response_model=ItemResponse)
def check_in_item(item_id: int, req: CheckInRequest, db: Session = Depends(get_db)):
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
        
    now = datetime.utcnow()
    target_loc_id = req.location_id if req.location_id is not None else item.location_id
    
    item.status = "checked_in"
    item.checked_out_by_member_id = None
    item.checked_out_at = None
    item.location_id = target_loc_id
    
    is_debounced = check_and_debounce(db, item.family_id, item.id, req.member_id, "check_in")
    if not is_debounced:
        log = ActivityLog(
            family_id=item.family_id,
            item_id=item.id,
            member_id=req.member_id,
            location_id=target_loc_id,
            action="check_in",
            created_at=now
        )
        db.add(log)
        
    db.commit()
    db.refresh(item)
    trigger_parasitic_cleanup(db, item.family_id)
    return item

@router.get("/items/{item_id}/trace")
def trace_item(item_id: int, db: Session = Depends(get_db)):
    item = db.query(Item).filter(Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
        
    last_log = db.query(ActivityLog).filter(
        ActivityLog.item_id == item.id,
        ActivityLog.action == "check_out"
    ).order_by(ActivityLog.created_at.desc()).first()
    
    member_name = "未知成員"
    if item.checked_out_by_member_id:
        m = db.query(Member).filter(Member.id == item.checked_out_by_member_id).first()
        if m:
            member_name = m.name
    elif last_log and last_log.member:
        member_name = last_log.member.name

    loc_path = get_location_breadcrumbs(db, item.location_id)
    return {
        "item": ItemResponse.model_validate(item),
        "last_checked_out_by": member_name,
        "checked_out_at": item.checked_out_at or (last_log.created_at if last_log else None),
        "target_location_id": item.location_id,
        "target_location_path": loc_path
    }

@router.get("/families/{family_id}/search", response_model=List[SearchResultItem])
def search_items(family_id: int, q: str = Query(..., min_length=1), db: Session = Depends(get_db)):
    q = q.strip()
    if not q:
        return []
        
    items = db.query(Item).filter(Item.family_id == family_id).all()
    if not items:
        return []

    query_vector = embedding_service.get_embedding(q)
    expanded_queries = embedding_service.expand_query(q)
    scored_list = []

    for item in items:
        target_text = f"{item.name} {item.description or ''}"
        text_score = max(embedding_service.calculate_text_score(eq, target_text) for eq in expanded_queries)
        
        vec_score = 0.0
        if query_vector and item.search_vector:
            vec_score = embedding_service.cosine_similarity(query_vector, item.search_vector)
            
        final_score = max(text_score, (text_score * 0.4 + vec_score * 0.6))
        
        if final_score > 0.15:
            scored_list.append((item, final_score))

    scored_list.sort(key=lambda x: x[1], reverse=True)
    top_results = scored_list[:20]

    response = []
    for it, score in top_results:
        loc_path = get_location_breadcrumbs(db, it.location_id)
        response.append(SearchResultItem(
            item=ItemResponse.model_validate(it),
            score=round(score, 3),
            location_path=loc_path
        ))
    return response
