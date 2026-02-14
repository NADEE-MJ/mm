import { useEffect, useRef, useState } from "react";
import { Download, LogOut, Upload } from "lucide-react";

import UserStats from "../components/UserStats";
import api from "../services/api";

export default function AccountPage({ movies, user, logout, onRefresh }) {
  const fileInputRef = useRef(null);

  const [backupEnabled, setBackupEnabled] = useState(false);
  const [settingsLoading, setSettingsLoading] = useState(true);
  const [settingsSaving, setSettingsSaving] = useState(false);
  const [isExporting, setIsExporting] = useState(false);
  const [isImporting, setIsImporting] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    let isMounted = true;

    const loadBackupSettings = async () => {
      try {
        setSettingsLoading(true);
        const response = await api.getBackupSettings();
        if (!isMounted) {
          return;
        }
        setBackupEnabled(Boolean(response?.backup_enabled));
      } catch (err) {
        if (isMounted) {
          setError(err.message || "Failed to load backup settings");
        }
      } finally {
        if (isMounted) {
          setSettingsLoading(false);
        }
      }
    };

    loadBackupSettings();

    return () => {
      isMounted = false;
    };
  }, []);

  const handleToggleBackup = async (event) => {
    const nextValue = event.target.checked;
    const previousValue = backupEnabled;

    setBackupEnabled(nextValue);
    setSettingsSaving(true);
    setMessage("");
    setError("");

    try {
      const updated = await api.updateBackupSettings(nextValue);
      setBackupEnabled(Boolean(updated?.backup_enabled));
      setMessage(`Auto-backup ${updated?.backup_enabled ? "enabled" : "disabled"}.`);
    } catch (err) {
      setBackupEnabled(previousValue);
      setError(err.message || "Failed to update backup settings");
    } finally {
      setSettingsSaving(false);
    }
  };

  const handleExport = async () => {
    setIsExporting(true);
    setMessage("");
    setError("");

    try {
      const blob = await api.exportBackup();
      const datePart = new Date().toISOString().slice(0, 10);
      const filename = `moviemanager-export-${datePart}.json`;
      const url = URL.createObjectURL(blob);

      const link = document.createElement("a");
      link.href = url;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);

      setMessage("Export downloaded.");
    } catch (err) {
      setError(err.message || "Export failed");
    } finally {
      setIsExporting(false);
    }
  };

  const handleImportClick = () => {
    fileInputRef.current?.click();
  };

  const handleImportFile = async (event) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) {
      return;
    }

    setIsImporting(true);
    setMessage("");
    setError("");

    try {
      const raw = await file.text();
      const payload = JSON.parse(raw);
      const result = await api.importBackup(payload);
      if (result?.success === false) {
        const importErrors = Array.isArray(result?.errors) ? result.errors : [];
        throw new Error(importErrors.join(" | ") || "Import failed");
      }

      const imported = result?.imported_counts || {};
      const moviesCount = imported.movies || 0;
      const peopleCount = imported.people || 0;
      const listsCount = imported.lists || 0;
      const toEnrich = Array.isArray(result?.imdb_ids_needing_enrichment)
        ? result.imdb_ids_needing_enrichment
        : [];

      if (toEnrich.length > 0) {
        await Promise.allSettled(toEnrich.map((imdbId) => api.refreshMovie(imdbId)));
      }

      if (onRefresh) {
        await onRefresh();
      }

      setMessage(
        `Import complete: ${moviesCount} movies, ${peopleCount} people, ${listsCount} lists.`
        + (toEnrich.length > 0 ? ` Refreshed ${toEnrich.length} movie metadata records.` : ""),
      );
    } catch (err) {
      setError(err.message || "Import failed");
    } finally {
      setIsImporting(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4 pt-2">
        <div>
          <h2 className="text-ios-title1">Account</h2>
          <p className="text-ios-caption1 text-ios-secondary-label mt-1">{user?.username}</p>
        </div>
      </div>

      <div className="ios-card p-5 space-y-4">
        <div>
          <p className="text-ios-caption1 text-ios-secondary-label uppercase tracking-wider">Username</p>
          <p className="text-ios-headline text-ios-label mt-1">{user?.username}</p>
        </div>
        {user?.email && (
          <div>
            <p className="text-ios-caption1 text-ios-secondary-label uppercase tracking-wider">Email</p>
            <p className="text-ios-body text-ios-label mt-1 break-all">{user.email}</p>
          </div>
        )}
        <button onClick={logout} className="btn-ios-secondary w-full justify-center">
          <LogOut className="w-4 h-4 mr-2" />
          Logout
        </button>
      </div>

      <div className="ios-card p-5 space-y-4">
        <div>
          <p className="text-ios-caption1 text-ios-secondary-label uppercase tracking-wider">Data & Backup</p>
          <p className="text-ios-caption1 text-ios-secondary-label mt-1">
            Saves your library daily on the server (14 days retained)
          </p>
        </div>

        <div className="flex items-center justify-between gap-4 rounded-xl border border-[var(--color-ios-separator)] px-4 py-3">
          <div>
            <p className="text-ios-body text-ios-label">Auto-backup</p>
            <p className="text-ios-caption2 text-ios-secondary-label">
              {settingsLoading ? "Loading..." : backupEnabled ? "Enabled" : "Disabled"}
            </p>
          </div>
          <input
            type="checkbox"
            className="h-5 w-5 accent-[var(--color-ios-blue)]"
            checked={backupEnabled}
            disabled={settingsLoading || settingsSaving}
            onChange={handleToggleBackup}
          />
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <button
            type="button"
            className="btn-ios-secondary justify-center"
            disabled={isExporting || settingsLoading}
            onClick={handleExport}
          >
            <Download className="w-4 h-4 mr-2" />
            {isExporting ? "Exporting..." : "Export Library"}
          </button>

          <button
            type="button"
            className="btn-ios-secondary justify-center"
            disabled={isImporting || settingsLoading}
            onClick={handleImportClick}
          >
            <Upload className="w-4 h-4 mr-2" />
            {isImporting ? "Importing..." : "Import Library"}
          </button>
        </div>

        <input
          ref={fileInputRef}
          type="file"
          accept=".json,application/json"
          className="hidden"
          onChange={handleImportFile}
        />

        {message && <p className="text-ios-caption1 text-ios-green">{message}</p>}
        {error && <p className="text-ios-caption1 text-ios-red">{error}</p>}
      </div>

      <UserStats movies={movies} user={user} showHeader={false} showUserCard={false} />
    </div>
  );
}
