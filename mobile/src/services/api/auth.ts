import { apiClient, handleApiError } from './client';
import { User, AuthResponse, ApiResponse } from '../../types';

/**
 * Register a new user
 */
export async function register(
  email: string,
  username: string,
  password: string
): Promise<AuthResponse> {
  try {
    const response = await apiClient.post<ApiResponse<AuthResponse>>('/auth/register', {
      email,
      username,
      password,
    });

    return response.data.data;
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Login user
 */
export async function login(
  username: string,
  password: string
): Promise<AuthResponse> {
  try {
    const response = await apiClient.post<ApiResponse<AuthResponse>>('/auth/login', {
      username,
      password,
    });

    return response.data.data;
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Verify current token and get user profile
 */
export async function verifyToken(): Promise<User> {
  try {
    const response = await apiClient.get<ApiResponse<User>>('/auth/me');
    return response.data.data;
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
