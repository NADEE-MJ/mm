from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class WeeklyScheduleEntryIn(BaseModel):
    day_of_week: int
    template_id: str | None


class WeeklyScheduleEntryOut(BaseModel):
    id: str
    user_id: str
    day_of_week: int
    template_id: str | None
    last_modified: float

    model_config = ConfigDict(from_attributes=True)


class TodayTemplateStatus(BaseModel):
    schedule_id: str
    template_id: str | None
    template_name: str | None
    completed_today: bool


class ReplaceScheduleRequest(BaseModel):
    entries: list[WeeklyScheduleEntryIn]
