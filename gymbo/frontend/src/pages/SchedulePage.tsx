import { useEffect, useMemo, useState } from "react";
import api from "../services/api";

const DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

export default function SchedulePage() {
  const [schedule, setSchedule] = useState<any[]>([]);
  const [templates, setTemplates] = useState<any[]>([]);
  const [day, setDay] = useState(0);
  const [templateId, setTemplateId] = useState("");

  const load = async () => {
    const [scheduleData, templateData] = await Promise.all([api.getSchedule(), api.getTemplates()]);
    setSchedule(scheduleData || []);
    setTemplates(templateData || []);
  };

  useEffect(() => {
    load();
  }, []);

  const grouped = useMemo(() => {
    const map: Record<number, any[]> = {};
    for (let index = 0; index < 7; index += 1) map[index] = [];
    for (const entry of schedule) map[entry.day_of_week].push(entry);
    return map;
  }, [schedule]);

  const addEntry = () => {
    if (!templateId) return;
    setSchedule((prev) => [...prev, { id: `local-${Math.random()}`, day_of_week: day, template_id: templateId }]);
  };

  const removeEntry = (id: string) => {
    setSchedule((prev) => prev.filter((entry) => entry.id !== id));
  };

  const save = async () => {
    const entries = schedule.map((entry) => ({ day_of_week: entry.day_of_week, template_id: entry.template_id }));
    const result = await api.updateSchedule(entries);
    setSchedule(result || []);
  };

  return (
    <div className="space-y-5">
      <h1 className="text-2xl font-semibold">Schedule</h1>

      <section className="ios-card p-4 grid gap-3 md:grid-cols-[180px_1fr_auto]">
        <select className="ios-input app-select" value={day} onChange={(event) => setDay(Number(event.target.value))}>
          {DAYS.map((dayName, index) => <option key={dayName} value={index}>{dayName}</option>)}
        </select>
        <select className="ios-input app-select" value={templateId} onChange={(event) => setTemplateId(event.target.value)}>
          <option value="">Select template</option>
          {templates.map((template) => <option key={template.id} value={template.id}>{template.name}</option>)}
        </select>
        <button className="btn-ios-primary px-4 py-2" onClick={addEntry}>Add</button>
      </section>

      <div className="grid gap-3 md:grid-cols-2">
        {DAYS.map((dayName, index) => (
          <section key={dayName} className="ios-card p-4">
            <h2 className="font-medium mb-2">{dayName}</h2>
            {grouped[index]?.length ? (
              <div className="space-y-2">
                {grouped[index].map((entry) => {
                  const template = templates.find((item) => item.id === entry.template_id);
                  return (
                    <div key={entry.id} className="rounded border border-[var(--color-ios-separator)] p-2 flex items-center justify-between">
                      <span>{template?.name || entry.template_id || "Unknown template"}</span>
                      <button className="text-xs text-ios-red" onClick={() => removeEntry(entry.id)}>Remove</button>
                    </div>
                  );
                })}
              </div>
            ) : (
              <p className="text-sm text-[var(--color-ios-label-secondary)]">No templates assigned.</p>
            )}
          </section>
        ))}
      </div>

      <button className="btn-ios-primary px-4 py-2" onClick={save}>Save Schedule</button>
    </div>
  );
}
