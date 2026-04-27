import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import api from "../services/api";

export default function HistoryPage() {
  const [sessions, setSessions] = useState<any[]>([]);
  const [dateFilter, setDateFilter] = useState("");
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  const load = async () => {
    setLoading(true);
    try {
      const data = await api.getSessions(dateFilter ? { date: dateFilter } : {});
      setSessions(data || []);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  return (
    <div className="space-y-5">
      <h1 className="text-2xl font-semibold">History</h1>
      <div className="ios-card p-4 flex items-center gap-3">
        <input type="date" className="ios-input max-w-xs" value={dateFilter} onChange={(event) => setDateFilter(event.target.value)} />
        <button className="btn-ios-primary px-4 py-2" onClick={load}>Apply</button>
      </div>

      {loading ? (
        <p>Loading sessions...</p>
      ) : sessions.length === 0 ? (
        <p className="text-[var(--color-ios-label-secondary)]">No sessions found.</p>
      ) : (
        <div className="space-y-3">
          {sessions.map((session) => (
            <section key={session.id} className="ios-card p-4">
              <div className="flex items-center justify-between">
                <h2 className="font-medium">{new Date(session.date * 1000).toLocaleString()}</h2>
                <span className="text-sm text-[var(--color-ios-label-secondary)]">{session.status}</span>
              </div>
              <p className="text-sm text-[var(--color-ios-label-secondary)] mt-2">{session.exercises?.length || 0} exercises</p>
              <div className="mt-3">
                <button className="btn-ios-primary px-3 py-2 text-sm" onClick={() => navigate(`/log/${session.id}`)}>
                  View / Edit Session
                </button>
              </div>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}
