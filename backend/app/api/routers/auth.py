"""Authentication endpoints."""

from datetime import timedelta

from auth import (
    ACCESS_TOKEN_EXPIRE_DAYS,
    Token,
    UserCreate,
    UserLogin,
    UserResponse,
    authenticate_user,
    create_access_token,
    create_user,
    get_required_user,
    get_user_by_email,
    get_user_by_username,
)
from database import get_db
from fastapi import APIRouter, Depends, HTTPException, status
from models import User
from sqlalchemy.orm import Session

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(user: UserCreate, db: Session = Depends(get_db)) -> User:
    """Register a new user account."""
    if get_user_by_email(db, user.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered"
        )
    if get_user_by_username(db, user.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Username already taken"
        )
    return create_user(db, user)


@router.post("/login", response_model=Token)
async def login(user: UserLogin, db: Session = Depends(get_db)) -> Token:
    """Authenticate a user and issue an access token."""
    db_user = authenticate_user(db, user.email, user.password)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(
        data={"sub": db_user.id}, expires_delta=timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
    )
    return Token(access_token=access_token, token_type="bearer")


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(user: User = Depends(get_required_user)) -> User:
    """Return the authenticated user profile."""
    return user
