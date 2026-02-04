"""SQLAlchemy models for the movie recommendation database."""

import time
import uuid

from database import Base
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    Float,
    ForeignKey,
    ForeignKeyConstraint,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship


class User(Base):
    """User table for authentication."""

    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String, unique=True, index=True, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    created_at = Column(Float, default=lambda: time.time())
    is_active = Column(Boolean, default=True)

    # Relationships
    movies = relationship("Movie", back_populates="user", cascade="all, delete-orphan")
    people = relationship("Person", back_populates="user", cascade="all, delete-orphan")
    custom_lists = relationship(
        "CustomList", back_populates="user", cascade="all, delete-orphan"
    )


class Movie(Base):
    """Movie table storing TMDB and OMDb data."""

    __tablename__ = "movies"

    imdb_id = Column(String, primary_key=True, index=True)
    user_id = Column(
        String, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    tmdb_data = Column(Text)  # JSON string of TMDB data
    omdb_data = Column(Text)  # JSON string of OMDb data
    last_modified = Column(
        Float, default=lambda: time.time(), onupdate=lambda: time.time()
    )

    # Relationships
    user = relationship("User", back_populates="movies")
    recommendations = relationship(
        "Recommendation", back_populates="movie", cascade="all, delete-orphan"
    )
    watch_history = relationship(
        "WatchHistory",
        back_populates="movie",
        uselist=False,
        cascade="all, delete-orphan",
    )
    status = relationship(
        "MovieStatus",
        back_populates="movie",
        uselist=False,
        cascade="all, delete-orphan",
    )


class Recommendation(Base):
    """Recommendation table tracking who recommended which movie."""

    __tablename__ = "recommendations"

    id = Column(Integer, primary_key=True, autoincrement=True)
    imdb_id = Column(String, nullable=False)
    user_id = Column(String, nullable=False)
    person = Column(String, nullable=False)
    date_recommended = Column(Float, default=lambda: time.time())

    # Relationships
    movie = relationship(
        "Movie",
        back_populates="recommendations",
        foreign_keys=[imdb_id, user_id],
        primaryjoin="and_(Recommendation.imdb_id==Movie.imdb_id, Recommendation.user_id==Movie.user_id)",
    )

    __table_args__ = (
        ForeignKeyConstraint(
            ["imdb_id", "user_id"],
            ["movies.imdb_id", "movies.user_id"],
            ondelete="CASCADE",
        ),
    )


class WatchHistory(Base):
    """Watch history table tracking when movies were watched and user ratings."""

    __tablename__ = "watch_history"

    imdb_id = Column(String, primary_key=True)
    user_id = Column(String, primary_key=True)
    date_watched = Column(Float, nullable=False)
    my_rating = Column(Float, nullable=False)  # 1-10 scale with 1 decimal

    # Relationships
    movie = relationship(
        "Movie",
        back_populates="watch_history",
        foreign_keys=[imdb_id, user_id],
        primaryjoin="and_(WatchHistory.imdb_id==Movie.imdb_id, WatchHistory.user_id==Movie.user_id)",
    )

    __table_args__ = (
        ForeignKeyConstraint(
            ["imdb_id", "user_id"],
            ["movies.imdb_id", "movies.user_id"],
            ondelete="CASCADE",
        ),
        CheckConstraint(
            "my_rating >= 1.0 AND my_rating <= 10.0", name="check_rating_range"
        ),
    )


class Person(Base):
    """People table for managing recommenders."""

    __tablename__ = "people"

    name = Column(String, primary_key=True)
    user_id = Column(
        String, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    is_trusted = Column(Boolean, default=False)
    is_default = Column(Boolean, default=False)  # For system default recommenders

    # Relationships
    user = relationship("User", back_populates="people")


class CustomList(Base):
    """Custom lists created by users."""

    __tablename__ = "custom_lists"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String, nullable=False)
    color = Column(String, default="#0a84ff")  # iOS blue default
    icon = Column(String, default="list")
    position = Column(Integer, default=0)
    created_at = Column(Float, default=lambda: time.time())

    # Relationships
    user = relationship("User", back_populates="custom_lists")


class MovieStatus(Base):
    """Movie status table for tracking movie state."""

    __tablename__ = "movie_status"

    imdb_id = Column(String, primary_key=True)
    user_id = Column(String, primary_key=True)
    status = Column(String, nullable=False, default="toWatch")
    custom_list_id = Column(String, nullable=True)  # For custom lists

    # Relationships
    movie = relationship(
        "Movie",
        back_populates="status",
        foreign_keys=[imdb_id, user_id],
        primaryjoin="and_(MovieStatus.imdb_id==Movie.imdb_id, MovieStatus.user_id==Movie.user_id)",
    )

    __table_args__ = (
        ForeignKeyConstraint(
            ["imdb_id", "user_id"],
            ["movies.imdb_id", "movies.user_id"],
            ondelete="CASCADE",
        ),
        CheckConstraint(
            "status IN ('toWatch', 'watched', 'deleted', 'custom')",
            name="check_status_values",
        ),
    )
