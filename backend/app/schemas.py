from pydantic import BaseModel, Field, computed_field
from typing import List, Optional
from datetime import datetime
from app.config import settings

def resolve_photo_url(photo_key: str) -> str:
    if not photo_key:
        return ""
    if photo_key.startswith("http://") or photo_key.startswith("https://") or photo_key.startswith("data:"):
        return photo_key
    domain = settings.R2_PUBLIC_DOMAIN.rstrip("/")
    clean_key = photo_key.lstrip("/")
    return f"{domain}/{clean_key}"

class MemberBase(BaseModel):
    name: str = Field(..., max_length=100)
    color: str = Field(default="#3F51B5")
    pincode: Optional[str] = None
    email: Optional[str] = None

class MemberCreate(MemberBase):
    pass

class MemberResponse(MemberBase):
    id: int
    family_id: int
    has_pincode: bool = False
    created_at: datetime

    class Config:
        from_attributes = True

    @computed_field
    def has_pin(self) -> bool:
        return bool(self.pincode)

class LocationBase(BaseModel):
    name: str = Field(..., max_length=100)
    description: Optional[str] = None
    parent_id: Optional[int] = None
    photos: List[str] = Field(default_factory=list)

class LocationCreate(LocationBase):
    pass

class LocationUpdate(BaseModel):
    name: str
    description: Optional[str] = None
    photos: List[str] = Field(default_factory=list)

class LocationResponse(LocationBase):
    id: int
    family_id: int
    created_at: datetime

    @computed_field
    def photo_urls(self) -> List[str]:
        return [resolve_photo_url(p) for p in self.photos]

    class Config:
        from_attributes = True

class LocationTreeNode(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    photos: List[str] = Field(default_factory=list)
    photo_urls: List[str] = Field(default_factory=list)
    sub_locations: List['LocationTreeNode'] = Field(default_factory=list)

class ItemBase(BaseModel):
    name: str = Field(..., max_length=100)
    description: Optional[str] = None
    location_id: Optional[int] = None
    photos: List[str] = Field(default_factory=list)

class ItemCreate(ItemBase):
    pass

class ItemUpdate(BaseModel):
    name: str
    description: Optional[str] = None
    location_id: Optional[int] = None
    photos: List[str] = Field(default_factory=list)

class ItemResponse(ItemBase):
    id: int
    family_id: int
    status: str
    checked_out_by_member_id: Optional[int] = None
    checked_out_at: Optional[datetime] = None
    created_at: datetime

    @computed_field
    def photo_urls(self) -> List[str]:
        return [resolve_photo_url(p) for p in self.photos]

    class Config:
        from_attributes = True

class CheckOutRequest(BaseModel):
    member_id: int

class CheckInRequest(BaseModel):
    member_id: int
    location_id: Optional[int] = None

class ActivityLogResponse(BaseModel):
    id: int
    family_id: int
    item_id: int
    item_name: str
    member_id: int
    member_name: str
    location_id: Optional[int] = None
    location_name: str
    action: str
    created_at: datetime

    class Config:
        from_attributes = True

class SearchResultItem(BaseModel):
    item: ItemResponse
    score: float
    location_path: str

class DirectPrintRequest(BaseModel):
    item_id: Optional[int] = None
    location_id: Optional[int] = None
    title: str = Field(..., max_length=80)
    qr_payload: str = Field(..., max_length=80)
    copies: int = 1
