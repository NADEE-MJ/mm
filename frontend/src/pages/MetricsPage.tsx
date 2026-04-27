import { useEffect, useMemo, useState } from "react";
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import api from "../services/api";

export default function MetricsPage() {
  const [summary, setSummary] = useState<any>(null);
  const [frequency, setFrequency] = useState<any[]>([]);
  const [prs, setPrs] = useState<any[]>([]);
  const [exercises, setExercises] = useState<any[]>([]);
  const [selectedExercise, setSelectedExercise] = useState("");
  const [exerciseProgress, setExerciseProgress] = useState<any[]>([]);

  useEffect(() => {
    const load = async () => {
      const [summaryData, frequencyData, prsData, exerciseData] = await Promise.all([
        api.getMetricsSummary(),
        api.getFrequency(),
        api.getPRs(),
        api.getExercises(),
      ]);
      setSummary(summaryData);
      setFrequency(frequencyData || []);
      setPrs(prsData || []);
      setExercises(exerciseData || []);
      if ((exerciseData || []).length > 0) {
        const firstId = exerciseData[0].id;
        setSelectedExercise(firstId);
      }
    };
    load();
  }, []);

  useEffect(() => {
    if (!selectedExercise) return;
    const loadProgress = async () => {
      const data = await api.getExerciseProgress(selectedExercise);
      setExerciseProgress(data || []);
    };
    loadProgress();
  }, [selectedExercise]);

  const frequencyByWeek = useMemo(() => {
    const grouped: Record<string, number> = {};
    for (const point of frequency) {
      grouped[point.week_start] = (grouped[point.week_start] || 0) + point.sessions;
    }
    return Object.entries(grouped).map(([week_start, sessions]) => ({ week_start, sessions }));
  }, [frequency]);

  return (
    <div className="space-y-5">
      <h1 className="text-2xl font-semibold">Metrics</h1>

      {summary && (
        <section className="grid gap-3 md:grid-cols-4">
          <div className="ios-card p-4"><p className="text-sm text-[var(--color-ios-label-secondary)]">Current Streak</p><p className="text-2xl font-semibold">{summary.current_streak}</p></div>
          <div className="ios-card p-4"><p className="text-sm text-[var(--color-ios-label-secondary)]">Total Sessions</p><p className="text-2xl font-semibold">{summary.total_sessions}</p></div>
          <div className="ios-card p-4"><p className="text-sm text-[var(--color-ios-label-secondary)]">Total Volume</p><p className="text-2xl font-semibold">{summary.total_volume}</p></div>
          <div className="ios-card p-4"><p className="text-sm text-[var(--color-ios-label-secondary)]">PR Count</p><p className="text-2xl font-semibold">{summary.pr_count}</p></div>
        </section>
      )}

      <section className="ios-card p-4">
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-lg font-medium">Exercise Progress</h2>
          <select className="ios-input app-select max-w-xs" value={selectedExercise} onChange={(event) => setSelectedExercise(event.target.value)}>
            {exercises.map((exercise) => <option key={exercise.id} value={exercise.id}>{exercise.name}</option>)}
          </select>
        </div>
        <div style={{ height: 280 }}>
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={exerciseProgress}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="timestamp" tickFormatter={(value) => new Date(value * 1000).toLocaleDateString()} />
              <YAxis />
              <Tooltip labelFormatter={(value) => new Date(Number(value) * 1000).toLocaleString()} />
              <Legend />
              <Line type="monotone" dataKey="weight" stroke="#0a84ff" name="Weight" />
              <Line type="monotone" dataKey="estimated_1rm" stroke="#30d158" name="Estimated 1RM" />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </section>

      <section className="ios-card p-4">
        <h2 className="text-lg font-medium mb-3">Weekly Frequency</h2>
        <div style={{ height: 260 }}>
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={frequencyByWeek}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="week_start" />
              <YAxis />
              <Tooltip />
              <Bar dataKey="sessions" fill="#bf5af2" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </section>

      <section className="ios-card p-4">
        <h2 className="text-lg font-medium mb-3">Workout Type Frequency</h2>
        <div style={{ height: 260 }}>
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={frequency}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="week_start" />
              <YAxis />
              <Tooltip />
              <Area type="monotone" dataKey="sessions" stroke="#ff9f0a" fill="#ff9f0a55" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </section>

      <section className="ios-card p-4">
        <h2 className="text-lg font-medium mb-3">PRs</h2>
        {prs.length === 0 ? (
          <p className="text-[var(--color-ios-label-secondary)]">No PR records yet.</p>
        ) : (
          <div className="space-y-2">
            {prs.map((item) => (
              <div key={`${item.exercise_id}-${item.reps}-${item.weight}`} className="rounded border border-[var(--color-ios-separator)] p-2 flex items-center justify-between">
                <span>{item.exercise_name} ({item.reps || "-"} reps)</span>
                <span className="font-medium">{item.weight}</span>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
