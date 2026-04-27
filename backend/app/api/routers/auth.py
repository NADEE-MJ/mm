"""Authentication endpoints."""

from datetime import timedelta

from auth import (
    ADMIN_TOKEN,
    ACCESS_TOKEN_EXPIRE_DAYS,
    AdminLoginRequest,
    LoginResponse,
    Token,
    UserCreate,
    UserLogin,
    UserResponse,
    authenticate_user,
    create_admin_access_token,
    create_access_token,
    create_user,
    get_required_admin,
    get_required_user,
    get_user_by_email,
    get_user_by_username,
    verify_admin_bootstrap_token,
)
from database import get_db
from fastapi import APIRouter, Depends, HTTPException, status
from models import User
from sqlalchemy.orm import Session

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=LoginResponse)
async def login(user: UserLogin, db: Session = Depends(get_db)) -> dict:
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
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": db_user,
    }


@router.post("/admin/login", response_model=Token)
async def admin_login(payload: AdminLoginRequest) -> dict:
    """Authenticate with bootstrap admin token and mint a short-lived admin JWT."""
    if not ADMIN_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="ADMIN_TOKEN is not configured",
        )

    if not verify_admin_bootstrap_token(payload.token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    admin_access_token = create_admin_access_token()
    return {"access_token": admin_access_token, "token_type": "bearer"}


@router.post(
    "/admin/users",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
async def admin_create_user(
    user: UserCreate,
    _admin: dict = Depends(get_required_admin),
    db: Session = Depends(get_db),
) -> User:
    """Create a new user account (admin-only)."""
    if get_user_by_email(db, user.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    if get_user_by_username(db, user.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already taken",
        )
    return create_user(db, user)


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(user: User = Depends(get_required_user)) -> User:
    """Return the authenticated user profile."""
    return user
