/**
 * Backend API client
 * Handles all HTTP requests to the FastAPI backend
 */

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

class APIClient {
  constructor() {
    this.baseURL = API_BASE_URL;
  }

  async request(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`;
    const config = {
      headers: {
        'Content-Type': 'application/json',
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

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.detail || `HTTP error! status: ${response.status}`);
      }

      return data;
    } catch (error) {
      if (error.name === 'TypeError' && error.message === 'Failed to fetch') {
        throw new Error('Network error - backend may be offline');
      }
      throw error;
    }
  }

  // Movie endpoints
  async getMovie(imdbId) {
    return this.request(`/api/movies/${imdbId}`);
  }

  async getAllMovies() {
    return this.request('/api/movies');
  }

  // Recommendation endpoints
  async addRecommendation(imdbId, person, dateRecommended = null) {
    return this.request(`/api/movies/${imdbId}/recommendations`, {
      method: 'POST',
      body: JSON.stringify({
        person,
        date_recommended: dateRecommended || Date.now() / 1000,
      }),
    });
  }

  async removeRecommendation(imdbId, person) {
    return this.request(`/api/movies/${imdbId}/recommendations/${encodeURIComponent(person)}`, {
      method: 'DELETE',
    });
  }

  // Watch history endpoints
  async markWatched(imdbId, dateWatched, myRating) {
    return this.request(`/api/movies/${imdbId}/watch`, {
      method: 'PUT',
      body: JSON.stringify({
        date_watched: dateWatched / 1000,
        my_rating: myRating,
      }),
    });
  }

  // Status endpoints
  async updateMovieStatus(imdbId, status) {
    return this.request(`/api/movies/${imdbId}/status`, {
      method: 'PUT',
      body: JSON.stringify({ status }),
    });
  }

  // Sync endpoints
  async syncGetChanges(since) {
    return this.request(`/api/sync?since=${since}`);
  }

  async syncProcessAction(action, data, timestamp) {
    return this.request('/api/sync', {
      method: 'POST',
      body: JSON.stringify({
        action,
        data,
        timestamp,
      }),
    });
  }

  // People endpoints
  async getPeople() {
    return this.request('/api/people');
  }

  async addPerson(name, isTrusted = false) {
    return this.request('/api/people', {
      method: 'POST',
      body: JSON.stringify({
        name,
        is_trusted: isTrusted,
      }),
    });
  }

  async updatePersonTrust(name, isTrusted) {
    return this.request(`/api/people/${encodeURIComponent(name)}`, {
      method: 'PUT',
      body: JSON.stringify({
        is_trusted: isTrusted,
      }),
    });
  }

  // Health check
  async healthCheck() {
    return this.request('/api/health');
  }
}

export const api = new APIClient();
export default api;
