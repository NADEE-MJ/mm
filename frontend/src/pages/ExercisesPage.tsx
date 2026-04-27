import { useEffect, useState, type FormEvent } from "react";
import api from "../services/api";

// --- Enum definitions (must match backend app/schemas/exercises.py) ---

const MUSCLE_GROUPS = [
  { bit: 1, label: "Chest" },
  { bit: 2, label: "Back" },
  { bit: 4, label: "Shoulders" },
  { bit: 8, label: "Biceps" },
  { bit: 16, label: "Triceps" },
  { bit: 32, label: "Legs" },
  { bit: 64, label: "Core" },
  { bit: 128, label: "Cardio" },
  { bit: 256, label: "Full Body" },
  { bit: 512, label: "Plyometric" },
  { bit: 1024, label: "Pilates" },
  { bit: 2048, label: "Mobility" },
];

const WEIGHT_TYPES = [
  { value: 1, label: "No Weight / Bodyweight" },
  { value: 2, label: "Dumbbells" },
  { value: 3, label: "Plates" },
  { value: 4, label: "Raw Weight (Machine/Cable)" },
  { value: 5, label: "Bands" },
  { value: 6, label: "Time Based" },
  { value: 7, label: "Distance" },
];

const WORKOUT_TYPES = [
  { value: 1, label: "Lifting" },
  { value: 2, label: "Running" },
  { value: 3, label: "Pilates" },
  { value: 4, label: "Mobility/Stretching" },
  { value: 5, label: "Plyometric" },
  { value: 6, label: "Hyrox Training" },
  { value: 7, label: "Custom" },
];

function muscleGroupsLabel(bitmask: number): string {
  if (!bitmask) return "—";
  return MUSCLE_GROUPS.filter((mg) => bitmask & mg.bit)
    .map((mg) => mg.label)
    .join(", ");
}

function weightTypeLabel(value: number): string {
  return WEIGHT_TYPES.find((wt) => wt.value === value)?.label ?? String(value);
}

function workoutTypeLabel(value: number | null): string {
  if (!value) return "—";
  return WORKOUT_TYPES.find((wt) => wt.value === value)?.label ?? String(value);
}

const BLANK_FORM = {
  name: "",
  muscle_groups: 0,
  workout_type: "",
  weight_type: 4,
  all_sets_same_weight: true,
  warmup_sets: "1",
};

