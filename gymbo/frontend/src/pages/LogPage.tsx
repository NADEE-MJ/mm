import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import api from "../services/api";

export default function LogPage() {
  const [templates, setTemplates] = useState<any[]>([]);
  const [activeSession, setActiveSession] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);
  const [startingId, setStartingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();

  const loadActiveSession = async () => {
    const sessions = await api.getSessions({ status: "in_progress" });
    const current = (sessions || [])[0] || null;
    setActiveSession(current);
    return current;
  };

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const [templateData, inProgressSessions] = await Promise.all([
          api.getTemplates(),
          api.getSessions({ status: "in_progress" }),
        ]);
        setTemplates(templateData || []);
        setActiveSession((inProgressSessions || [])[0] || null);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const start = async (templateId: string | null) => {
    if (activeSession?.id) {
      navigate(`/log/${activeSession.id}`);
      return;
    }

    setStartingId(templateId || "scratch");
    setError(null);
    try {
      const session = await api.startSession({ template_id: templateId });
      navigate(`/log/${session.id}`);
    } catch (err: any) {
      const message = err?.message || "Unable to start session.";
      if (String(message).toLowerCase().includes("active session")) {
        try {
          const current = await loadActiveSession();
          if (current?.id) {
            navigate(`/log/${current.id}`);
            return;
          }
        } catch {
          // Keep original error message below.
        }
      }
      setError(message);
    } finally {
      setStartingId(null);
    }
  };

  return (
    <div className="space-y-5">
      <h1 className="text-2xl font-semibold">Log Workout</h1>
      {activeSession && (
        <section className="ios-card p-4 space-y-3">
          <p className="text-sm text-[var(--color-ios-label-secondary)]">
            You already have an active session. Finish it before starting another one.
          </p>
          <button className="btn-ios-primary px-4 py-2" onClick={() => navigate(`/log/${activeSession.id}`)}>
            Resume Active Session
          </button>
        </section>
      )}

      {error && <p className="text-sm text-red-400">{error}</p>}

      <button
        className="btn-ios-primary px-4 py-2"
        onClick={() => start(null)}
        disabled={Boolean(startingId) || Boolean(activeSession)}
      >
        Start From Scratch
      </button>

      <section className="ios-card p-4">
        <h2 className="text-lg font-medium mb-3">Templates</h2>
        {loading ? (
          <p>Loading templates...</p>
        ) : templates.length === 0 ? (
          <p className="text-[var(--color-ios-label-secondary)]">No templates found.</p>
        ) : (
          <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
            {templates.map((template) => (
              <button
                key={template.id}
                className="rounded-lg border border-[var(--color-ios-separator)] p-3 text-left hover:bg-white/5"
                onClick={() => start(template.id)}
                disabled={Boolean(startingId) || Boolean(activeSession)}
              >
                <div className="flex items-center justify-between">
                  <p className="font-medium">{template.name}</p>
                </div>
                <p className="text-sm text-[var(--color-ios-label-secondary)] mt-1">
                  {template.exercises?.length || 0} exercises
                </p>
              </button>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
