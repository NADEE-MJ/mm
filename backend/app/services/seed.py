"""Seed per-user workout types, exercises, and starter templates."""

from __future__ import annotations

import time

from app.schemas.exercises import (
    ExerciseWorkoutType,
    MuscleGroup,
    WeightType,
)
from models import Exercise, WorkoutTemplate, WorkoutTemplateExercise, WorkoutType
from sqlalchemy.orm import Session


WORKOUT_TYPES = [
    {"slug": "lifting", "name": "Lifting", "icon": "dumbbell", "color": "#0a84ff"},
    {"slug": "running", "name": "Running", "icon": "figure.run", "color": "#30d158"},
    {"slug": "pilates", "name": "Pilates", "icon": "figure.cooldown", "color": "#bf5af2"},
    {"slug": "mobility", "name": "Mobility/Stretching", "icon": "figure.flexibility", "color": "#ffd60a"},
    {"slug": "plyometric", "name": "Plyometric Drills", "icon": "bolt", "color": "#ff9f0a"},
    {"slug": "hyrox", "name": "Hyrox Training", "icon": "flame", "color": "#ff453a"},
    {"slug": "custom", "name": "Custom", "icon": "wrench.and.screwdriver", "color": "#64d2ff"},
]

# (name, muscle_groups_bitmask, weight_type_int, workout_type_int)
EXERCISES = [
    ("Bench Press",          MuscleGroup.CHEST,      WeightType.PLATES,      ExerciseWorkoutType.LIFTING),
    ("Incline DB Press",     MuscleGroup.CHEST,      WeightType.DUMBBELLS,   ExerciseWorkoutType.LIFTING),
    ("Push Up",              MuscleGroup.CHEST,      WeightType.BODYWEIGHT,  ExerciseWorkoutType.LIFTING),
    ("Deadlift",             MuscleGroup.BACK,       WeightType.PLATES,      ExerciseWorkoutType.LIFTING),
    ("Pull Up",              MuscleGroup.BACK,       WeightType.BODYWEIGHT,  ExerciseWorkoutType.LIFTING),
    ("Barbell Row",          MuscleGroup.BACK,       WeightType.PLATES,      ExerciseWorkoutType.LIFTING),
    ("Lat Pulldown",         MuscleGroup.BACK,       WeightType.RAW_WEIGHT,  ExerciseWorkoutType.LIFTING),
    ("Seated Row",           MuscleGroup.BACK,       WeightType.RAW_WEIGHT,  ExerciseWorkoutType.LIFTING),
    ("Overhead Press",       MuscleGroup.SHOULDERS,  WeightType.PLATES,      ExerciseWorkoutType.LIFTING),
    ("Lateral Raise",        MuscleGroup.SHOULDERS,  WeightType.DUMBBELLS,   ExerciseWorkoutType.LIFTING),
    ("Face Pull",            MuscleGroup.SHOULDERS,  WeightType.RAW_WEIGHT,  ExerciseWorkoutType.LIFTING),
    ("Barbell Curl",         MuscleGroup.BICEPS,     WeightType.PLATES,      ExerciseWorkoutType.LIFTING),
    ("Dumbbell Curl",        MuscleGroup.BICEPS,     WeightType.DUMBBELLS,   ExerciseWorkoutType.LIFTING),
    ("Hammer Curl",          MuscleGroup.BICEPS,     WeightType.DUMBBELLS,   ExerciseWorkoutType.LIFTING),
    ("Tricep Pushdown",      MuscleGroup.TRICEPS,    WeightType.RAW_WEIGHT,  ExerciseWorkoutType.LIFTING),
    ("Skull Crushers",       MuscleGroup.TRICEPS,    WeightType.PLATES,      ExerciseWorkoutType.LIFTING),
    ("Dip",                  MuscleGroup.TRICEPS,    WeightType.BODYWEIGHT,  ExerciseWorkoutType.LIFTING),
    ("Squat",                MuscleGroup.LEGS,       WeightType.PLATES,      ExerciseWorkoutType.LIFTING),
    ("Romanian Deadlift",    MuscleGroup.LEGS,       WeightType.PLATES,      ExerciseWorkoutType.LIFTING),
    ("Leg Press",            MuscleGroup.LEGS,       WeightType.RAW_WEIGHT,  ExerciseWorkoutType.LIFTING),
    ("Leg Curl",             MuscleGroup.LEGS,       WeightType.RAW_WEIGHT,  ExerciseWorkoutType.LIFTING),
    ("Leg Extension",        MuscleGroup.LEGS,       WeightType.RAW_WEIGHT,  ExerciseWorkoutType.LIFTING),
    ("Calf Raise",           MuscleGroup.LEGS,       WeightType.RAW_WEIGHT,  ExerciseWorkoutType.LIFTING),
    ("Bulgarian Split Squat",MuscleGroup.LEGS,       WeightType.DUMBBELLS,   ExerciseWorkoutType.LIFTING),
    ("Lunges",               MuscleGroup.LEGS,       WeightType.DUMBBELLS,   ExerciseWorkoutType.LIFTING),
    ("Plank",                MuscleGroup.CORE,       WeightType.TIME_BASED,  ExerciseWorkoutType.MOBILITY),
    ("Cable Crunch",         MuscleGroup.CORE,       WeightType.RAW_WEIGHT,  ExerciseWorkoutType.LIFTING),
    ("Treadmill Run",        MuscleGroup.CARDIO,     WeightType.DISTANCE,    ExerciseWorkoutType.RUNNING),
    ("Outdoor Run",          MuscleGroup.CARDIO,     WeightType.DISTANCE,    ExerciseWorkoutType.RUNNING),
    ("Rowing Machine",       MuscleGroup.CARDIO,     WeightType.DISTANCE,    ExerciseWorkoutType.RUNNING),
    ("Box Jump",             MuscleGroup.PLYOMETRIC, WeightType.BODYWEIGHT,  ExerciseWorkoutType.PLYOMETRIC),
    ("Burpee",               MuscleGroup.PLYOMETRIC, WeightType.BODYWEIGHT,  ExerciseWorkoutType.PLYOMETRIC),
    ("Jump Rope",            MuscleGroup.PLYOMETRIC, WeightType.TIME_BASED,  ExerciseWorkoutType.PLYOMETRIC),
    ("Hundred",              MuscleGroup.PILATES,    WeightType.BODYWEIGHT,  ExerciseWorkoutType.PILATES),
    ("Roll Up",              MuscleGroup.PILATES,    WeightType.BODYWEIGHT,  ExerciseWorkoutType.PILATES),
    ("Hip Flexor Stretch",   MuscleGroup.MOBILITY,   WeightType.TIME_BASED,  ExerciseWorkoutType.MOBILITY),
]

