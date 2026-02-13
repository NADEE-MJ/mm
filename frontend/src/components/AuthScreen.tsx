import { useState } from "react";
import { AlertCircle, Film, Loader2, Lock, Mail } from "lucide-react";

import { useAuth } from "../contexts/AuthContext";

export default function AuthScreen() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const { login, isLoading, error, clearError } = useAuth();

  const handleSubmit = async (e) => {
    e.preventDefault();
    clearError();
    await login(email, password);
  };

  return (
    <div className="min-h-screen bg-ios-bg flex flex-col ios-fade-in">
      <div className="flex-1 flex flex-col items-center justify-center px-6 py-12 safe-area-top safe-area-bottom">
        <div className="mb-10 text-center">
          <div className="w-24 h-24 bg-ios-yellow rounded-[28px] flex items-center justify-center mx-auto mb-5 shadow-lg">
            <Film className="w-12 h-12 text-black" />
          </div>
          <h1 className="text-ios-large-title font-bold text-ios-label">Movie Tracker</h1>
          <p className="text-ios-body text-ios-secondary-label mt-2">
            Sign in with an account created by your admin
          </p>
        </div>

        <div className="w-full max-w-sm">
          {error && (
            <div className="mb-6 p-4 ios-card bg-ios-red/10 border border-ios-red/20 flex items-center gap-3 text-ios-red">
              <AlertCircle className="w-5 h-5 shrink-0" />
              <span className="text-ios-body">{error}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-5">
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
                  className="ios-input input-with-leading-icon"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={isLoading}
              className="w-full btn-ios-primary py-4 text-lg font-semibold mt-6"
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-5 h-5 animate-spin mr-2" />
                  Signing in...
                </>
              ) : (
                "Sign In"
              )}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
