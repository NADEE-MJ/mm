from __future__ import annotations

from pydantic import BaseModel


class MetricsSummary(BaseModel):
    current_streak: int
    longest_streak: int
    total_sessions: int
    total_volume: float
    pr_count: int


class CalendarMetric(BaseModel):
    date: str
    session_count: int
    volume: float


class ExerciseProgressPoint(BaseModel):
    timestamp: float
    weight: float | None
    reps: int | None
    estimated_1rm: float | None


class FrequencyPoint(BaseModel):
    week_start: str
    workout_type: str
    sessions: int


class PRRecord(BaseModel):
    exercise_id: str
    exercise_name: str
    reps: int | None
    weight: float
    achieved_at: float


class StreakOut(BaseModel):
    current_streak: int
    longest_streak: int
