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
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
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
    backup_enabled = Column(Boolean, default=False, nullable=False)

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
    media_type = Column(String, nullable=False, default="movie")
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

    __table_args__ = (
        Index("ix_movies_user_last_modified", "user_id", "last_modified"),
    )


class Recommendation(Base):
    """Recommendation table tracking who voted for which movie (upvote or downvote)."""

    __tablename__ = "recommendations"

    id = Column(Integer, primary_key=True, autoincrement=True)
    imdb_id = Column(String, nullable=False)
    user_id = Column(String, nullable=False)
    person_id = Column(Integer, ForeignKey("people.id", ondelete="CASCADE"), nullable=False)
    date_recommended = Column(Float, default=lambda: time.time())
    vote_type = Column(Boolean, nullable=False, default=True)  # True=upvote, False=downvote

    # Relationships
    movie = relationship(
        "Movie",
        back_populates="recommendations",
        foreign_keys=[imdb_id, user_id],
        primaryjoin="and_(Recommendation.imdb_id==Movie.imdb_id, Recommendation.user_id==Movie.user_id)",
    )
    person_ref = relationship("Person", back_populates="recommendations")

    __table_args__ = (
        ForeignKeyConstraint(
            ["imdb_id", "user_id"],
            ["movies.imdb_id", "movies.user_id"],
            ondelete="CASCADE",
        ),
        UniqueConstraint("imdb_id", "user_id", "person_id", name="uq_recommendation_per_person"),
        Index("ix_recommendations_user_person", "user_id", "person_id"),
        Index("ix_recommendations_movie_user", "imdb_id", "user_id"),
    )

    @property
    def person_name(self) -> str:
        return self.person_ref.name if self.person_ref else ""

    @property
    def person(self) -> str:
        # Legacy compatibility for older serializers/clients.
        return self.person_name


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

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, nullable=False)
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    is_trusted = Column(Boolean, default=False)
    color = Column(String, default="#0a84ff")
    emoji = Column(String, nullable=True)
    quick_key = Column(String, nullable=True)
    last_modified = Column(
        Float, default=lambda: time.time(), onupdate=lambda: time.time()
    )

    # Relationships
    user = relationship("User", back_populates="people")
    recommendations = relationship(
        "Recommendation",
        back_populates="person_ref",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        UniqueConstraint("user_id", "name", name="uq_person_name_per_user"),
        Index("ix_people_user_last_modified", "user_id", "last_modified"),
    )


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
    last_modified = Column(
        Float, default=lambda: time.time(), onupdate=lambda: time.time()
    )

    # Relationships
    user = relationship("User", back_populates="custom_lists")

    __table_args__ = (
        Index("ix_custom_lists_user_last_modified", "user_id", "last_modified"),
    )


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
        Index("ix_movie_status_user_custom_list", "user_id", "custom_list_id"),
    )