TEMPLATES = [
    ("Push Day", "lifting", ["Bench Press", "Incline DB Press", "Overhead Press", "Tricep Pushdown"]),
    ("Pull Day", "lifting", ["Deadlift", "Barbell Row", "Lat Pulldown", "Barbell Curl"]),
    ("Leg Day", "lifting", ["Squat", "Romanian Deadlift", "Leg Press", "Calf Raise"]),
    ("Full Body Strength", "lifting", ["Squat", "Bench Press", "Barbell Row", "Plank"]),
    ("5K Run", "running", ["Outdoor Run"]),
]


def seed_user_data(db: Session, user_id: str) -> None:
    """Create default data for a specific user if they have no workout types yet."""
    existing = db.query(WorkoutType.id).filter(WorkoutType.user_id == user_id).first()
    if existing is not None:
        return

    now = time.time()
    workout_type_by_slug: dict[str, WorkoutType] = {}

    for wt in WORKOUT_TYPES:
        item = WorkoutType(
            user_id=user_id,
            name=wt["name"],
            slug=wt["slug"],
            icon=wt["icon"],
            color=wt["color"],
            is_system=False,
            last_modified=now,
        )
        db.add(item)
        db.flush()
        workout_type_by_slug[item.slug] = item

    exercise_by_name: dict[str, Exercise] = {}
    for name, muscle_groups, weight_type, workout_type in EXERCISES:
        exercise = Exercise(
            user_id=user_id,
            name=name,
            description=None,
            muscle_groups=int(muscle_groups),
            workout_type=int(workout_type),
            weight_type=int(weight_type),
            warmup_sets=1 if name in {"Bench Press", "Deadlift", "Squat"} else 0,
            accessories=["Belt", "Straps"] if name in {"Deadlift", "Romanian Deadlift"} else [],
            is_system=False,
            last_modified=now,
        )
        db.add(exercise)
        db.flush()
        exercise_by_name[name] = exercise

    for template_name, wt_slug, exercise_names in TEMPLATES:
        template = WorkoutTemplate(
            user_id=user_id,
            name=template_name,
            description=f"Starter {template_name}",
            workout_type_id=workout_type_by_slug[wt_slug].id,
            is_system=False,
            created_at=now,
            last_modified=now,
        )
        db.add(template)
        db.flush()

        for position, exercise_name in enumerate(exercise_names):
            db.add(
                WorkoutTemplateExercise(
                    template_id=template.id,
                    exercise_id=exercise_by_name[exercise_name].id,
                    position=position,
                    default_sets=3,
                    default_reps=10,
                    default_weight=20.0,
                    default_duration_secs=600 if exercise_name in {"Plank", "Jump Rope"} else None,
                    default_distance=5.0 if exercise_name == "Outdoor Run" else None,
                    notes=None,
                    last_modified=now,
                )
            )

    db.commit()
