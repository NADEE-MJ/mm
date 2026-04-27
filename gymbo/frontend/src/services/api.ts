import { getAuthToken } from "../contexts/AuthContext";

const API_BASE_URL = import.meta.env.VITE_API_URL || "";

class APIClient {
  baseURL: string;

  constructor() {
    this.baseURL = API_BASE_URL;
  }

  getAuthHeaders() {
    const token = getAuthToken();
    return token ? { Authorization: `Bearer ${token}` } : {};
  }

  async parseJsonResponse(response: Response) {
    const contentType = response.headers.get("content-type") || "";
    if (!contentType.includes("application/json")) {
      return null;
    }
    try {
      return await response.json();
    } catch {
      return null;
    }
  }

  handleUnauthorized(response: Response) {
    if (response.status !== 401) {
      return;
    }
    window.dispatchEvent(new CustomEvent("auth-error", { detail: { status: 401 } }));
    throw new Error("Authentication required");
  }

  handleNetworkError(error: any) {
    if (error?.name === "TypeError" && error?.message === "Failed to fetch") {
      throw new Error("Network error - backend may be offline");
    }
    throw error;
  }

  async request(endpoint: string, options: RequestInit = {}) {
    const url = `${this.baseURL}${endpoint}`;
    const config: RequestInit = {
      headers: {
        "Content-Type": "application/json",
        ...this.getAuthHeaders(),
        ...((options.headers as object) || {}),
      },
      ...options,
    };

    try {
      const response = await fetch(url, config);

      if (response.status === 204) {
        return null;
      }

      this.handleUnauthorized(response);
      const data = await this.parseJsonResponse(response);

      if (!response.ok) {
        throw new Error(data?.detail || `HTTP ${response.status}`);
      }
      return data;
    } catch (error) {
      this.handleNetworkError(error);
    }
  }

  // Auth
  async getMe() {
    return this.request("/api/auth/me");
  }

  async updateMe(payload: { unit_preference?: string; barbell_weight?: number }) {
    return this.request("/api/auth/me", {
      method: "PUT",
      body: JSON.stringify(payload),
    });
  }

  // Workout Types
  async getWorkoutTypes() {
    return this.request("/api/workout-types");
  }

  async createWorkoutType(payload: any) {
    return this.request("/api/workout-types", {
      method: "POST",
      body: JSON.stringify(payload),
    });
  }

  // Exercises
  async getExercises(params: { muscle_groups?: number; weight_type?: number; workout_type?: number } = {}) {
    const search = new URLSearchParams();
    if (params.muscle_groups != null) search.set("muscle_groups", String(params.muscle_groups));
    if (params.weight_type != null) search.set("weight_type", String(params.weight_type));
    if (params.workout_type != null) search.set("workout_type", String(params.workout_type));
    const qs = search.toString();
    return this.request(`/api/exercises${qs ? `?${qs}` : ""}`);
  }

  async createExercise(payload: any) {
    return this.request("/api/exercises", {
      method: "POST",
      body: JSON.stringify(payload),
    });
  }

  async updateExercise(id: string, payload: any) {
    return this.request(`/api/exercises/${id}`, {
      method: "PUT",
      body: JSON.stringify(payload),
    });
  }

  async deleteExercise(id: string) {
    return this.request(`/api/exercises/${id}`, { method: "DELETE" });
  }

  // Templates
  async getTemplates() {
    return this.request("/api/templates");
  }

  async getTemplate(id: string) {
    return this.request(`/api/templates/${id}`);
  }

  async createTemplate(payload: any) {
    return this.request("/api/templates", {
      method: "POST",
      body: JSON.stringify(payload),
    });
  }

  async updateTemplate(id: string, payload: any) {
    return this.request(`/api/templates/${id}`, {
      method: "PUT",
      body: JSON.stringify(payload),
    });
  }

  async deleteTemplate(id: string) {
    return this.request(`/api/templates/${id}`, { method: "DELETE" });
  }

  async addTemplateExercise(templateId: string, payload: any) {
    return this.request(`/api/templates/${templateId}/exercises`, {
      method: "POST",
      body: JSON.stringify(payload),
    });
  }

  async deleteTemplateExercise(templateId: string, templateExerciseId: string) {
    return this.request(`/api/templates/${templateId}/exercises/${templateExerciseId}`, {
      method: "DELETE",
    });
  }

