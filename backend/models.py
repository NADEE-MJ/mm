"""SQLAlchemy models for Gymbo."""

from __future__ import annotations

import time
import uuid

from database import Base
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    Float,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String, unique=True, index=True, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    created_at = Column(Float, default=lambda: time.time())
    is_active = Column(Boolean, default=True)
    backup_enabled = Column(Boolean, default=False, nullable=False)
    unit_preference = Column(String, default="lbs", nullable=False)
    barbell_weight = Column(Float, default=45.0, nullable=False)


class WorkoutType(Base):
    __tablename__ = "workout_types"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    name = Column(String, nullable=False)
    slug = Column(String, nullable=False)
    icon = Column(String, nullable=True)
    color = Column(String, nullable=True)
    is_system = Column(Boolean, default=False, nullable=False)
    last_modified = Column(Float, default=lambda: time.time(), onupdate=lambda: time.time())

    __table_args__ = (
        UniqueConstraint("user_id", "slug", name="uq_workout_type_user_slug"),
        Index("ix_workout_types_user_last_modified", "user_id", "last_modified"),
    )


class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    muscle_groups = Column(Integer, nullable=False, default=0)
    workout_type = Column(Integer, nullable=True)
    weight_type = Column(Integer, nullable=False)
    warmup_sets = Column(Integer, default=0, nullable=False)
    accessories = Column(JSON, nullable=False, default=list)
    video_url = Column(Text, nullable=True)
    goal_reps_min = Column(Integer, nullable=True)
    goal_reps_max = Column(Integer, nullable=True)
    show_highest_set = Column(Boolean, default=False, nullable=False)
    track_highest_set = Column(Boolean, default=False, nullable=False)
    highest_set_weight = Column(Float, nullable=True)
    highest_set_reps = Column(Integer, nullable=True)
    show_one_rep_max = Column(Boolean, default=False, nullable=False)
    track_one_rep_max = Column(Boolean, default=False, nullable=False)
    one_rep_max = Column(Float, nullable=True)
    is_system = Column(Boolean, default=False, nullable=False)
    source_exercise_id = Column(String, ForeignKey("exercises.id", ondelete="SET NULL"), nullable=True)
    last_modified = Column(Float, default=lambda: time.time(), onupdate=lambda: time.time())

    __table_args__ = (
        CheckConstraint(
            "warmup_sets >= 0",
            name="ck_exercise_warmup_sets_non_negative",
        ),
        CheckConstraint(
            "goal_reps_min IS NULL OR goal_reps_min >= 1",
            name="ck_exercise_goal_reps_min_positive",
        ),
        CheckConstraint(
            "goal_reps_max IS NULL OR goal_reps_max >= 1",
            name="ck_exercise_goal_reps_max_positive",
        ),
        CheckConstraint(
            "goal_reps_min IS NULL OR goal_reps_max IS NULL OR goal_reps_min <= goal_reps_max",
            name="ck_exercise_goal_reps_order",
        ),
        CheckConstraint(
            "highest_set_weight IS NULL OR highest_set_weight >= 0",
            name="ck_exercise_highest_set_weight_non_negative",
        ),
        CheckConstraint(
            "highest_set_reps IS NULL OR highest_set_reps >= 1",
            name="ck_exercise_highest_set_reps_positive",
        ),
        CheckConstraint(
            "one_rep_max IS NULL OR one_rep_max >= 0",
            name="ck_exercise_one_rep_max_non_negative",
        ),
        Index("ix_exercises_user_last_modified", "user_id", "last_modified"),
    )


class WorkoutTemplate(Base):
    __tablename__ = "workout_templates"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    workout_type_id = Column(String, ForeignKey("workout_types.id", ondelete="SET NULL"), nullable=True)
    is_system = Column(Boolean, default=False, nullable=False)
    created_at = Column(Float, default=lambda: time.time())
    last_modified = Column(Float, default=lambda: time.time(), onupdate=lambda: time.time())

    exercises = relationship(
        "WorkoutTemplateExercise",
        back_populates="template",
        cascade="all, delete-orphan",
        order_by="WorkoutTemplateExercise.position",
    )

    __table_args__ = (
        Index("ix_templates_user_last_modified", "user_id", "last_modified"),
    )


