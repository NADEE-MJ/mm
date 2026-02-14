/**
 * Backend API client
 * Handles all HTTP requests to the FastAPI backend
 */

import { getAuthToken } from "../contexts/AuthContext";

// Use VITE_API_URL if set (development), otherwise use empty string for same-origin requests (production)
const API_BASE_URL = import.meta.env.VITE_API_URL || "";

class APIClient {
  constructor() {
    this.baseURL = API_BASE_URL;
  }

  getAuthHeaders() {
    const token = getAuthToken();
    if (token) {
      return { Authorization: `Bearer ${token}` };
    }
    return {};
  }

  async parseJsonResponse(response) {
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

  handleUnauthorized(response) {
    if (response.status !== 401) {
      return;
    }
    window.dispatchEvent(new CustomEvent("auth-error", { detail: { status: 401 } }));
    throw new Error("Authentication required");
  }

  handleNetworkError(error) {
    if (error?.name === "TypeError" && error?.message === "Failed to fetch") {
      throw new Error("Network error - backend may be offline");
    }
    throw error;
  }

  async request(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`;
    const config = {
      headers: {
        "Content-Type": "application/json",
        ...this.getAuthHeaders(),
        ...options.headers,
      },
      ...options,
    };

    try {
      const response = await fetch(url, config);

      // Handle 204 No Content
      if (response.status === 204) {
        return null;
      }

      this.handleUnauthorized(response);
      const data = await this.parseJsonResponse(response);

      if (!response.ok) {
        throw new Error(data?.detail || `HTTP error! status: ${response.status}`);
      }

      return data;
    } catch (error) {
      this.handleNetworkError(error);
    }
  }

  // Movie endpoints
  async getMovie(imdbId) {
    return this.request(`/api/movies/${imdbId}`);
  }

  async getAllMovies() {
    return this.request("/api/movies");
  }

  // Recommendation endpoints
  async addRecommendation(
    imdbId,
    person,
    dateRecommended = null,
    voteType = "upvote",
    tmdbData = null,
    omdbData = null,
    mediaType = "movie",
  ) {
    return this.request(`/api/movies/${imdbId}/recommendations`, {
      method: "POST",
      body: JSON.stringify({
        person,
        date_recommended: dateRecommended || Date.now() / 1000,
        vote_type: voteType,
        tmdb_data: tmdbData,
        omdb_data: omdbData,
        media_type: mediaType,
      }),
    });
  }

  async removeRecommendation(imdbId, person) {
    return this.request(`/api/movies/${imdbId}/recommendations/${encodeURIComponent(person)}`, {
      method: "DELETE",
    });
  }

  // Watch history endpoints
  async markWatched(imdbId, dateWatched, myRating) {
    return this.request(`/api/movies/${imdbId}/watch`, {
      method: "PUT",
      body: JSON.stringify({
        date_watched: dateWatched / 1000,
        my_rating: myRating,
      }),
    });
  }

  // Status endpoints
  async updateMovieStatus(imdbId, status) {
    return this.request(`/api/movies/${imdbId}/status`, {
      method: "PUT",
      body: JSON.stringify({ status }),
    });
  }

  async refreshMovie(imdbId) {
    return this.request(`/api/movies/${imdbId}/refresh`, {
      method: "POST",
    });
  }

  // Sync endpoints
  async syncGetChanges(since) {
    return this.request(`/api/sync?since=${since}`);
  }

  async syncProcessAction(action, data, timestamp) {
    return this.request("/api/sync", {
      method: "POST",
      body: JSON.stringify({
        action,
        data,
        timestamp,
      }),
    });
  }

  // People endpoints
  async getPeople() {
    return this.request("/api/people");
  }

  async addPerson(
    name,
    { isTrusted = false, color = "#0a84ff", emoji = null } = {},
  ) {
    return this.request("/api/people", {
      method: "POST",
      body: JSON.stringify({
        name,
        is_trusted: isTrusted,
        color,
        emoji,
      }),
    });
  }

  async updatePerson(name, updates) {
    return this.request(`/api/people/${encodeURIComponent(name)}`, {
      method: "PUT",
      body: JSON.stringify(updates),
    });
  }

  // Health check
  async healthCheck() {
    return this.request("/api/health");
  }

  // External API proxy endpoints (TMDB, OMDB)
  async searchTMDB(query) {
    return this.request(`/api/external/tmdb/search?q=${encodeURIComponent(query)}`);
  }

  async getTMDBMovieDetails(tmdbId) {
    return this.request(`/api/external/tmdb/movie/${tmdbId}`);
  }

  async getTMDBTVDetails(tmdbId) {
    return this.request(`/api/external/tmdb/tv/${tmdbId}`);
  }

  async getOMDBMovie(imdbId) {
    return this.request(`/api/external/omdb/movie/${imdbId}`);
  }

  async getExternalCacheInfo() {
    return this.request("/api/external/cache/info");
  }

  // Backup endpoints
  async exportBackup() {
    const url = `${this.baseURL}/api/backup/export`;

    try {
      const response = await fetch(url, {
        method: "GET",
        headers: {
          ...this.getAuthHeaders(),
        },
      });

      this.handleUnauthorized(response);

      if (!response.ok) {
        let detail = `HTTP error! status: ${response.status}`;
        const data = await this.parseJsonResponse(response);
        detail = data?.detail || detail;
        throw new Error(detail);
      }

      return response.blob();
    } catch (error) {
      this.handleNetworkError(error);
    }
  }

  async importBackup(data) {
    return this.request("/api/backup/import", {
      method: "POST",
      body: JSON.stringify(data),
    });
  }

  async getBackupSettings() {
    return this.request("/api/backup/settings");
  }

  async updateBackupSettings(enabled) {
    return this.request("/api/backup/settings", {
      method: "PUT",
      body: JSON.stringify({ backup_enabled: enabled }),
    });
  }

  async listBackups() {
    return this.request("/api/backup/list");
  }
}

export const api = new APIClient();
export default api;
