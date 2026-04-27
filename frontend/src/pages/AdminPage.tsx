import { useMemo, useState, type FormEvent } from "react";
import { AlertCircle, CheckCircle2, KeyRound, LogOut, ShieldCheck, UserPlus } from "lucide-react";

const ADMIN_SESSION_STORAGE_KEY = "gymbo_admin_access_token";

export default function AdminPage() {
  const [bootstrapToken, setBootstrapToken] = useState("");
  const [adminAccessToken, setAdminAccessToken] = useState(
    () => sessionStorage.getItem(ADMIN_SESSION_STORAGE_KEY) || "",
  );

  const [email, setEmail] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const isLoggedIn = useMemo(() => adminAccessToken.length > 0, [adminAccessToken]);

  const handleAdminLogin = async (event: FormEvent) => {
    event.preventDefault();
    setError("");
    setSuccess("");
    setIsSubmitting(true);

    try {
      const response = await fetch("/api/auth/admin/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token: bootstrapToken }),
      });

      const data = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(data.detail || "Admin login failed");
      }

      const token = data.access_token;
      if (!token) {
        throw new Error("Admin login did not return an access token");
      }

      sessionStorage.setItem(ADMIN_SESSION_STORAGE_KEY, token);
      setAdminAccessToken(token);
      setBootstrapToken("");
      setSuccess("Admin session established.");
    } catch (err: any) {
      setError(err.message || "Admin login failed");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleCreateAccount = async (event: FormEvent) => {
    event.preventDefault();
    setError("");
    setSuccess("");
    setIsSubmitting(true);

    try {
      const response = await fetch("/api/auth/admin/users", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${adminAccessToken}`,
        },
        body: JSON.stringify({ email, username, password }),
      });

      const data = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(data.detail || "Failed to create account");
      }

      setSuccess(`Created account for ${data.username || username}.`);
      setEmail("");
      setUsername("");
      setPassword("");
    } catch (err: any) {
      setError(err.message || "Failed to create account");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleLogoutAdmin = () => {
    sessionStorage.removeItem(ADMIN_SESSION_STORAGE_KEY);
    setAdminAccessToken("");
    setError("");
    setSuccess("");
  };

  return (
    <div className="mx-auto w-full max-w-2xl px-4 py-8">
      <div className="ios-card p-6 space-y-6">
        <div>
          <h1 className="text-2xl font-semibold text-ios-label">Admin</h1>
          <p className="text-sm text-ios-secondary-label mt-1">
            Account provisioning for Gymbo. Sign in with your backend ADMIN_TOKEN.
          </p>
        </div>

        {error && (
          <div className="rounded-xl border border-ios-red/25 bg-ios-red/10 p-3 text-ios-red flex items-center gap-2">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span className="text-sm">{error}</span>
          </div>
        )}

        {success && (
          <div className="rounded-xl border border-ios-green/25 bg-ios-green/10 p-3 text-ios-green flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 shrink-0" />
            <span className="text-sm">{success}</span>
          </div>
        )}

        {!isLoggedIn ? (
          <form onSubmit={handleAdminLogin} className="space-y-4">
            <label className="block text-sm text-ios-secondary-label">Admin Bootstrap Token</label>
            <div className="relative">
              <KeyRound className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ios-tertiary-label" />
              <input
                type="password"
                value={bootstrapToken}
                onChange={(event) => setBootstrapToken(event.target.value)}
                required
                className="ios-input input-with-leading-icon"
                placeholder="Paste ADMIN_TOKEN"
              />
            </div>

            <button type="submit" disabled={isSubmitting} className="btn-ios-primary w-full justify-center">
              <ShieldCheck className="w-4 h-4 mr-2" />
              {isSubmitting ? "Signing in..." : "Admin Sign In"}
            </button>
          </form>
        ) : (
          <div className="space-y-5">
            <div className="flex items-center justify-between rounded-xl border border-[var(--color-app-border)] px-4 py-3">
              <div className="text-sm text-ios-secondary-label">Admin session active</div>
              <button type="button" onClick={handleLogoutAdmin} className="px-3 py-2 rounded border border-[var(--color-ios-separator)]">
                <LogOut className="w-4 h-4 mr-2 inline" />
                Sign Out Admin
              </button>
            </div>

            <form onSubmit={handleCreateAccount} className="space-y-4">
              <h2 className="text-lg font-medium">Create User Account</h2>

              <input
                type="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                required
                className="ios-input"
                placeholder="Email"
              />

              <input
                type="text"
                value={username}
                onChange={(event) => setUsername(event.target.value)}
                required
                minLength={2}
                className="ios-input"
                placeholder="Username"
              />

              <input
                type="password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                required
                minLength={8}
                className="ios-input"
                placeholder="Temporary password"
              />

              <button type="submit" disabled={isSubmitting} className="btn-ios-primary w-full justify-center">
                <UserPlus className="w-4 h-4 mr-2" />
                {isSubmitting ? "Creating account..." : "Create Account"}
              </button>
            </form>
          </div>
        )}
      </div>
    </div>
  );
}
