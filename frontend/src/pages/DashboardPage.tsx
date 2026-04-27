import { useEffect, useState } from "react";
import api from "../services/api";

export default function DashboardPage() {
  const [today, setToday] = useState<any[]>([]);
  const [recent, setRecent] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const [todayData, recentData] = await Promise.all([
          api.getTodaySchedule(),
          api.getSessions({ status: "completed" }),
        ]);
        setToday(todayData || []);
        setRecent((recentData || []).slice(0, 7));
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  if (loading) return <div>Loading dashboard...</div>;

  return (
    <div className="space-y-5">
      <h1 className="text-2xl font-semibold">Dashboard</h1>
      <section className="ios-card p-4">
        <h2 className="text-lg font-medium mb-3">Today's Schedule</h2>
        {today.length === 0 ? (
          <p className="text-[var(--color-ios-label-secondary)]">No templates scheduled today.</p>
        ) : (
          <div className="space-y-2">
            {today.map((item) => (
              <div key={item.schedule_id} className="rounded-lg border border-[var(--color-ios-separator)] p-3 flex items-center justify-between">
                <div>
                  <p className="font-medium">{item.template_name || "Freeform"}</p>
                  <p className="text-sm text-[var(--color-ios-label-secondary)]">Template ID: {item.template_id || "-"}</p>
                </div>
                <span className={`text-sm ${item.completed_today ? "text-ios-green" : "text-ios-yellow"}`}>
                  {item.completed_today ? "Completed" : "Pending"}
                </span>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="ios-card p-4">
        <h2 className="text-lg font-medium mb-3">Recent Sessions</h2>
        {recent.length === 0 ? (
          <p className="text-[var(--color-ios-label-secondary)]">No completed sessions yet.</p>
        ) : (
          <div className="space-y-2">
            {recent.map((session) => (
              <div key={session.id} className="rounded-lg border border-[var(--color-ios-separator)] p-3">
                <div className="flex items-center justify-between">
                  <span className="font-medium">{new Date(session.date * 1000).toLocaleString()}</span>
                  <span className="text-sm text-[var(--color-ios-label-secondary)]">{session.status}</span>
                </div>
                <p className="text-sm text-[var(--color-ios-label-secondary)] mt-1">{session.exercises?.length || 0} exercises</p>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