  async reorderTemplateExercises(templateId: string, exerciseIds: string[]) {
    return this.request(`/api/templates/${templateId}/reorder`, {
      method: "POST",
      body: JSON.stringify({ exercise_ids: exerciseIds }),
    });
  }

  // Schedule
  async getSchedule() {
    return this.request("/api/schedule");
  }

  async updateSchedule(entries: { day_of_week: number; template_id: string | null }[]) {
    return this.request("/api/schedule", {
      method: "PUT",
      body: JSON.stringify({ entries }),
    });
  }

  async getTodaySchedule() {
    return this.request("/api/schedule/today");
  }

  async deleteScheduleEntry(id: string) {
    return this.request(`/api/schedule/${id}`, { method: "DELETE" });
  }

  // Sessions
  async getSessions(params: {
    since?: number;
    date?: string;
    template_id?: string;
    status?: string;
  } = {}) {
    const search = new URLSearchParams();
    if (params.since !== undefined) search.set("since", String(params.since));
    if (params.date) search.set("date", params.date);
    if (params.template_id) search.set("template_id", params.template_id);
    if (params.status) search.set("status", params.status);
    const qs = search.toString();
    return this.request(`/api/sessions${qs ? `?${qs}` : ""}`);
  }

  async startSession(payload: any) {
    return this.request("/api/sessions", {
      method: "POST",
      body: JSON.stringify(payload),
    });
  }

  async getSession(id: string) {
    return this.request(`/api/sessions/${id}`);
  }

  async updateSession(id: string, payload: any) {
    return this.request(`/api/sessions/${id}`, {
      method: "PUT",
      body: JSON.stringify(payload),
    });
  }

  async completeSession(id: string, payload: any = {}) {
    return this.request(`/api/sessions/${id}/complete`, {
      method: "POST",
      body: JSON.stringify(payload),
    });
  }

  async addSessionExercise(sessionId: string, payload: any) {
    return this.request(`/api/sessions/${sessionId}/exercises`, {
      method: "POST",
      body: JSON.stringify(payload),
    });
  }

  async updateSessionExercise(sessionId: string, sessionExerciseId: string, payload: any) {
    return this.request(`/api/sessions/${sessionId}/exercises/${sessionExerciseId}`, {
      method: "PUT",
      body: JSON.stringify(payload),
    });
  }

  async deleteSessionExercise(sessionId: string, sessionExerciseId: string) {
    return this.request(`/api/sessions/${sessionId}/exercises/${sessionExerciseId}`, {
      method: "DELETE",
    });
  }

  async addSet(sessionId: string, sessionExerciseId: string, payload: any) {
    return this.request(`/api/sessions/${sessionId}/exercises/${sessionExerciseId}/sets`, {
      method: "POST",
      body: JSON.stringify(payload),
    });
  }

  async updateSet(sessionId: string, sessionExerciseId: string, setId: string, payload: any) {
    return this.request(`/api/sessions/${sessionId}/exercises/${sessionExerciseId}/sets/${setId}`, {
      method: "PUT",
      body: JSON.stringify(payload),
    });
  }

  async deleteSession(id: string) {
    return this.request(`/api/sessions/${id}`, { method: "DELETE" });
  }

  // Metrics
  async getMetricsSummary() {
    return this.request("/api/metrics/summary");
  }

  async getMetricsCalendar(year: number, month: number) {
    return this.request(`/api/metrics/calendar?year=${year}&month=${month}`);
  }

  async getExerciseProgress(exerciseId: string) {
    return this.request(`/api/metrics/exercise/${exerciseId}`);
  }

  async getFrequency() {
    return this.request("/api/metrics/frequency");
  }

  async getPRs() {
    return this.request("/api/metrics/prs");
  }

  async getStreak() {
    return this.request("/api/metrics/streak");
  }

  // Backup
  async exportBackup() {
    return this.request("/api/backup/export");
  }

  async importBackup(payload: any) {
    return this.request("/api/backup/import", {
      method: "POST",
      body: JSON.stringify(payload),
    });
  }

  async getBackupSettings() {
    return this.request("/api/backup/settings");
  }

  async updateBackupSettings(backup_enabled: boolean) {
    return this.request("/api/backup/settings", {
      method: "PUT",
      body: JSON.stringify({ backup_enabled }),
    });
  }

  async listBackups() {
    return this.request("/api/backup/list");
  }
}

const api = new APIClient();
export default api;
