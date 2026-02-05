"""Security helpers shared across routers."""

from __future__ import annotations

from typing import Optional

from jose import JWTError, jwt
from sqlalchemy.orm import Session

from auth import ALGORITHM, SECRET_KEY, get_user_by_id
from models import User


def get_user_from_ws_token(db: Session, token: Optional[str]) -> Optional[User]:
    """Decode a JWT token coming from the sync WebSocket."""
    if not token:
        return None

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        return None

    user_id: Optional[str] = payload.get("sub")
    if not user_id:
        return None

    return get_user_by_id(db, user_id)
