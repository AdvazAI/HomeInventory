from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, JSON, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base

class Family(Base):
    __tablename__ = "families"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    members = relationship("Member", back_populates="family", cascade="all, delete-orphan")
    locations = relationship("Location", back_populates="family", cascade="all, delete-orphan")
    items = relationship("Item", back_populates="family", cascade="all, delete-orphan")
    activity_logs = relationship("ActivityLog", back_populates="family", cascade="all, delete-orphan")


class Member(Base):
    __tablename__ = "members"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    color = Column(String(20), default="#3F51B5")
    pincode = Column(String(20), nullable=True)
    email = Column(String(255), nullable=True, index=True)
    google_id = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    family = relationship("Family", back_populates="members")
    activity_logs = relationship("ActivityLog", back_populates="member", cascade="all, delete-orphan")


class Location(Base):
    __tablename__ = "locations"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id", ondelete="CASCADE"), nullable=False, index=True)
    parent_id = Column(Integer, ForeignKey("locations.id", ondelete="SET NULL"), nullable=True, index=True)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    photos = Column(JSON, default=list)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    family = relationship("Family", back_populates="locations")
    parent = relationship("Location", remote_side=[id], backref="sub_locations")
    items = relationship("Item", back_populates="location")


class Item(Base):
    __tablename__ = "items"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id", ondelete="CASCADE"), nullable=False, index=True)
    location_id = Column(Integer, ForeignKey("locations.id", ondelete="SET NULL"), nullable=True, index=True)
    name = Column(String(100), nullable=False, index=True)
    description = Column(Text, nullable=True)
    status = Column(String(30), default="checked_in", index=True)
    checked_out_by_member_id = Column(Integer, ForeignKey("members.id", ondelete="SET NULL"), nullable=True)
    checked_out_at = Column(DateTime(timezone=True), nullable=True)
    photos = Column(JSON, default=list)
    search_vector = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    family = relationship("Family", back_populates="items")
    location = relationship("Location", back_populates="items")
    checked_out_by = relationship("Member")
    activity_logs = relationship("ActivityLog", back_populates="item", cascade="all, delete-orphan")


class ActivityLog(Base):
    __tablename__ = "activity_logs"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id", ondelete="CASCADE"), nullable=False, index=True)
    item_id = Column(Integer, ForeignKey("items.id", ondelete="CASCADE"), nullable=False, index=True)
    member_id = Column(Integer, ForeignKey("members.id", ondelete="CASCADE"), nullable=False, index=True)
    location_id = Column(Integer, ForeignKey("locations.id", ondelete="SET NULL"), nullable=True)
    action = Column(String(30), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    family = relationship("Family", back_populates="activity_logs")
    item = relationship("Item", back_populates="activity_logs")
    member = relationship("Member", back_populates="activity_logs")
    location = relationship("Location")
