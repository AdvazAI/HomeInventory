from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models import Location, Item
from app.schemas import LocationCreate, LocationUpdate, LocationResponse, LocationTreeNode, resolve_photo_url

router = APIRouter(prefix="/api", tags=["Locations"])

def get_location_breadcrumbs(db: Session, location_id: int) -> str:
    if not location_id:
        return "未指定儲存格"
    nodes = []
    curr_id = location_id
    visited = set()
    while curr_id and curr_id not in visited:
        visited.add(curr_id)
        loc = db.query(Location).filter(Location.id == curr_id).first()
        if loc:
            nodes.insert(0, loc.name)
            curr_id = loc.parent_id
        else:
            break
    return " > ".join(nodes) if nodes else "未知空間"

@router.get("/families/{family_id}/locations", response_model=List[LocationResponse])
def get_locations(family_id: int, db: Session = Depends(get_db)):
    return db.query(Location).filter(Location.family_id == family_id).order_by(Location.id).all()

@router.get("/families/{family_id}/locations/tree", response_model=List[LocationTreeNode])
def get_location_tree(family_id: int, db: Session = Depends(get_db)):
    all_locs = db.query(Location).filter(Location.family_id == family_id).order_by(Location.id).all()
    node_map = {}
    for loc in all_locs:
        photos = loc.photos or []
        node_map[loc.id] = LocationTreeNode(
            id=loc.id,
            name=loc.name,
            description=loc.description,
            photos=photos,
            photo_urls=[resolve_photo_url(p) for p in photos],
            sub_locations=[]
        )
        
    roots = []
    for loc in all_locs:
        node = node_map[loc.id]
        if loc.parent_id is None:
            roots.append(node)
        else:
            parent_node = node_map.get(loc.parent_id)
            if parent_node:
                parent_node.sub_locations.append(node)
            else:
                roots.append(node)
    return roots

@router.post("/families/{family_id}/locations", response_model=LocationResponse, status_code=201)
def create_location(family_id: int, loc_in: LocationCreate, db: Session = Depends(get_db)):
    photos = (loc_in.photos or [])[:3]
    loc = Location(
        family_id=family_id,
        parent_id=loc_in.parent_id,
        name=loc_in.name,
        description=loc_in.description,
        photos=photos
    )
    db.add(loc)
    db.commit()
    db.refresh(loc)
    return loc

@router.put("/locations/{location_id}", response_model=LocationResponse)
def update_location(location_id: int, loc_in: LocationUpdate, db: Session = Depends(get_db)):
    loc = db.query(Location).filter(Location.id == location_id).first()
    if not loc:
        raise HTTPException(status_code=404, detail="Location not found")
        
    loc.name = loc_in.name
    loc.description = loc_in.description
    loc.photos = (loc_in.photos or [])[:3]
    db.commit()
    db.refresh(loc)
    return loc

@router.delete("/locations/{location_id}", status_code=204)
def delete_location(location_id: int, db: Session = Depends(get_db)):
    loc = db.query(Location).filter(Location.id == location_id).first()
    if not loc:
        raise HTTPException(status_code=404, detail="Location not found")
        
    item_count = db.query(Item).filter(Item.location_id == location_id).count()
    if item_count > 0:
        raise HTTPException(status_code=400, detail=f"無法刪除此儲存格，內部尚有 {item_count} 件物品，請先將物品移出。")
        
    sub_count = db.query(Location).filter(Location.parent_id == location_id).count()
    if sub_count > 0:
        raise HTTPException(status_code=400, detail=f"無法刪除此空間，內部尚有 {sub_count} 個子空間隔層，請先清理子空間。")
        
    db.delete(loc)
    db.commit()
    return None
