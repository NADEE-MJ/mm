import { useEffect, useState, type FormEvent } from "react";
import api from "../services/api";

export default function TemplatesPage() {
  const [templates, setTemplates] = useState<any[]>([]);
  const [workoutTypes, setWorkoutTypes] = useState<any[]>([]);
  const [exercises, setExercises] = useState<any[]>([]);
  const [newTemplate, setNewTemplate] = useState({ name: "", workout_type_id: "" });
  const [selectedTemplateId, setSelectedTemplateId] = useState("");
  const [selectedExerciseId, setSelectedExerciseId] = useState("");
  const [busyTemplateExerciseId, setBusyTemplateExerciseId] = useState<string | null>(null);

  const load = async () => {
    const [templateData, workoutTypeData, exerciseData] = await Promise.all([
      api.getTemplates(),
      api.getWorkoutTypes(),
      api.getExercises(),
    ]);
    setTemplates(templateData || []);
    setWorkoutTypes(workoutTypeData || []);
    setExercises(exerciseData || []);
  };

  useEffect(() => {
    load();
  }, []);

  const createTemplate = async (event: FormEvent) => {
    event.preventDefault();
    await api.createTemplate({
      name: newTemplate.name,
      workout_type_id: newTemplate.workout_type_id || null,
    });
    setNewTemplate({ name: "", workout_type_id: "" });
    await load();
  };

  const addExercise = async () => {
    if (!selectedTemplateId || !selectedExerciseId) return;
    const template = templates.find((item) => item.id === selectedTemplateId);
    const positions = (template?.exercises || []).map((entry: any) => Number(entry.position || 0));
    const position = (positions.length ? Math.max(...positions) : -1) + 1;
    await api.addTemplateExercise(selectedTemplateId, {
      exercise_id: selectedExerciseId,
      position,
      default_sets: 3,
      default_reps: 10,
    });
    setSelectedExerciseId("");
    await load();
  };

  const removeExercise = async (templateId: string, templateExerciseId: string) => {
    setBusyTemplateExerciseId(templateExerciseId);
    try {
      await api.deleteTemplateExercise(templateId, templateExerciseId);
      await load();
    } finally {
      setBusyTemplateExerciseId(null);
    }
  };

  return (
    <div className="space-y-5">
      <h1 className="text-2xl font-semibold">Templates</h1>

      <form className="ios-card p-4 grid gap-3 md:grid-cols-3" onSubmit={createTemplate}>
        <input className="ios-input" placeholder="Template name" value={newTemplate.name} onChange={(event) => setNewTemplate((prev) => ({ ...prev, name: event.target.value }))} required />
        <select className="ios-input app-select" value={newTemplate.workout_type_id} onChange={(event) => setNewTemplate((prev) => ({ ...prev, workout_type_id: event.target.value }))}>
          <option value="">No workout type</option>
          {workoutTypes.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
        </select>
        <button className="btn-ios-primary px-4 py-2" type="submit">Create Template</button>
      </form>

      <section className="ios-card p-4 grid gap-3 md:grid-cols-[1fr_1fr_auto]">
        <select className="ios-input app-select" value={selectedTemplateId} onChange={(event) => setSelectedTemplateId(event.target.value)}>
          <option value="">Select template</option>
          {templates.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
        </select>
        <select className="ios-input app-select" value={selectedExerciseId} onChange={(event) => setSelectedExerciseId(event.target.value)}>
          <option value="">Select exercise</option>
          {exercises.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
        </select>
        <button className="btn-ios-primary px-4 py-2" type="button" onClick={addExercise}>Add Exercise</button>
      </section>

      <div className="grid gap-3 md:grid-cols-2">
        {templates.map((template) => (
          <section key={template.id} className="ios-card p-4">
            <div className="flex items-center justify-between">
              <h2 className="font-medium">{template.name}</h2>
            </div>
            <p className="text-sm text-[var(--color-ios-label-secondary)] mt-1">{template.exercises?.length || 0} exercises</p>
            <ul className="mt-3 space-y-2">
              {(template.exercises || []).map((entry: any) => {
                const ex = exercises.find((item) => item.id === entry.exercise_id);
                return (
                  <li key={entry.id} className="flex items-center justify-between gap-3 text-sm">
                    <span className="text-[var(--color-ios-label-secondary)]">{ex?.name || entry.exercise_id}</span>
                    <button
                      type="button"
                      className="px-2 py-1 rounded border border-red-500/40 text-red-300 disabled:opacity-50"
                      onClick={() => removeExercise(template.id, entry.id)}
                      disabled={busyTemplateExerciseId === entry.id}
                    >
                      Remove
                    </button>
                  </li>
                );
              })}
            </ul>
          </section>
        ))}
      </div>
    </div>
  );
}
