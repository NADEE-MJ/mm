"""Authentication utilities for JWT-based auth."""

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from app.config import config
from database import get_db
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from models import Person, User
from pydantic import BaseModel
from sqlalchemy.orm import Session

# Configuration
SECRET_KEY = config.SECRET_KEY
ADMIN_TOKEN = config.ADMIN_TOKEN
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 30
ADMIN_TOKEN_EXPIRE_HOURS = 12

QUICK_RECOMMENDERS = [
    {
        "key": "youtube",
        "name": "Random YouTube Video",
        "color": "#bf5af2",
        "emoji": "📺",
    },
    {
        "key": "oscar",
        "name": "Oscar Winner/Nominee",
        "color": "#ffd60a",
        "emoji": "🏆",
    },
    {
        "key": "random_person",
        "name": "Random Person",
        "color": "#30d158",
        "emoji": "🤝",
    },
    {
        "key": "google",
        "name": "Google Search",
        "color": "#64d2ff",
        "emoji": "🔎",
    },
]

# HTTP Bearer token
security = HTTPBearer(auto_error=False)


class Token(BaseModel):
    access_token: str
    token_type: str


class TokenData(BaseModel):
    user_id: Optional[str] = None


class UserCreate(BaseModel):
    email: str
    username: str
    password: str


class UserLogin(BaseModel):
    email: str
    password: str


class UserResponse(BaseModel):
    id: str
    email: str
    username: str
    created_at: float
    is_active: bool

    class Config:
        from_attributes = True


class LoginResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse


class AdminLoginRequest(BaseModel):
    token: str


def hash_password(password: str, salt: str | None = None) -> tuple[str, str]:
    """Hash a password with PBKDF2-SHA256."""
    if salt is None:
        salt = secrets.token_hex(32)
    pwd_hash = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), salt.encode("utf-8"), 100000
    )
    return pwd_hash.hex(), salt


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash (format: salt$hash)."""
    try:
        salt, stored_hash = hashed_password.split("$")
        computed_hash, _ = hash_password(plain_password, salt)
        return secrets.compare_digest(computed_hash, stored_hash)
    except ValueError:
        return False


def get_password_hash(password: str) -> str:
    """Hash a password and return salt$hash format."""
    pwd_hash, salt = hash_password(password)
    return f"{salt}${pwd_hash}"


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT access token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def create_admin_access_token(expires_delta: Optional[timedelta] = None) -> str:
    """Create a short-lived admin JWT used for account provisioning routes."""
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(hours=ADMIN_TOKEN_EXPIRE_HOURS)

    payload = {"sub": "admin", "role": "admin", "exp": expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def verify_admin_bootstrap_token(candidate_token: str) -> bool:
    """Constant-time compare for the bootstrap admin token from environment."""
    if not ADMIN_TOKEN:
        return False
    if not candidate_token:
        return False
    return secrets.compare_digest(candidate_token, ADMIN_TOKEN)


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """Get a user by email."""
    return db.query(User).filter(User.email == email).first()


def get_user_by_username(db: Session, username: str) -> Optional[User]:
    """Get a user by username."""
    return db.query(User).filter(User.username == username).first()


def get_user_by_id(db: Session, user_id: str | None) -> Optional[User]:
    """Get a user by ID."""
    return db.query(User).filter(User.id == user_id).first()


def create_user(db: Session, user: UserCreate) -> User:
    """Create a new user."""
    hashed_password = get_password_hash(user.password)
    db_user = User(
        email=user.email,
        username=user.username,
        hashed_password=hashed_password,
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    seed_quick_recommenders(db, db_user.id)
    return db_user


def seed_quick_recommenders(db: Session, user_id: str) -> None:
    for rec in QUICK_RECOMMENDERS:
        db.add(
            Person(
                name=rec["name"],
                user_id=user_id,
                is_trusted=False,
                color=rec["color"],
                emoji=rec["emoji"],
                quick_key=rec["key"],
            )
        )
    db.commit()


def authenticate_user(db: Session, email: str, password: str) -> Optional[User]:
    """Authenticate a user by email and password."""
    user = get_user_by_email(db, email)
    if not user:
        return None
    if not verify_password(password, user.hashed_password):
        return None
    return user


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db),
) -> Optional[User]:
    """Get the current authenticated user from JWT token."""
    if credentials is None:
        return None

    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str | None = payload.get("sub")
        if user_id is None:
            return None
        token_data = TokenData(user_id=user_id)
    except JWTError:
        return None

    user = get_user_by_id(db, user_id=token_data.user_id)
    if user is None:
        return None
    return user


async def get_required_user(
    user: Optional[User] = Depends(get_current_user),
) -> User:
    """Require an authenticated user, raise 401 if not authenticated."""
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


async def get_required_admin(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> dict:
    """Require a valid admin JWT token."""
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    if payload.get("role") != "admin" or payload.get("sub") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin permissions required",
        )

    return payload
