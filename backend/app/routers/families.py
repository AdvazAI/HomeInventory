from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Family, Member, Location, Item
from app.search import embedding_service

router = APIRouter(prefix="/api", tags=["Families & Setup"])

@router.post("/setup")
def initial_setup(db: Session = Depends(get_db)):
    existing_family = db.query(Family).first()
    if existing_family:
        return {"message": "Database already initialized", "family_id": existing_family.id}

    family = Family(name="Smith Family")
    db.add(family)
    db.flush()

    members_data = [
        ("Dad (Edward)", "#3F51B5", "1234", "edward@example.com"),
        ("Mom (Sarah)", "#E91E63", None, "sarah@example.com"),
        ("Alice", "#9C27B0", None, "alice@example.com"),
        ("Bob", "#FF9800", None, "bob@example.com")
    ]
    for name, color, pin, email in members_data:
        m = Member(family_id=family.id, name=name, color=color, pincode=pin, email=email)
        db.add(m)
    db.flush()

    kitchen = Location(family_id=family.id, name="廚房 (Kitchen)", description="一樓廚房料理區")
    garage = Location(family_id=family.id, name="車庫 (Garage)", description="主車庫工具間與儲藏櫃")
    db.add_all([kitchen, garage])
    db.flush()

    cabinet = Location(family_id=family.id, parent_id=kitchen.id, name="A號櫥櫃", description="廚房上方乾燥儲物櫃")
    toolbox = Location(family_id=family.id, parent_id=garage.id, name="紅色工具箱", description="車庫第二層移動式五金工具箱")
    db.add_all([cabinet, toolbox])
    db.flush()

    sample_items = [
        ("螺絲起子", "藍柄中型十字螺絲起子", toolbox.id),
        ("馬克杯", "白色陶瓷印花咖啡杯", cabinet.id),
        ("電鑽", "DeWalt 18V 充電式衝擊電鑽", garage.id),
        ("平底鍋", "黑色不沾鍋 28cm", kitchen.id),
    ]
    for name, desc, loc_id in sample_items:
        vector = embedding_service.get_embedding(f"{name} {desc}")
        item = Item(
            family_id=family.id,
            location_id=loc_id,
            name=name,
            description=desc,
            status="checked_in",
            search_vector=vector,
            photos=[]
        )
        db.add(item)

    db.commit()
    return {"message": "Database initialized successfully with default family!", "family_id": family.id}

@router.get("/families/{family_id}")
def get_family(family_id: int, db: Session = Depends(get_db)):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Family not found")
    return {"id": family.id, "name": family.name, "created_at": family.created_at}
