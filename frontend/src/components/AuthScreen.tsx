/**
 * Auth Screen - iOS Style
 * Login and Register
 */

import { useState } from "react";
import { useAuth } from "../contexts/AuthContext";
import { Film, Mail, Lock, User, Loader2, AlertCircle } from "lucide-react";

export default function AuthScreen() {
  const [mode, setMode] = useState("login");
  const [email, setEmail] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [localError, setLocalError] = useState("");

  const { login, register, isLoading, error, clearError } = useAuth();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLocalError("");
    clearError();

    if (mode === "register") {
      if (password !== confirmPassword) {
        setLocalError("Passwords do not match");
        return;
      }
      if (password.length < 6) {
        setLocalError("Password must be at least 6 characters");
        return;
      }
      if (username.length < 3) {
        setLocalError("Username must be at least 3 characters");
        return;
      }
      await register(email, username, password);
    } else {
      await login(email, password);
    }
  };

  const switchMode = () => {
    setMode(mode === "login" ? "register" : "login");
    setLocalError("");
    clearError();
  };

  const displayError = localError || error;

  return (
    <div className="min-h-screen bg-ios-bg flex flex-col ios-fade-in">
      {/* Header */}
      <div className="flex-1 flex flex-col items-center justify-center px-6 py-12 safe-area-top safe-area-bottom">
        {/* Logo */}
        <div className="mb-10 text-center">
          <div className="w-24 h-24 bg-ios-yellow rounded-[28px] flex items-center justify-center mx-auto mb-5 shadow-lg">
            <Film className="w-12 h-12 text-black" />
          </div>
          <h1 className="text-ios-large-title font-bold text-ios-label">Movie Tracker</h1>
          <p className="text-ios-body text-ios-secondary-label mt-2">
            Track recommendations across devices
          </p>
        </div>

        {/* Form Card */}
        <div className="w-full max-w-sm">
          {/* Segmented Control */}
          <div className="ios-segmented-control mb-6">
            <button
              onClick={() => switchMode()}
              className={`ios-segment ${mode === "login" ? "active" : ""}`}
            >
              Sign In
            </button>
            <button
              onClick={() => switchMode()}
              className={`ios-segment ${mode === "register" ? "active" : ""}`}
            >
              Create Account
            </button>
          </div>

          {displayError && (
            <div className="mb-6 p-4 ios-card bg-ios-red/10 border border-ios-red/20 flex items-center gap-3 text-ios-red">
              <AlertCircle className="w-5 h-5 shrink-0" />
              <span className="text-ios-body">{displayError}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Email */}
            <div>
              <label className="text-ios-caption1 font-medium text-ios-secondary-label mb-2 block">
                Email
              </label>
              <div className="relative">
                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-ios-tertiary-label" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  required
                  className="ios-input input-with-leading-icon"
                />
              </div>
            </div>

            {/* Username (register only) */}
            {mode === "register" && (
              <div className="ios-slide-up">
                <label className="text-ios-caption1 font-medium text-ios-secondary-label mb-2 block">
                  Username
                </label>
                <div className="relative">
                  <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-ios-tertiary-label" />
                  <input
                    type="text"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    placeholder="Choose a username"
                    required
                    minLength={3}
                    className="ios-input input-with-leading-icon"
                  />
                </div>
              </div>
            )}

            {/* Password */}
            <div>
              <label className="text-ios-caption1 font-medium text-ios-secondary-label mb-2 block">
                Password
              </label>
              <div className="relative">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-ios-tertiary-label" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  minLength={mode === "register" ? 6 : 1}
                  className="ios-input input-with-leading-icon"
                />
              </div>
            </div>

            {/* Confirm Password (register only) */}
            {mode === "register" && (
              <div className="ios-slide-up">
                <label className="text-ios-caption1 font-medium text-ios-secondary-label mb-2 block">
                  Confirm Password
                </label>
                <div className="relative">
                  <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-ios-tertiary-label" />
                  <input
                    type="password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    placeholder="••••••••"
                    required
                    className="ios-input input-with-leading-icon"
                  />
                </div>
              </div>
            )}

            {/* Submit Button */}
            <button
              type="submit"
              disabled={isLoading}
              className="w-full btn-ios-primary py-4 text-lg font-semibold mt-6"
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-5 h-5 animate-spin mr-2" />
                  {mode === "login" ? "Signing in..." : "Creating account..."}
                </>
              ) : mode === "login" ? (
                "Sign In"
              ) : (
                "Create Account"
              )}
            </button>
          </form>

          {/* Footer */}
          <p className="text-center text-ios-caption1 text-ios-tertiary-label mt-8">
            {mode === "login" ? (
              <>
                Don't have an account?{" "}
                <button onClick={switchMode} className="text-ios-blue font-medium">
                  Create one
                </button>
              </>
            ) : (
              <>
                Already have an account?{" "}
                <button onClick={switchMode} className="text-ios-blue font-medium">
                  Sign in
                </button>
              </>
            )}
          </p>
        </div>
      </div>
    </div>
  );
}
