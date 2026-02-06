import { create } from 'zustand';
import { User } from '../types';
import * as authApi from '../services/api/auth';
import * as secureStorage from '../services/auth/secure-storage';
import { clearDatabase, initDatabase } from '../services/database/init';
import {
  isBiometricEnabled,
  setBiometricEnabled,
  authenticateWithBiometrics,
} from '../services/auth/biometric';

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;

  // Actions
  login: (username: string, password: string) => Promise<void>;
  register: (email: string, username: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  verifyAuth: () => Promise<boolean>;
  checkBiometric: () => Promise<boolean>;
  enableBiometric: (enabled: boolean) => Promise<void>;
  authenticateBiometric: () => Promise<boolean>;
  clearError: () => void;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  isAuthenticated: false,
  isLoading: false,
  error: null,

  login: async (username: string, password: string) => {
    set({ isLoading: true, error: null });

    try {
      const { token, user } = await authApi.login(username, password);

      // Store token and user
      await secureStorage.storeToken(token);
      await secureStorage.storeUser(user);

      // Initialize database
      await initDatabase();

      // Clear any old data
      await clearDatabase();

      set({
        user,
        isAuthenticated: true,
        isLoading: false,
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Login failed',
        isLoading: false,
      });
      throw error;
    }
  },

  register: async (email: string, username: string, password: string) => {
    set({ isLoading: true, error: null });

    try {
      const { token, user } = await authApi.register(email, username, password);

      // Store token and user
      await secureStorage.storeToken(token);
      await secureStorage.storeUser(user);

      // Initialize database
      await initDatabase();

      set({
        user,
        isAuthenticated: true,
        isLoading: false,
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Registration failed',
        isLoading: false,
      });
      throw error;
    }
  },

  logout: async () => {
    set({ isLoading: true, error: null });

    try {
      // Clear all data
      await secureStorage.clearAuthData();
      await clearDatabase();

      set({
        user: null,
        isAuthenticated: false,
        isLoading: false,
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Logout failed',
        isLoading: false,
      });
    }
  },

  verifyAuth: async () => {
    set({ isLoading: true, error: null });

    try {
      const token = await secureStorage.getToken();

      if (!token) {
        set({ isLoading: false, isAuthenticated: false });
        return false;
      }

      // Verify token with server
      const user = await authApi.verifyToken();

      // Initialize database
      await initDatabase();

      set({
        user,
        isAuthenticated: true,
        isLoading: false,
      });

      return true;
    } catch (error) {
      // Token invalid or expired
      await secureStorage.clearAuthData();
      set({
        user: null,
        isAuthenticated: false,
        isLoading: false,
        error: null, // Don't show error for expired tokens
      });
      return false;
    }
  },

  checkBiometric: async () => {
    try {
      return await isBiometricEnabled();
    } catch (error) {
      console.error('Failed to check biometric:', error);
      return false;
    }
  },

  enableBiometric: async (enabled: boolean) => {
    try {
      await setBiometricEnabled(enabled);
    } catch (error) {
      console.error('Failed to enable biometric:', error);
      throw error;
    }
  },

  authenticateBiometric: async () => {
    try {
      const success = await authenticateWithBiometrics();
      return success;
    } catch (error) {
      console.error('Biometric authentication failed:', error);
      return false;
    }
  },

  clearError: () => set({ error: null }),
}));
