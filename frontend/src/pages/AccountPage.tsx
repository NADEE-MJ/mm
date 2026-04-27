import { useEffect, useState } from "react";
import { useAuth } from "../contexts/AuthContext";
import api from "../services/api";

export default function AccountPage() {
  const { user, setUser, logout } = useAuth();
  const [unitPreference, setUnitPreference] = useState(user?.unit_preference || "lbs");
  const [barbellWeight, setBarbellWeight] = useState(String(user?.barbell_weight || 45));
  const [backupEnabled, setBackupEnabled] = useState(Boolean(user?.backup_enabled));
  const [backups, setBackups] = useState<any[]>([]);
  const [exportPayload, setExportPayload] = useState<string>("");
  const [status, setStatus] = useState("");

  const loadBackupState = async () => {
    const [settings, list] = await Promise.all([api.getBackupSettings(), api.listBackups()]);
    setBackupEnabled(Boolean(settings?.backup_enabled));
    setBackups(list || []);
  };

  useEffect(() => {
    loadBackupState();
  }, []);

  const saveProfile = async () => {
    const updated = await api.updateMe({
      unit_preference: unitPreference,
      barbell_weight: Number(barbellWeight),
    });
    setUser(updated);
    setStatus("Profile updated");
  };

  const toggleBackup = async () => {
    const next = !backupEnabled;
    await api.updateBackupSettings(next);
    setBackupEnabled(next);
  };

  const runExport = async () => {
    const payload = await api.exportBackup();
    setExportPayload(JSON.stringify(payload, null, 2));
  };

  const runImport = async () => {
    if (!exportPayload.trim()) return;
    const payload = JSON.parse(exportPayload);
    await api.importBackup(payload);
    setStatus("Backup imported");
    await loadBackupState();
  };

  return (
    <div className="space-y-5">
      <h1 className="text-2xl font-semibold">Account</h1>

      <section className="ios-card p-4 space-y-3">
        <h2 className="text-lg font-medium">Profile</h2>
        <p className="text-sm text-[var(--color-ios-label-secondary)]">{user?.email}</p>
        <p className="text-sm text-[var(--color-ios-label-secondary)]">{user?.username}</p>

        <div className="grid gap-3 md:grid-cols-2">
          <select className="ios-input app-select" value={unitPreference} onChange={(event) => setUnitPreference(event.target.value)}>
            <option value="lbs">lbs</option>
            <option value="kg">kg</option>
          </select>
          <input className="ios-input" type="number" value={barbellWeight} onChange={(event) => setBarbellWeight(event.target.value)} placeholder="Barbell weight" />
        </div>
        <button className="btn-ios-primary px-4 py-2" onClick={saveProfile}>Save Profile</button>
      </section>

      <section className="ios-card p-4 space-y-3">
        <h2 className="text-lg font-medium">Backup</h2>
        <button className="btn-ios-primary px-4 py-2" onClick={toggleBackup}>{backupEnabled ? "Disable" : "Enable"} Auto Backup</button>
        <button className="px-4 py-2 rounded border border-[var(--color-ios-separator)]" onClick={runExport}>Export Backup JSON</button>
        <textarea className="ios-input" rows={10} value={exportPayload} onChange={(event) => setExportPayload(event.target.value)} placeholder="Backup JSON" />
        <button className="px-4 py-2 rounded border border-[var(--color-ios-separator)]" onClick={runImport}>Import JSON</button>

        <div>
          <h3 className="font-medium mb-2">Server Backups</h3>
          {backups.length === 0 ? (
            <p className="text-sm text-[var(--color-ios-label-secondary)]">No backups found.</p>
          ) : (
            <div className="space-y-2">
              {backups.map((backup) => (
                <div key={backup.filename} className="rounded border border-[var(--color-ios-separator)] p-2 text-sm">
                  {backup.filename} ({Math.round((backup.size_bytes || 0) / 1024)} KB)
                </div>
              ))}
            </div>
          )}
        </div>
      </section>

      <section className="ios-card p-4">
        <button className="px-4 py-2 rounded border border-[var(--color-ios-separator)] text-ios-red" onClick={logout}>Sign Out</button>
      </section>

      {status && <p className="text-sm text-ios-green">{status}</p>}
    </div>
  );
}
