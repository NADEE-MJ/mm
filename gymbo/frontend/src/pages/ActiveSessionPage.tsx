import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import api from "../services/api";

const BAND_COLORS = ["Yellow", "Red", "Blue", "Green", "Black", "Purple", "Orange", "Gray"];
const LB_PLATES = [45, 35, 25, 10, 5, 2.5];
const KG_PLATES = [25, 20, 15, 10, 5, 2.5, 1.25];

// WeightType int enum (matches backend WeightType)
const WT_BODYWEIGHT = 1;
const WT_DUMBBELLS = 2;
const WT_PLATES = 3;
const WT_RAW_WEIGHT = 4;
const WT_BANDS = 5;
const WT_TIME_BASED = 6;
const WT_DISTANCE = 7;

function formatLoad(value: number) {
  const rounded = Math.round(value * 100) / 100;
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(2);
}

function labelForWeightType(weightType: number, unit: string, barbellWeight: number, value: number | null, bandColor: string | null) {
  switch (weightType) {
    case WT_DUMBBELLS:
      return value != null ? `2x ${value} ${unit}` : `Per dumbbell (${unit})`;
    case WT_PLATES: {
      if (value == null) return `/side (${unit})`;
      const total = (value * 2) + barbellWeight;
      return `${formatLoad(value)}/side + ${formatLoad(barbellWeight)} ${unit} bar = ${formatLoad(total)} ${unit}`;
    }
    case WT_RAW_WEIGHT:
      return `${unit} total`;
    case WT_BODYWEIGHT:
      return "Bodyweight";
    case WT_BANDS:
      return bandColor ? `${bandColor} band` : "Select band color";
    case WT_TIME_BASED:
      return "seconds";
    case WT_DISTANCE:
      return unit === "lbs" ? "miles" : "km";
    default:
      return unit;
  }
}

function estimatePlateCounts(perSide: number, sizes: number[]) {
  const counts: Record<number, number> = {};
  let remainder = Math.max(0, Math.round(perSide * 100) / 100);
  for (const size of sizes) {
    const count = Math.floor((remainder + 1e-9) / size);
    counts[size] = count;
    remainder = Math.max(0, Math.round((remainder - (count * size)) * 100) / 100);
  }
  return counts;
}

function toggleAccessory(usedAccessories: string[], accessory: string) {
  if (usedAccessories.includes(accessory)) {
    return usedAccessories.filter((item) => item !== accessory);
  }
  return [...usedAccessories, accessory];
}

type PlateSelectorProps = {
  value: number | null;
  unit: string;
  barbellWeight: number;
  onChange: (next: number | null) => Promise<void>;
};

function PlateSelector({ value, unit, barbellWeight, onChange }: PlateSelectorProps) {
  const perSide = value ?? 0;
  const sizes = unit === "lbs" ? LB_PLATES : KG_PLATES;
  const counts = estimatePlateCounts(perSide, sizes);
  const total = (perSide * 2) + barbellWeight;

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2">
        <input
          className="ios-input"
          type="number"
          step="0.5"
          defaultValue={value ?? ""}
          placeholder="per side"
          onBlur={(event) => onChange(event.target.value ? Number(event.target.value) : null)}
        />
        <span className="text-xs text-[var(--color-ios-label-secondary)]">{unit}/side</span>
      </div>
      <div className="grid gap-1 md:grid-cols-2">
        {sizes.map((size) => (
          <div key={size} className="rounded border border-[var(--color-ios-separator)] px-2 py-1 flex items-center justify-between">
            <span className="text-xs">{formatLoad(size)} {unit}</span>
            <div className="flex items-center gap-1">
              <button
                type="button"
                className="h-6 w-6 rounded border border-[var(--color-ios-separator)]"
                onClick={() => onChange(Math.max(0, Number((perSide - size).toFixed(2))))}
                disabled={perSide < size}
                title={`Remove one ${size}${unit} plate per side`}
              >
                -
              </button>
              <span className="text-xs w-5 text-center">{counts[size] || 0}</span>
              <button
                type="button"
                className="h-6 w-6 rounded border border-[var(--color-ios-separator)]"
                onClick={() => onChange(Number((perSide + size).toFixed(2)))}
                title={`Add one ${size}${unit} plate per side`}
              >
                +
              </button>
            </div>
          </div>
        ))}
      </div>
      <p className="text-xs text-[var(--color-ios-label-secondary)]">
        {formatLoad(perSide)}/side + {formatLoad(barbellWeight)} {unit} bar = {formatLoad(total)} {unit}
      </p>
    </div>
  );
}

