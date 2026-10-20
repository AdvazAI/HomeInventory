from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models import Member
from app.schemas import MemberCreate, MemberResponse

router = APIRouter(prefix="/api", tags=["Members"])

@router.get("/families/{family_id}/members", response_model=List[MemberResponse])
def get_family_members(family_id: int, db: Session = Depends(get_db)):
    return db.query(Member).filter(Member.family_id == family_id).order_by(Member.id).all()

@router.post("/families/{family_id}/members", response_model=MemberResponse, status_code=201)
def create_member(family_id: int, member_in: MemberCreate, db: Session = Depends(get_db)):
    member = Member(
        family_id=family_id,
        name=member_in.name,
        color=member_in.color,
        pincode=member_in.pincode,
        email=member_in.email.strip().lower() if member_in.email else None
    )
    db.add(member)
    db.commit()
    db.refresh(member)
    return member

@router.post("/members/{member_id}/verify-pin")
def verify_pin(member_id: int, pin: str = Body(..., embed=True), db: Session = Depends(get_db)):
    member = db.query(Member).filter(Member.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    if member.pincode == pin:
        return {"status": "verified"}
    raise HTTPException(status_code=401, detail="Invalid PIN")

@router.post("/auth/google-login", response_model=MemberResponse)
def google_login(payload: dict = Body(...), db: Session = Depends(get_db)):
    email = payload.get("email", "").strip().lower()
    google_id = payload.get("google_id", "")
    if not email:
        raise HTTPException(status_code=400, detail="Email is required")
        
    member = db.query(Member).filter(Member.email == email).first()
    if not member:
        raise HTTPException(status_code=401, detail=f"No member profile found with email '{email}'.")
        
    if not member.google_id and google_id:
        member.google_id = google_id
        db.commit()
        db.refresh(member)
        
    return member
