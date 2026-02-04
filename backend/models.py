"""SQLAlchemy models for the movie recommendation database."""

import time
from sqlalchemy import (
    Column, String, Float, Integer, Boolean, ForeignKey, CheckConstraint, Text
)
from sqlalchemy.orm import relationship
from database import Base


class Movie(Base):
    """Movie table storing TMDB and OMDb data."""
    __tablename__ = "movies"

    imdb_id = Column(String, primary_key=True, index=True)
    tmdb_data = Column(Text)  # JSON string of TMDB data
    omdb_data = Column(Text)  # JSON string of OMDb data
    last_modified = Column(Float, default=lambda: time.time(), onupdate=lambda: time.time())

    # Relationships
    recommendations = relationship("Recommendation", back_populates="movie", cascade="all, delete-orphan")
    watch_history = relationship("WatchHistory", back_populates="movie", uselist=False, cascade="all, delete-orphan")
    status = relationship("MovieStatus", back_populates="movie", uselist=False, cascade="all, delete-orphan")


class Recommendation(Base):
    """Recommendation table tracking who recommended which movie."""
    __tablename__ = "recommendations"

    id = Column(Integer, primary_key=True, autoincrement=True)
    imdb_id = Column(String, ForeignKey("movies.imdb_id", ondelete="CASCADE"), nullable=False)
    person = Column(String, nullable=False)
    date_recommended = Column(Float, default=lambda: time.time())

    # Relationships
    movie = relationship("Movie", back_populates="recommendations")


class WatchHistory(Base):
    """Watch history table tracking when movies were watched and user ratings."""
    __tablename__ = "watch_history"

    imdb_id = Column(String, ForeignKey("movies.imdb_id", ondelete="CASCADE"), primary_key=True)
    date_watched = Column(Float, nullable=False)
    my_rating = Column(Float, nullable=False)  # 1-10 scale with 1 decimal

    # Relationships
    movie = relationship("Movie", back_populates="watch_history")

    __table_args__ = (
        CheckConstraint('my_rating >= 1.0 AND my_rating <= 10.0', name='check_rating_range'),
    )


class Person(Base):
    """People table for managing recommenders."""
    __tablename__ = "people"

    name = Column(String, primary_key=True)
    is_trusted = Column(Boolean, default=False)


class MovieStatus(Base):
    """Movie status table for tracking movie state."""
    __tablename__ = "movie_status"

    imdb_id = Column(String, ForeignKey("movies.imdb_id", ondelete="CASCADE"), primary_key=True)
    status = Column(String, nullable=False, default="toWatch")

    # Relationships
    movie = relationship("Movie", back_populates="status")

    __table_args__ = (
        CheckConstraint(
            "status IN ('toWatch', 'watched', 'questionable', 'deleted')",
            name='check_status_values'
        ),
    )
