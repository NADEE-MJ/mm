import { apiClient, handleApiError } from "./client";
import { User, AuthResponse } from "../../types";

/** Shape returned by the backend auth endpoints */
interface BackendAuthResponse {
  access_token: string;
  token_type: string;
  user: User;
}

/**
 * Register a new user
 */
export async function register(
  email: string,
  username: string,
  password: string,
): Promise<AuthResponse> {
  try {
    const response = await apiClient.post<BackendAuthResponse>("/auth/register", {
      email,
      username,
      password,
    });

    return {
      token: response.data.access_token,
      user: response.data.user,
    };
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Login user
 */
export async function login(email: string, password: string): Promise<AuthResponse> {
  try {
    const response = await apiClient.post<BackendAuthResponse>("/auth/login", {
      email,
      password,
    });

    return {
      token: response.data.access_token,
      user: response.data.user,
    };
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Verify current token and get user profile
 */
export async function verifyToken(): Promise<User> {
  try {
    const response = await apiClient.get<User>("/auth/me");
    return response.data;
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Logout (client-side only, no server endpoint needed)
 */
export async function logout(): Promise<void> {
  // No server-side logout needed for JWT
  // Just clear client-side data
  return Promise.resolve();
}
