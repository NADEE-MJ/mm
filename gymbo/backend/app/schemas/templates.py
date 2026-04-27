from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class TemplateExerciseBase(BaseModel):
    exercise_id: str
    position: int
    default_sets: int | None = None
    default_reps: int | None = None
    default_weight: float | None = None
    default_duration_secs: int | None = None
    default_distance: float | None = None
    notes: str | None = None


class TemplateExerciseCreate(TemplateExerciseBase):
    pass


class TemplateExerciseUpdate(BaseModel):
    position: int | None = None
    default_sets: int | None = None
    default_reps: int | None = None
    default_weight: float | None = None
    default_duration_secs: int | None = None
    default_distance: float | None = None
    notes: str | None = None


class TemplateExerciseOut(TemplateExerciseBase):
    id: str
    template_id: str
    last_modified: float

    model_config = ConfigDict(from_attributes=True)


class WorkoutTemplateCreate(BaseModel):
    name: str
    description: str | None = None
    workout_type_id: str | None = None
    clone_from: str | None = None


class WorkoutTemplateUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    workout_type_id: str | None = None


class WorkoutTemplateOut(BaseModel):
    id: str
    user_id: str | None
    name: str
    description: str | None
    workout_type_id: str | None
    is_system: bool
    created_at: float
    last_modified: float
    exercises: list[TemplateExerciseOut] = []

    model_config = ConfigDict(from_attributes=True)


class ReorderTemplateExercises(BaseModel):
    exercise_ids: list[str]
