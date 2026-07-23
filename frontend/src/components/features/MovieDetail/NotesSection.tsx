import { useEffect, useState } from "react";
import { NotebookPen } from "lucide-react";

export default function NotesSection({ notes, onSave }) {
  const [value, setValue] = useState(notes || "");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    setValue(notes || "");
  }, [notes]);

  const dirty = value !== (notes || "");

  const handleSave = async () => {
    if (!dirty || saving) return;
    setSaving(true);
    try {
      await onSave(value.trim());
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="px-4 pb-4">
      <div className="ios-card p-4 space-y-2">
        <div className="flex items-center gap-2 text-ios-secondary-label">
          <NotebookPen className="w-4 h-4" />
          <h3 className="text-ios-caption1 font-semibold uppercase tracking-wide">Notes</h3>
        </div>
        <textarea
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onBlur={handleSave}
          placeholder="Add a personal note about this title..."
          rows={3}
          className="ios-input w-full resize-y !h-auto py-2"
        />
        {dirty && (
          <div className="flex justify-end">
            <button
              type="button"
              onClick={handleSave}
              disabled={saving}
              className="px-3 py-1.5 bg-ios-blue text-white rounded-lg text-sm font-medium disabled:opacity-50"
            >
              {saving ? "Saving..." : "Save Note"}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
