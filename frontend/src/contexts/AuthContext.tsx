import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";

const AUTH_TOKEN_KEY = "gymbo_auth_token";
const AUTH_USER_KEY = "gymbo_auth_user";

const AuthContext = createContext<any>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<any>(null);
  const [token, setToken] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const savedToken = localStorage.getItem(AUTH_TOKEN_KEY);
    const savedUser = localStorage.getItem(AUTH_USER_KEY);
    if (savedToken && savedUser) {
      setToken(savedToken);
      setUser(JSON.parse(savedUser));
    }
    setIsLoading(false);
  }, []);

  const logout = useCallback(async () => {
    setToken(null);
    setUser(null);
    setError(null);
    localStorage.removeItem(AUTH_TOKEN_KEY);
    localStorage.removeItem(AUTH_USER_KEY);
  }, []);

  const verifyToken = useCallback(async () => {
    if (!token) {
      return;
    }
    try {
      const response = await fetch("/api/auth/me", {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!response.ok) {
        await logout();
      } else {
        const fresh = await response.json();
        setUser(fresh);
        localStorage.setItem(AUTH_USER_KEY, JSON.stringify(fresh));
      }
    } catch {
      // Keep local auth during transient failures.
    }
  }, [logout, token]);

  useEffect(() => {
    verifyToken();
  }, [verifyToken]);

  useEffect(() => {
    const onAuthError = async () => {
      await logout();
    };
    window.addEventListener("auth-error", onAuthError);
    return () => window.removeEventListener("auth-error", onAuthError);
  }, [logout]);

  const login = useCallback(async (email: string, password: string) => {
    setError(null);
    setIsLoading(true);

    try {
      const response = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.detail || "Login failed");
      }

      const data = await response.json();
      const accessToken = data.access_token;

      const userResponse = await fetch("/api/auth/me", {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      if (!userResponse.ok) {
        throw new Error("Failed to get user profile");
      }

      const userData = await userResponse.json();
      setToken(accessToken);
      setUser(userData);
      localStorage.setItem(AUTH_TOKEN_KEY, accessToken);
      localStorage.setItem(AUTH_USER_KEY, JSON.stringify(userData));

      return { success: true };
    } catch (err: any) {
      setError(err.message);
      return { success: false, error: err.message };
    } finally {
      setIsLoading(false);
    }
  }, []);

  const value = {
    user,
    token,
    isLoading,
    error,
    isAuthenticated: Boolean(token && user),
    login,
    logout,
    clearError: () => setError(null),
    setUser,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}

export function getAuthToken() {
  return localStorage.getItem(AUTH_TOKEN_KEY);
}
