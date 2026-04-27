from __future__ import annotations

import time
from datetime import datetime, timedelta, timezone

from app.schemas.sessions import (
    CompleteSessionRequest,
    CompleteSessionResponse,
    SessionExerciseCreate,
    SessionExerciseOut,
    SessionExerciseUpdate,
    SessionSetCreate,
    SessionSetOut,
    SessionSetUpdate,
    WorkoutSessionCreate,
    WorkoutSessionOut,
    WorkoutSessionUpdate,
)
from app.services.notifications import notify_session_completed, notify_session_updated
from app.services.sessions import detect_prs_for_session_completion, populate_session_from_template
from auth import get_required_user
from database import get_db
from fastapi import APIRouter, Depends, HTTPException, Query
from models import SessionExercise, SessionSet, User, WorkoutSession, WorkoutTemplate
from sqlalchemy.orm import Session, joinedload

router = APIRouter(prefix="/sessions", tags=["sessions"])


def _query_session(db: Session, user_id: str, session_id: str) -> WorkoutSession | None:
    return (
        db.query(WorkoutSession)
        .options(joinedload(WorkoutSession.exercises).joinedload(SessionExercise.sets))
        .filter(WorkoutSession.id == session_id, WorkoutSession.user_id == user_id)
        .first()
    )


def _query_active_session(db: Session, user_id: str, exclude_session_id: str | None = None) -> WorkoutSession | None:
    query = db.query(WorkoutSession).filter(
        WorkoutSession.user_id == user_id,
        WorkoutSession.status == "in_progress",
    )
    if exclude_session_id:
        query = query.filter(WorkoutSession.id != exclude_session_id)
    return query.order_by(WorkoutSession.started_at.desc().nullslast(), WorkoutSession.date.desc()).first()


