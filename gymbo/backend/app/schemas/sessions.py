from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field, field_validator


def normalize_string_list(values: object) -> list[str]:
    if not values:
        return []
    if isinstance(values, str):
        values = values.split(",")
    if not isinstance(values, list):
        return []
    cleaned: list[str] = []
    seen: set[str] = set()
    for item in values:
        value = str(item).strip()
        if not value:
            continue
        key = value.casefold()
        if key in seen:
            continue
        seen.add(key)
        cleaned.append(value)
    return cleaned


class SessionSetBase(BaseModel):
    set_number: int
    reps: int | None = None
    weight: float | None = None
    duration_secs: int | None = None
    distance: float | None = None
    is_warmup: bool = False
    used_accessories: list[str] = Field(default_factory=list)
    band_color: str | None = None
    completed: bool = False

    @field_validator("used_accessories", mode="before")
    @classmethod
    def _normalize_used_accessories(cls, value: list[str] | None) -> list[str]:
        return normalize_string_list(value)


class SessionSetCreate(SessionSetBase):
    pass


class SessionSetUpdate(BaseModel):
    set_number: int | None = None
    reps: int | None = None
    weight: float | None = None
    duration_secs: int | None = None
    distance: float | None = None
    is_warmup: bool | None = None
    used_accessories: list[str] | None = None
    band_color: str | None = None
    completed: bool | None = None

    @field_validator("used_accessories", mode="before")
    @classmethod
    def _normalize_used_accessories(cls, value: list[str] | None) -> list[str] | None:
        if value is None:
            return []
        return normalize_string_list(value)


class SessionSetOut(SessionSetBase):
    id: str
    session_exercise_id: str
    last_modified: float

    model_config = ConfigDict(from_attributes=True)


class SessionExerciseBase(BaseModel):
    exercise_id: str
    position: int
    notes: str | None = None


class SessionExerciseCreate(SessionExerciseBase):
    pass


class SessionExerciseUpdate(BaseModel):
    position: int | None = None
    notes: str | None = None


class SessionExerciseOut(SessionExerciseBase):
    id: str
    session_id: str
    last_modified: float
    sets: list[SessionSetOut] = []

    model_config = ConfigDict(from_attributes=True)


class WorkoutSessionCreate(BaseModel):
    template_id: str | None = None
    date: float | None = None
    started_at: float | None = None
    notes: str | None = None


class WorkoutSessionUpdate(BaseModel):
    template_id: str | None = None
    date: float | None = None
    started_at: float | None = None
    finished_at: float | None = None
    duration_secs: int | None = None
    notes: str | None = None
    status: str | None = None


class CompleteSessionRequest(BaseModel):
    finished_at: float | None = None


class WorkoutSessionOut(BaseModel):
    id: str
    user_id: str
    template_id: str | None
    date: float
    started_at: float | None
    finished_at: float | None
    duration_secs: int | None
    notes: str | None
    status: str
    last_modified: float
    exercises: list[SessionExerciseOut] = []

    model_config = ConfigDict(from_attributes=True)


class CompleteSessionResponse(BaseModel):
    session: WorkoutSessionOut
    prs: list[dict] = []