class WorkoutTemplateExercise(Base):
    __tablename__ = "workout_template_exercises"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    template_id = Column(String, ForeignKey("workout_templates.id", ondelete="CASCADE"), nullable=False)
    exercise_id = Column(String, ForeignKey("exercises.id", ondelete="CASCADE"), nullable=False)
    position = Column(Integer, nullable=False, default=0)
    default_sets = Column(Integer, nullable=True)
    default_reps = Column(Integer, nullable=True)
    default_weight = Column(Float, nullable=True)
    default_duration_secs = Column(Integer, nullable=True)
    default_distance = Column(Float, nullable=True)
    notes = Column(Text, nullable=True)
    last_modified = Column(Float, default=lambda: time.time(), onupdate=lambda: time.time())

    template = relationship("WorkoutTemplate", back_populates="exercises")
    exercise = relationship("Exercise")

    __table_args__ = (
        UniqueConstraint("template_id", "position", name="uq_template_position"),
        Index("ix_template_exercises_template", "template_id"),
    )


class WeeklySchedule(Base):
    __tablename__ = "weekly_schedule"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    day_of_week = Column(Integer, nullable=False)
    template_id = Column(String, ForeignKey("workout_templates.id", ondelete="SET NULL"), nullable=True)
    last_modified = Column(Float, default=lambda: time.time(), onupdate=lambda: time.time())

    template = relationship("WorkoutTemplate")

    __table_args__ = (
        CheckConstraint("day_of_week >= 0 AND day_of_week <= 6", name="ck_weekly_schedule_day"),
        Index("ix_weekly_schedule_user_day", "user_id", "day_of_week"),
        Index("ix_weekly_schedule_user_last_modified", "user_id", "last_modified"),
    )


class WorkoutSession(Base):
    __tablename__ = "workout_sessions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    template_id = Column(String, ForeignKey("workout_templates.id", ondelete="SET NULL"), nullable=True)
    date = Column(Float, nullable=False)
    started_at = Column(Float, nullable=True)
    finished_at = Column(Float, nullable=True)
    duration_secs = Column(Integer, nullable=True)
    notes = Column(Text, nullable=True)
    status = Column(String, nullable=False, default="in_progress")
    last_modified = Column(Float, default=lambda: time.time(), onupdate=lambda: time.time())

    exercises = relationship(
        "SessionExercise",
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="SessionExercise.position",
    )

    __table_args__ = (
        CheckConstraint("status IN ('in_progress','completed','abandoned')", name="ck_session_status"),
        Index("ix_sessions_user_date", "user_id", "date"),
        Index("ix_sessions_user_last_modified", "user_id", "last_modified"),
    )


class SessionExercise(Base):
    __tablename__ = "session_exercises"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id = Column(String, ForeignKey("workout_sessions.id", ondelete="CASCADE"), nullable=False)
    exercise_id = Column(String, ForeignKey("exercises.id", ondelete="CASCADE"), nullable=False)
    position = Column(Integer, nullable=False, default=0)
    notes = Column(Text, nullable=True)
    last_modified = Column(Float, default=lambda: time.time(), onupdate=lambda: time.time())

    session = relationship("WorkoutSession", back_populates="exercises")
    exercise = relationship("Exercise")
    sets = relationship(
        "SessionSet",
        back_populates="session_exercise",
        cascade="all, delete-orphan",
        order_by="SessionSet.set_number",
    )

    __table_args__ = (
        UniqueConstraint("session_id", "position", name="uq_session_exercise_position"),
        Index("ix_session_exercises_session", "session_id"),
    )


class SessionSet(Base):
    __tablename__ = "session_sets"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    session_exercise_id = Column(String, ForeignKey("session_exercises.id", ondelete="CASCADE"), nullable=False)
    set_number = Column(Integer, nullable=False)
    reps = Column(Integer, nullable=True)
    weight = Column(Float, nullable=True)
    duration_secs = Column(Integer, nullable=True)
    distance = Column(Float, nullable=True)
    is_warmup = Column(Boolean, default=False, nullable=False)
    used_accessories = Column(JSON, nullable=False, default=list)
    band_color = Column(String, nullable=True)
    completed = Column(Boolean, default=False, nullable=False)
    last_modified = Column(Float, default=lambda: time.time(), onupdate=lambda: time.time())

    session_exercise = relationship("SessionExercise", back_populates="sets")

    __table_args__ = (
        UniqueConstraint("session_exercise_id", "set_number", name="uq_session_set_number"),
        Index("ix_session_sets_exercise", "session_exercise_id"),
    )
