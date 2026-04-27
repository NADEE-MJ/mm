from __future__ import annotations

from enum import IntEnum

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class MuscleGroup(IntEnum):
    CHEST = 1
    BACK = 2
    SHOULDERS = 4
    BICEPS = 8
    TRICEPS = 16
    LEGS = 32
    CORE = 64
    CARDIO = 128
    FULL_BODY = 256
    PLYOMETRIC = 512
    PILATES = 1024
    MOBILITY = 2048


MUSCLE_GROUP_LABELS: dict[int, str] = {
    MuscleGroup.CHEST: "Chest",
    MuscleGroup.BACK: "Back",
    MuscleGroup.SHOULDERS: "Shoulders",
    MuscleGroup.BICEPS: "Biceps",
    MuscleGroup.TRICEPS: "Triceps",
    MuscleGroup.LEGS: "Legs",
    MuscleGroup.CORE: "Core",
    MuscleGroup.CARDIO: "Cardio",
    MuscleGroup.FULL_BODY: "Full Body",
    MuscleGroup.PLYOMETRIC: "Plyometric",
    MuscleGroup.PILATES: "Pilates",
    MuscleGroup.MOBILITY: "Mobility",
}

# Bitmask of all valid muscle group bits
ALL_MUSCLE_BITS: int = sum(mg.value for mg in MuscleGroup)


class WeightType(IntEnum):
    BODYWEIGHT = 1
    DUMBBELLS = 2
    PLATES = 3
    RAW_WEIGHT = 4
    BANDS = 5
    TIME_BASED = 6
    DISTANCE = 7


WEIGHT_TYPE_LABELS: dict[int, str] = {
    WeightType.BODYWEIGHT: "No Weight / Bodyweight",
    WeightType.DUMBBELLS: "Dumbbells",
    WeightType.PLATES: "Plates",
    WeightType.RAW_WEIGHT: "Raw Weight (Machine/Cable)",
    WeightType.BANDS: "Bands",
    WeightType.TIME_BASED: "Time Based",
    WeightType.DISTANCE: "Distance",
}

VALID_WEIGHT_TYPES: set[int] = {wt.value for wt in WeightType}


class ExerciseWorkoutType(IntEnum):
    LIFTING = 1
    RUNNING = 2
    PILATES = 3
    MOBILITY = 4
    PLYOMETRIC = 5
    HYROX = 6
    CUSTOM = 7


EXERCISE_WORKOUT_TYPE_LABELS: dict[int, str] = {
    ExerciseWorkoutType.LIFTING: "Lifting",
    ExerciseWorkoutType.RUNNING: "Running",
    ExerciseWorkoutType.PILATES: "Pilates",
    ExerciseWorkoutType.MOBILITY: "Mobility/Stretching",
    ExerciseWorkoutType.PLYOMETRIC: "Plyometric",
    ExerciseWorkoutType.HYROX: "Hyrox Training",
    ExerciseWorkoutType.CUSTOM: "Custom",
}

VALID_WORKOUT_TYPES: set[int] = {wt.value for wt in ExerciseWorkoutType}

# Legacy string → int mappings (used in migration and sync fallback)
WEIGHT_TYPE_STRING_TO_INT: dict[str, int] = {
    "bodyweight": WeightType.BODYWEIGHT,
    "dumbbells": WeightType.DUMBBELLS,
    "dumbbell": WeightType.DUMBBELLS,
    "plates": WeightType.PLATES,
    "raw_weight": WeightType.RAW_WEIGHT,
    "machine": WeightType.RAW_WEIGHT,
    "bands": WeightType.BANDS,
    "time_based": WeightType.TIME_BASED,
    "distance": WeightType.DISTANCE,
}

MUSCLE_GROUP_STRING_TO_BIT: dict[str, int] = {
    "chest": MuscleGroup.CHEST,
    "back": MuscleGroup.BACK,
    "shoulders": MuscleGroup.SHOULDERS,
    "biceps": MuscleGroup.BICEPS,
    "triceps": MuscleGroup.TRICEPS,
    "legs": MuscleGroup.LEGS,
    "core": MuscleGroup.CORE,
    "cardio": MuscleGroup.CARDIO,
    "full_body": MuscleGroup.FULL_BODY,
    "plyometric": MuscleGroup.PLYOMETRIC,
    "pilates": MuscleGroup.PILATES,
    "mobility": MuscleGroup.MOBILITY,
}

WORKOUT_TYPE_SLUG_TO_INT: dict[str, int] = {
    "lifting": ExerciseWorkoutType.LIFTING,
    "running": ExerciseWorkoutType.RUNNING,
    "pilates": ExerciseWorkoutType.PILATES,
    "mobility": ExerciseWorkoutType.MOBILITY,
    "plyometric": ExerciseWorkoutType.PLYOMETRIC,
    "hyrox": ExerciseWorkoutType.HYROX,
    "custom": ExerciseWorkoutType.CUSTOM,
}


def normalize_weight_type_int(value: int | str | None) -> int:
    """Accept int or legacy string, return valid WeightType int."""
    if isinstance(value, str):
        mapped = WEIGHT_TYPE_STRING_TO_INT.get(value.strip().lower())
        if mapped is None:
            raise ValueError(f"Invalid weight_type: {value!r}")
        return mapped
    if isinstance(value, int) and value in VALID_WEIGHT_TYPES:
        return value
    raise ValueError(f"Invalid weight_type: {value!r}")