export default function ExercisesPage() {
  const [exercises, setExercises] = useState<any[]>([]);
  const [form, setForm] = useState({ ...BLANK_FORM });
  const [accessories, setAccessories] = useState<string[]>([]);
  const [accessoryDraft, setAccessoryDraft] = useState("");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const load = async () => {
    const data = await api.getExercises();
    setExercises(data || []);
  };

  useEffect(() => { load(); }, []);

  const resetForm = () => {
    setForm({ ...BLANK_FORM });
    setAccessories([]);
    setAccessoryDraft("");
    setEditingId(null);
  };

  const startEdit = (exercise: any) => {
    setEditingId(exercise.id);
    setForm({
      name: exercise.name,
      muscle_groups: exercise.muscle_groups ?? 0,
      workout_type: exercise.workout_type ?? "",
      weight_type: exercise.weight_type ?? 4,
      all_sets_same_weight: (exercise.warmup_sets ?? 0) === 0,
      warmup_sets: String(exercise.warmup_sets ?? 1),
    });
    setAccessories(exercise.accessories ?? []);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setIsSubmitting(true);
    try {
      const payload = {
        name: form.name,
        muscle_groups: form.muscle_groups,
        workout_type: form.workout_type ? Number(form.workout_type) : null,
        weight_type: Number(form.weight_type),
        warmup_sets: form.all_sets_same_weight ? 0 : Math.max(0, Number(form.warmup_sets || 0)),
        accessories,
      };
      if (editingId) {
        await api.updateExercise(editingId, payload);
      } else {
        await api.createExercise(payload);
      }
      resetForm();
      await load();
    } finally {
      setIsSubmitting(false);
    }
  };

  const toggleMuscleGroup = (bit: number) => {
    setForm((prev) => ({ ...prev, muscle_groups: prev.muscle_groups ^ bit }));
  };

  const addAccessory = () => {
    const trimmed = accessoryDraft.trim();
    if (!trimmed) return;
    setAccessories((prev) => {
      if (prev.some((item) => item.toLowerCase() === trimmed.toLowerCase())) return prev;
      return [...prev, trimmed];
    });
    setAccessoryDraft("");
  };

  const removeAccessory = (name: string) => {
    setAccessories((prev) => prev.filter((item) => item !== name));
  };

  return (
    <div className="space-y-5">
      <h1 className="text-2xl font-semibold">Exercises</h1>

      <form className="ios-card p-4 grid gap-4" onSubmit={submit}>
        <div className="flex items-center justify-between">
          <h2 className="font-medium text-sm">{editingId ? "Edit Exercise" : "New Exercise"}</h2>
          {editingId && (
            <button type="button" className="text-xs text-[var(--color-ios-label-secondary)]" onClick={resetForm}>
              Cancel
            </button>
          )}
        </div>

        <div className="grid gap-3 md:grid-cols-2">
          <input
            className="ios-input md:col-span-2"
            placeholder="Exercise name"
            value={form.name}
            onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))}
            required
          />

          {/* Muscle Groups multi-select */}
          <div className="md:col-span-2">
            <p className="text-xs font-medium mb-2">Muscle Groups</p>
            <div className="flex flex-wrap gap-2">
              {MUSCLE_GROUPS.map((mg) => (
                <button
                  key={mg.bit}
                  type="button"
                  onClick={() => toggleMuscleGroup(mg.bit)}
                  className={`px-3 py-1 text-xs rounded-full border transition-colors ${
                    form.muscle_groups & mg.bit
                      ? "bg-ios-blue text-white border-ios-blue"
                      : "border-[var(--color-ios-separator)] text-[var(--color-ios-label-secondary)]"
                  }`}
                >
                  {mg.label}
                </button>
              ))}
            </div>
          </div>

          <select
            className="ios-input app-select"
            value={form.weight_type}
            onChange={(e) => setForm((p) => ({ ...p, weight_type: Number(e.target.value) }))}
          >
            {WEIGHT_TYPES.map((wt) => (
              <option key={wt.value} value={wt.value}>{wt.label}</option>
            ))}
          </select>

          <select
            className="ios-input app-select"
            value={form.workout_type}
            onChange={(e) => setForm((p) => ({ ...p, workout_type: e.target.value }))}
          >
            <option value="">No workout type</option>
            {WORKOUT_TYPES.map((wt) => (
              <option key={wt.value} value={wt.value}>{wt.label}</option>
            ))}
          </select>

          <label className="inline-flex items-center gap-2 text-sm md:col-span-2">
            <input
              type="checkbox"
              checked={form.all_sets_same_weight}
              onChange={(e) => setForm((p) => ({ ...p, all_sets_same_weight: e.target.checked }))}
            />
            All sets use same weight (no warm-ups)
          </label>

          {!form.all_sets_same_weight && (
            <input
              className="ios-input"
              type="number"
              min="0"
              placeholder="Warm-up sets"
              value={form.warmup_sets}
              onChange={(e) => setForm((p) => ({ ...p, warmup_sets: e.target.value }))}
            />
          )}
        </div>

        {/* Accessories */}
        <div className="rounded-lg border border-[var(--color-ios-separator)] p-3 space-y-2">
          <p className="text-sm font-medium">Accessories (optional)</p>
          <div className="flex gap-2">
            <input
              className="ios-input flex-1"
              placeholder="Add accessory (e.g. Belt, Straps)"
              value={accessoryDraft}
              onChange={(e) => setAccessoryDraft(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); addAccessory(); } }}
            />
            <button className="px-3 py-2 rounded border border-[var(--color-ios-separator)]" type="button" onClick={addAccessory}>Add</button>
          </div>
          <div className="flex flex-wrap gap-2">
            {accessories.length === 0 && (
              <span className="text-xs text-[var(--color-ios-label-secondary)]">No accessories configured.</span>
            )}
            {accessories.map((item) => (
              <button
                key={item}
                type="button"
                className="px-2 py-1 text-xs rounded border border-[var(--color-ios-separator)]"
                onClick={() => removeAccessory(item)}
                title="Remove accessory"
              >
                {item} ×
              </button>
            ))}
          </div>
        </div>

        <button
          className="btn-ios-primary px-4 py-2"
          type="submit"
          disabled={isSubmitting}
        >
          {isSubmitting ? "Saving…" : editingId ? "Save Changes" : "Create Exercise"}
        </button>
      </form>

      <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
        {exercises.map((exercise) => (
          <section key={exercise.id} className="ios-card p-4">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <h2 className="font-medium truncate">{exercise.name}</h2>
                <p className="text-sm text-[var(--color-ios-label-secondary)] mt-0.5">
                  {weightTypeLabel(exercise.weight_type)}
                  {exercise.workout_type ? ` · ${workoutTypeLabel(exercise.workout_type)}` : ""}
                </p>
                {!!exercise.muscle_groups && (
                  <p className="text-xs text-[var(--color-ios-label-secondary)] mt-0.5">
                    {muscleGroupsLabel(exercise.muscle_groups)}
                  </p>
                )}
                <p className="text-xs text-[var(--color-ios-label-secondary)] mt-0.5">
                  {exercise.warmup_sets > 0
                    ? `${exercise.warmup_sets} warm-up set${exercise.warmup_sets > 1 ? "s" : ""}`
                    : "No warm-up sets"}
                </p>
                {(exercise.accessories || []).length > 0 && (
                  <div className="mt-2 flex flex-wrap gap-1">
                    {(exercise.accessories || []).map((item: string) => (
                      <span key={item} className="px-2 py-0.5 text-xs rounded border border-[var(--color-ios-separator)]">
                        {item}
                      </span>
                    ))}
                  </div>
                )}
              </div>
              <div className="flex flex-col items-end gap-1 shrink-0">
                <button
                  className="text-xs text-ios-blue hover:underline"
                  onClick={() => startEdit(exercise)}
                >
                  Edit
                </button>
              </div>
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}