@router.get("", response_model=list[WorkoutSessionOut])
async def list_sessions(
    since: float | None = Query(default=None),
    date: str | None = Query(default=None),
    template_id: str | None = Query(default=None),
    status: str | None = Query(default=None),
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> list[WorkoutSession]:
    query = db.query(WorkoutSession).options(joinedload(WorkoutSession.exercises).joinedload(SessionExercise.sets)).filter(
        WorkoutSession.user_id == user.id
    )

    if since is not None:
        query = query.filter(WorkoutSession.last_modified >= since)
    if template_id is not None:
        query = query.filter(WorkoutSession.template_id == template_id)
    if status is not None:
        query = query.filter(WorkoutSession.status == status)
    if date:
        day = datetime.strptime(date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        day_end = day + timedelta(days=1)
        query = query.filter(WorkoutSession.date >= day.timestamp(), WorkoutSession.date < day_end.timestamp())

    return query.order_by(WorkoutSession.date.desc()).all()


@router.post("", response_model=WorkoutSessionOut)
async def start_session(
    payload: WorkoutSessionCreate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> WorkoutSession:
    active_session = _query_active_session(db, user.id)
    if active_session:
        raise HTTPException(
            status_code=409,
            detail="You already have an active session. Finish it before starting a new one.",
        )

    now = time.time()
    session = WorkoutSession(
        user_id=user.id,
        template_id=payload.template_id,
        date=payload.date or now,
        started_at=None,
        notes=payload.notes,
        status="in_progress",
        last_modified=now,
    )
    db.add(session)
    db.flush()

    if payload.template_id:
        template = db.query(WorkoutTemplate).filter(WorkoutTemplate.id == payload.template_id).first()
        if not template:
            raise HTTPException(status_code=404, detail="Template not found")
        if template.user_id != user.id:
            raise HTTPException(status_code=403, detail="Not authorized to use template")
        populate_session_from_template(db, user.id, template, session)

    db.commit()
    await notify_session_updated(user.id, session.id)
    return _query_session(db, user.id, session.id)


@router.get("/{session_id}", response_model=WorkoutSessionOut)
async def get_session(
    session_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> WorkoutSession:
    session = _query_session(db, user.id, session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return session


@router.put("/{session_id}", response_model=WorkoutSessionOut)
async def update_session(
    session_id: str,
    payload: WorkoutSessionUpdate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> WorkoutSession:
    session = db.query(WorkoutSession).filter(WorkoutSession.id == session_id, WorkoutSession.user_id == user.id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if payload.status == "in_progress":
        active_session = _query_active_session(db, user.id, exclude_session_id=session_id)
        if active_session:
            raise HTTPException(
                status_code=409,
                detail="You already have an active session. Finish it before starting a new one.",
            )

    for key, value in payload.model_dump(exclude_unset=True).items():
        if key in {"started_at", "finished_at", "duration_secs"}:
            continue
        setattr(session, key, value)
    session.last_modified = time.time()

    db.add(session)
    db.commit()
    await notify_session_updated(user.id, session.id)
    return _query_session(db, user.id, session.id)


@router.delete("/{session_id}")
async def delete_session(
    session_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict:
    session = db.query(WorkoutSession).filter(WorkoutSession.id == session_id, WorkoutSession.user_id == user.id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    db.delete(session)
    db.commit()
    await notify_session_updated(user.id, session_id)
    return {"success": True}


@router.post("/{session_id}/complete", response_model=CompleteSessionResponse)
async def complete_session(
    session_id: str,
    payload: CompleteSessionRequest,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> CompleteSessionResponse:
    session = _query_session(db, user.id, session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    session.started_at = None
    session.finished_at = None
    session.duration_secs = None
    session.status = "completed"
    session.last_modified = time.time()

    prs = detect_prs_for_session_completion(db, session)

    db.add(session)
    db.commit()
    db.refresh(session)

    await notify_session_completed(user.id, session.id)
    return CompleteSessionResponse(session=_query_session(db, user.id, session.id), prs=prs)


@router.post("/{session_id}/exercises", response_model=SessionExerciseOut)
async def add_session_exercise(
    session_id: str,
    payload: SessionExerciseCreate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> SessionExercise:
    session = db.query(WorkoutSession).filter(WorkoutSession.id == session_id, WorkoutSession.user_id == user.id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    item = SessionExercise(
        session_id=session_id,
        exercise_id=payload.exercise_id,
        position=payload.position,
        notes=payload.notes,
        last_modified=time.time(),
    )
    session.last_modified = time.time()

    db.add(item)
    db.add(session)
    db.commit()
    db.refresh(item)
    await notify_session_updated(user.id, session.id)
    return item


@router.put("/{session_id}/exercises/{session_exercise_id}", response_model=SessionExerciseOut)
async def update_session_exercise(
    session_id: str,
    session_exercise_id: str,
    payload: SessionExerciseUpdate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> SessionExercise:
    session = db.query(WorkoutSession).filter(WorkoutSession.id == session_id, WorkoutSession.user_id == user.id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    item = db.query(SessionExercise).filter(SessionExercise.id == session_exercise_id, SessionExercise.session_id == session_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Session exercise not found")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(item, key, value)
    item.last_modified = time.time()
    session.last_modified = time.time()

    db.add(item)
    db.add(session)
    db.commit()
    db.refresh(item)
    await notify_session_updated(user.id, session.id)
    return item


@router.delete("/{session_id}/exercises/{session_exercise_id}")
async def delete_session_exercise(
    session_id: str,
    session_exercise_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict:
    session = db.query(WorkoutSession).filter(WorkoutSession.id == session_id, WorkoutSession.user_id == user.id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    item = db.query(SessionExercise).filter(SessionExercise.id == session_exercise_id, SessionExercise.session_id == session_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Session exercise not found")

    db.delete(item)
    session.last_modified = time.time()
    db.add(session)
    db.commit()
    await notify_session_updated(user.id, session.id)
    return {"success": True}


@router.post("/{session_id}/exercises/{session_exercise_id}/sets", response_model=SessionSetOut)
async def add_set(
    session_id: str,
    session_exercise_id: str,
    payload: SessionSetCreate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> SessionSet:
    session = db.query(WorkoutSession).filter(WorkoutSession.id == session_id, WorkoutSession.user_id == user.id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    session_exercise = db.query(SessionExercise).filter(SessionExercise.id == session_exercise_id, SessionExercise.session_id == session_id).first()
    if not session_exercise:
        raise HTTPException(status_code=404, detail="Session exercise not found")

    item = SessionSet(
        session_exercise_id=session_exercise_id,
        set_number=payload.set_number,
        reps=payload.reps,
        weight=payload.weight,
        duration_secs=payload.duration_secs,
        distance=payload.distance,
        is_warmup=payload.is_warmup,
        used_accessories=payload.used_accessories,
        band_color=payload.band_color,
        completed=payload.completed,
        last_modified=time.time(),
    )
    session.last_modified = time.time()

    db.add(item)
    db.add(session)
    db.commit()
    db.refresh(item)
    await notify_session_updated(user.id, session.id)
    return item


@router.put("/{session_id}/exercises/{session_exercise_id}/sets/{set_id}", response_model=SessionSetOut)
async def update_set(
    session_id: str,
    session_exercise_id: str,
    set_id: str,
    payload: SessionSetUpdate,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> SessionSet:
    session = db.query(WorkoutSession).filter(WorkoutSession.id == session_id, WorkoutSession.user_id == user.id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    session_exercise = db.query(SessionExercise).filter(SessionExercise.id == session_exercise_id, SessionExercise.session_id == session_id).first()
    if not session_exercise:
        raise HTTPException(status_code=404, detail="Session exercise not found")

    item = db.query(SessionSet).filter(SessionSet.id == set_id, SessionSet.session_exercise_id == session_exercise_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Set not found")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(item, key, value)
    item.last_modified = time.time()
    session.last_modified = time.time()

    db.add(item)
    db.add(session)
    db.commit()
    db.refresh(item)
    await notify_session_updated(user.id, session.id)
    return item


@router.delete("/{session_id}/exercises/{session_exercise_id}/sets/{set_id}")
async def delete_set(
    session_id: str,
    session_exercise_id: str,
    set_id: str,
    user: User = Depends(get_required_user),
    db: Session = Depends(get_db),
) -> dict:
    session = db.query(WorkoutSession).filter(WorkoutSession.id == session_id, WorkoutSession.user_id == user.id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    item = db.query(SessionSet).filter(SessionSet.id == set_id, SessionSet.session_exercise_id == session_exercise_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Set not found")

    db.delete(item)
    session.last_modified = time.time()
    db.add(session)
    db.commit()
    await notify_session_updated(user.id, session.id)
    return {"success": True}
