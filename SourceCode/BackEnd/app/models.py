from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, JSON, text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from sqlalchemy.types import UserDefinedType
import json

from app.config import settings
from app.database import Base

# Conditionally define SafeVector depending on the database dialect
if settings.DATABASE_URL.startswith("sqlite"):
    class SafeVector(UserDefinedType):
        def __init__(self, dim):
            self.dim = dim

        def get_col_spec(self, **kw):
            return f"TEXT"

        def bind_processor(self, dialect):
            return lambda value: json.dumps(value) if value is not None else None

        def result_processor(self, dialect, coltype):
            return lambda value: json.loads(value) if value is not None else None
else:
    from pgvector.sqlalchemy import Vector
    class SafeVector(Vector):
        pass


class Family(Base):
    __tablename__ = "families"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    members = relationship("Member", back_populates="family", cascade="all, delete-orphan")
    items = relationship("Item", back_populates="family", cascade="all, delete-orphan")
    locations = relationship("Location", back_populates="family", cascade="all, delete-orphan")
    activity_logs = relationship("ActivityLog", back_populates="family", cascade="all, delete-orphan")


class Member(Base):
    __tablename__ = "members"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id", ondelete="CASCADE"), nullable=False)
    name = Column(String, nullable=False)
    color = Column(String, default="#4CAF50")  # Hex color for UI representation
    pincode = Column(String, nullable=True)     # Optional screen lock PIN
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    family = relationship("Family", back_populates="members")
    activity_logs = relationship("ActivityLog", back_populates="member", cascade="all, delete-orphan")


class Location(Base):
    __tablename__ = "locations"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id", ondelete="CASCADE"), nullable=False)
    parent_id = Column(Integer, ForeignKey("locations.id", ondelete="SET NULL"), nullable=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    photos = Column(JSON, default=list)  # List of URLs of physical photos of location
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    family = relationship("Family", back_populates="locations")
    parent = relationship("Location", remote_side=[id], backref="sub_locations")
    items = relationship("Item", back_populates="location")


class Item(Base):
    __tablename__ = "items"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id", ondelete="CASCADE"), nullable=False)
    location_id = Column(Integer, ForeignKey("locations.id", ondelete="SET NULL"), nullable=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    status = Column(String, default="checked_in")  # "checked_in" or "checked_out"
    checked_out_by_member_id = Column(Integer, ForeignKey("members.id", ondelete="SET NULL"), nullable=True)
    checked_out_at = Column(DateTime(timezone=True), nullable=True)
    photos = Column(JSON, default=list)  # List of URLs (1 to 4 images)
    
    # 384 dimensions for sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
    search_vector = Column(SafeVector(384), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    family = relationship("Family", back_populates="items")
    location = relationship("Location", back_populates="items")
    checked_out_by = relationship("Member")
    activity_logs = relationship("ActivityLog", back_populates="item", cascade="all, delete-orphan")


class ActivityLog(Base):
    __tablename__ = "activity_logs"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id", ondelete="CASCADE"), nullable=False)
    item_id = Column(Integer, ForeignKey("items.id", ondelete="CASCADE"), nullable=False)
    member_id = Column(Integer, ForeignKey("members.id", ondelete="CASCADE"), nullable=False)
    location_id = Column(Integer, ForeignKey("locations.id", ondelete="SET NULL"), nullable=True)
    action = Column(String, nullable=False)  # "check_in" or "check_out"
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    family = relationship("Family", back_populates="activity_logs")
    item = relationship("Item", back_populates="activity_logs")
    member = relationship("Member", back_populates="activity_logs")
    location = relationship("Location")
