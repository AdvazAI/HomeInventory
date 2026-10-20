from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional

# --- Family Schemas ---
class FamilyCreate(BaseModel):
    name: str

class FamilyResponse(BaseModel):
    id: int
    name: str
    created_at: datetime

    class Config:
        from_attributes = True


# --- Member Schemas ---
class MemberCreate(BaseModel):
    name: str
    color: str = "#4CAF50"
    pincode: Optional[str] = None

class MemberResponse(BaseModel):
    id: int
    family_id: int
    name: str
    color: str
    has_pincode: bool
    created_at: datetime

    @classmethod
    def from_orm(cls, obj):
        return cls(
            id=obj.id,
            family_id=obj.family_id,
            name=obj.name,
            color=obj.color,
            has_pincode=obj.pincode is not None and obj.pincode != "",
            created_at=obj.created_at
        )

    class Config:
        from_attributes = True


# --- Location Schemas ---
class LocationCreate(BaseModel):
    name: str
    parent_id: Optional[int] = None
    description: Optional[str] = None
    photos: List[str] = []

class LocationResponse(BaseModel):
    id: int
    family_id: int
    parent_id: Optional[int]
    name: str
    description: Optional[str]
    photos: List[str]
    created_at: datetime

    class Config:
        from_attributes = True

class LocationNodeResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    photos: List[str] = []
    sub_locations: List["LocationNodeResponse"] = []

    class Config:
        from_attributes = True


# --- Item Schemas ---
class ItemCreate(BaseModel):
    name: str
    location_id: Optional[int] = None
    description: Optional[str] = None
    photos: List[str] = []

class ItemResponse(BaseModel):
    id: int
    family_id: int
    location_id: Optional[int]
    name: str
    description: Optional[str]
    status: str
    checked_out_by_member_id: Optional[int]
    checked_out_at: Optional[datetime]
    photos: List[str]
    created_at: datetime

    class Config:
        from_attributes = True

class CheckInOutRequest(BaseModel):
    member_id: int
    location_id: Optional[int] = None  # Needed for check-in to specify target storage container


# --- Activity Log Schemas ---
class ActivityLogResponse(BaseModel):
    id: int
    family_id: int
    item_id: int
    item_name: Optional[str] = None
    member_id: int
    member_name: Optional[str] = None
    location_id: Optional[int]
    location_name: Optional[str] = None
    action: str
    created_at: datetime

    class Config:
        from_attributes = True


# --- Search Schemas ---
class SearchResult(BaseModel):
    item: ItemResponse
    score: float
    location_path: str  # e.g., "Garage > Shelf A"