export default function ActiveSessionPage() {
  const { sessionId } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();

  const [session, setSession] = useState<any>(null);
  const [exerciseOptions, setExerciseOptions] = useState<any[]>([]);
  const [exerciseMap, setExerciseMap] = useState<Record<string, any>>({});
  const [selectedExerciseId, setSelectedExerciseId] = useState("");
  const [saving, setSaving] = useState(false);

  const isCompleted = session?.status === "completed";
  const unit = user?.unit_preference || "lbs";
  const barbellWeight = Number(user?.barbell_weight || 45);

  const load = async () => {
    if (!sessionId) return;
    const [sessionData, exercises] = await Promise.all([api.getSession(sessionId), api.getExercises()]);
    setSession(sessionData);
    setExerciseOptions(exercises || []);
    const map: Record<string, any> = {};
    for (const exercise of exercises || []) {
      map[exercise.id] = exercise;
    }
    setExerciseMap(map);
  };

  useEffect(() => {
    load();
  }, [sessionId]);

  const patchSet = async (sessionExerciseId: string, setId: string, payload: any) => {
    if (!sessionId) return;
    setSaving(true);
    try {
      await api.updateSet(sessionId, sessionExerciseId, setId, payload);
      await load();
    } finally {
      setSaving(false);
    }
  };

  const addSet = async (sessionExerciseId: string, sets: any[]) => {
    if (!sessionId) return;
    setSaving(true);
    try {
      const last = sets[sets.length - 1];
      await api.addSet(sessionId, sessionExerciseId, {
        set_number: (last?.set_number || sets.length) + 1,
        reps: last?.reps || 10,
        weight: last?.weight,
        duration_secs: last?.duration_secs,
        distance: last?.distance,
        is_warmup: Boolean(last?.is_warmup),
        used_accessories: last?.used_accessories || [],
        band_color: last?.band_color || null,
        completed: false,
      });
      await load();
    } finally {
      setSaving(false);
    }
  };

  const finish = async () => {
    if (!sessionId) return;
    setSaving(true);
    try {
      await api.completeSession(sessionId, {});
      navigate("/history");
    } finally {
      setSaving(false);
    }
  };

  const addExercise = async () => {
    if (!sessionId || !selectedExerciseId || isCompleted) return;
    const positions = (session?.exercises || []).map((entry: any) => Number(entry.position || 0));
    const position = (positions.length ? Math.max(...positions) : -1) + 1;
    setSaving(true);
    try {
      await api.addSessionExercise(sessionId, {
        exercise_id: selectedExerciseId,
        position,
      });
      setSelectedExerciseId("");
      await load();
    } finally {
      setSaving(false);
    }
  };

  const removeExercise = async (sessionExerciseId: string) => {
    if (!sessionId || isCompleted) return;
    setSaving(true);
    try {
      await api.deleteSessionExercise(sessionId, sessionExerciseId);
      await load();
    } finally {
      setSaving(false);
    }
  };

  if (!session) {
    return <div>Loading session...</div>;
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">{isCompleted ? "Session Details" : "Active Session"}</h1>
      </div>

      {!isCompleted && (
        <section className="ios-card p-4 grid gap-3 md:grid-cols-[1fr_auto]">
          <select className="ios-input app-select" value={selectedExerciseId} onChange={(event) => setSelectedExerciseId(event.target.value)}>
            <option value="">Select exercise to add</option>
            {exerciseOptions.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
          </select>
          <button className="btn-ios-primary px-4 py-2" type="button" onClick={addExercise} disabled={saving || !selectedExerciseId}>
            Add Exercise
          </button>
        </section>
      )}

      {session.exercises?.map((sessionExercise: any) => {
        const exercise = exerciseMap[sessionExercise.exercise_id];
        const weightType: number = Number(exercise?.weight_type ?? WT_RAW_WEIGHT);
        const accessories = exercise?.accessories || [];
        const configuredWarmups = Number(exercise?.warmup_sets || 0);
        return (
          <section key={sessionExercise.id} className="ios-card p-4 space-y-3">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-medium">{exercise?.name || sessionExercise.exercise_id}</h2>
                {configuredWarmups > 0 ? (
                  <p className="text-xs text-[var(--color-ios-label-secondary)]">{configuredWarmups} warm-up set{configuredWarmups > 1 ? "s" : ""} configured</p>
                ) : (
                  <p className="text-xs text-[var(--color-ios-label-secondary)]">All working sets</p>
                )}
              </div>
              <div className="flex items-center gap-2">
                <button className="px-2 py-1 rounded border border-[var(--color-ios-separator)]" onClick={() => addSet(sessionExercise.id, sessionExercise.sets || [])} disabled={saving || isCompleted}>
                  Add Set
                </button>
                {!isCompleted && (
                  <button
                    type="button"
                    className="px-2 py-1 rounded border border-red-500/40 text-red-300 disabled:opacity-50"
                    onClick={() => removeExercise(sessionExercise.id)}
                    disabled={saving}
                  >
                    Remove
                  </button>
                )}
              </div>
            </div>
            <div className="space-y-2">
              {(sessionExercise.sets || []).map((setRow: any) => {
                const usedAccessories = setRow.used_accessories || [];
                return (
                  <div key={setRow.id} className="rounded-lg border border-[var(--color-ios-separator)] p-3 space-y-3">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="text-sm">Set {setRow.set_number}</span>
                        {(setRow.is_warmup || (configuredWarmups > 0 && setRow.set_number <= configuredWarmups)) && (
                          <span className="text-[10px] uppercase tracking-wide px-2 py-0.5 rounded bg-[var(--color-ios-separator)]">Warm-up</span>
                        )}
                      </div>
                      <label className="inline-flex items-center gap-2 text-sm">
                        <input
                          type="checkbox"
                          checked={Boolean(setRow.completed)}
                          onChange={(event) => patchSet(sessionExercise.id, setRow.id, { completed: event.target.checked })}
                        />
                        Done
                      </label>
                    </div>

                    <div className="grid gap-2 md:grid-cols-2">
                      <input
                        className="ios-input"
                        type="number"
                        defaultValue={setRow.reps ?? ""}
                        placeholder="reps"
                        onBlur={(event) => patchSet(sessionExercise.id, setRow.id, { reps: event.target.value ? Number(event.target.value) : null })}
                      />

                      {weightType === WT_BODYWEIGHT && (
                        <div className="rounded border border-[var(--color-ios-separator)] px-3 py-2 text-sm text-[var(--color-ios-label-secondary)]">
                          No load entry for bodyweight sets.
                        </div>
                      )}

                      {weightType === WT_BANDS && (
                        <select
                          className="ios-input app-select"
                          value={setRow.band_color || ""}
                          onChange={(event) => patchSet(sessionExercise.id, setRow.id, { band_color: event.target.value || null })}
                        >
                          <option value="">Select band color</option>
                          {BAND_COLORS.map((color) => <option key={color} value={color}>{color}</option>)}
                        </select>
                      )}

                      {weightType === WT_PLATES && (
                        <PlateSelector
                          value={setRow.weight}
                          unit={unit}
                          barbellWeight={barbellWeight}
                          onChange={async (next) => patchSet(sessionExercise.id, setRow.id, { weight: next })}
                        />
                      )}

                      {(weightType === WT_RAW_WEIGHT || weightType === WT_DUMBBELLS) && (
                        <div className="flex items-center gap-2">
                          <input
                            className="ios-input"
                            type="number"
                            step="0.5"
                            defaultValue={setRow.weight ?? ""}
                            placeholder="weight"
                            onBlur={(event) => patchSet(sessionExercise.id, setRow.id, { weight: event.target.value ? Number(event.target.value) : null })}
                          />
                          <span className="text-xs text-[var(--color-ios-label-secondary)]">{unit}</span>
                        </div>
                      )}

                      {weightType === WT_TIME_BASED && (
                        <input
                          className="ios-input"
                          type="number"
                          defaultValue={setRow.duration_secs ?? ""}
                          placeholder="seconds"
                          onBlur={(event) => patchSet(sessionExercise.id, setRow.id, { duration_secs: event.target.value ? Number(event.target.value) : null })}
                        />
                      )}

                      {weightType === WT_DISTANCE && (
                        <div className="flex items-center gap-2">
                          <input
                            className="ios-input"
                            type="number"
                            step="0.1"
                            defaultValue={setRow.distance ?? ""}
                            placeholder={unit === "lbs" ? "miles" : "km"}
                            onBlur={(event) => patchSet(sessionExercise.id, setRow.id, { distance: event.target.value ? Number(event.target.value) : null })}
                          />
                          <span className="text-xs text-[var(--color-ios-label-secondary)]">{unit === "lbs" ? "miles" : "km"}</span>
                        </div>
                      )}
                    </div>

                    <div className="text-xs text-[var(--color-ios-label-secondary)]">
                      {labelForWeightType(weightType, unit, barbellWeight, setRow.weight, setRow.band_color || null)}
                    </div>

                    <div className="flex items-center gap-3 text-xs">
                      <label className="inline-flex items-center gap-1">
                        <input
                          type="checkbox"
                          checked={Boolean(setRow.is_warmup)}
                          onChange={(event) => patchSet(sessionExercise.id, setRow.id, { is_warmup: event.target.checked })}
                        />
                        Warm-up set
                      </label>
                    </div>

                    {accessories.length > 0 && (
                      <div className="space-y-1">
                        <p className="text-xs text-[var(--color-ios-label-secondary)]">Accessories used on this set</p>
                        <div className="flex flex-wrap gap-1">
                          {accessories.map((accessory: string) => {
                            const enabled = usedAccessories.includes(accessory);
                            return (
                              <button
                                key={`${setRow.id}-${accessory}`}
                                type="button"
                                className={`px-2 py-1 rounded text-xs border ${enabled ? "bg-ios-blue/20 border-ios-blue text-ios-blue" : "border-[var(--color-ios-separator)]"}`}
                                onClick={() => patchSet(sessionExercise.id, setRow.id, { used_accessories: toggleAccessory(usedAccessories, accessory) })}
                              >
                                {accessory}
                              </button>
                            );
                          })}
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </section>
        );
      })}

      <button className="btn-ios-primary px-4 py-3" onClick={finish} disabled={saving || isCompleted}>
        {isCompleted ? "Workout Completed" : "Finish Workout"}
      </button>
    </div>
  );
}