def normalize_muscle_groups(value: int | str | list | None) -> int:
    """Accept bitmask int, comma-separated string, or list of ints/strings."""
    if value is None:
        return 0
    if isinstance(value, int):
        # Mask to only valid bits
        return value & ALL_MUSCLE_BITS
    if isinstance(value, str):
        # Could be comma-separated labels or a raw int string
        try:
            return int(value) & ALL_MUSCLE_BITS
        except ValueError:
            pass
        result = 0
        for part in value.split(","):
            bit = MUSCLE_GROUP_STRING_TO_BIT.get(part.strip().lower(), 0)
            result |= bit
        return result
    if isinstance(value, list):
        result = 0
        for item in value:
            if isinstance(item, int):
                result |= item & ALL_MUSCLE_BITS
            elif isinstance(item, str):
                bit = MUSCLE_GROUP_STRING_TO_BIT.get(item.strip().lower(), 0)
                result |= bit
        return result
    return 0


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


class WorkoutTypeBase(BaseModel):
    name: str
    slug: str
    icon: str | None = None
    color: str | None = None


class WorkoutTypeCreate(WorkoutTypeBase):
    pass


class WorkoutTypeUpdate(BaseModel):
    name: str | None = None
    slug: str | None = None
    icon: str | None = None
    color: str | None = None


class WorkoutTypeOut(WorkoutTypeBase):
    id: str
    user_id: str | None
    is_system: bool
    last_modified: float | None = None

    model_config = ConfigDict(from_attributes=True)


class ExerciseBase(BaseModel):
    name: str
    description: str | None = None
    video_url: str | None = None
    muscle_groups: int = Field(default=0, ge=0)
    workout_type: int | None = None
    weight_type: int
    warmup_sets: int = Field(default=0, ge=0)
    accessories: list[str] = Field(default_factory=list)
    goal_reps_min: int | None = Field(default=None, ge=1)
    goal_reps_max: int | None = Field(default=None, ge=1)
    show_highest_set: bool = False
    track_highest_set: bool = False
    highest_set_weight: float | None = Field(default=None, ge=0)
    highest_set_reps: int | None = Field(default=None, ge=1)
    show_one_rep_max: bool = False
    track_one_rep_max: bool = False
    one_rep_max: float | None = Field(default=None, ge=0)

    @field_validator("weight_type", mode="before")
    @classmethod
    def _normalize_weight_type(cls, value: int | str) -> int:
        return normalize_weight_type_int(value)

    @field_validator("muscle_groups", mode="before")
    @classmethod
    def _normalize_muscle_groups(cls, value: int | str | list | None) -> int:
        return normalize_muscle_groups(value)

    @field_validator("workout_type", mode="before")
    @classmethod
    def _normalize_workout_type(cls, value: int | None) -> int | None:
        if value is None:
            return None
        if isinstance(value, int) and value in VALID_WORKOUT_TYPES:
            return value
        raise ValueError(f"Invalid workout_type: {value!r}")

    @field_validator("accessories", mode="before")
    @classmethod
    def _normalize_accessories(cls, value: list[str] | None) -> list[str]:
        return normalize_string_list(value)

    @model_validator(mode="after")
    def _validate_rep_goal_range(self) -> "ExerciseBase":
        if (
            self.goal_reps_min is not None
            and self.goal_reps_max is not None
            and self.goal_reps_min > self.goal_reps_max
        ):
            raise ValueError("goal_reps_min cannot be greater than goal_reps_max")
        return self


class ExerciseCreate(ExerciseBase):
    pass


class ExerciseUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    video_url: str | None = None
    muscle_groups: int | None = None
    workout_type: int | None = None
    weight_type: int | None = None
    warmup_sets: int | None = Field(default=None, ge=0)
    accessories: list[str] | None = None
    goal_reps_min: int | None = Field(default=None, ge=1)
    goal_reps_max: int | None = Field(default=None, ge=1)
    show_highest_set: bool | None = None
    track_highest_set: bool | None = None
    highest_set_weight: float | None = Field(default=None, ge=0)
    highest_set_reps: int | None = Field(default=None, ge=1)
    show_one_rep_max: bool | None = None
    track_one_rep_max: bool | None = None
    one_rep_max: float | None = Field(default=None, ge=0)

    @field_validator("weight_type", mode="before")
    @classmethod
    def _normalize_weight_type(cls, value: int | str | None) -> int | None:
        if value is None:
            return None
        return normalize_weight_type_int(value)

    @field_validator("muscle_groups", mode="before")
    @classmethod
    def _normalize_muscle_groups(cls, value: int | str | list | None) -> int | None:
        if value is None:
            return None
        return normalize_muscle_groups(value)

    @field_validator("workout_type", mode="before")
    @classmethod
    def _normalize_workout_type(cls, value: int | None) -> int | None:
        if value is None:
            return None
        if isinstance(value, int) and value in VALID_WORKOUT_TYPES:
            return value
        raise ValueError(f"Invalid workout_type: {value!r}")

    @field_validator("accessories", mode="before")
    @classmethod
    def _normalize_accessories(cls, value: list[str] | None) -> list[str] | None:
        if value is None:
            return []
        return normalize_string_list(value)

    @model_validator(mode="after")
    def _validate_rep_goal_range(self) -> "ExerciseUpdate":
        if (
            self.goal_reps_min is not None
            and self.goal_reps_max is not None
            and self.goal_reps_min > self.goal_reps_max
        ):
            raise ValueError("goal_reps_min cannot be greater than goal_reps_max")
        return self


class ExerciseOut(ExerciseBase):
    id: str
    user_id: str | None
    is_system: bool
    source_exercise_id: str | None = None
    last_modified: float

    model_config = ConfigDict(from_attributes=True)
