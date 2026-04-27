import { useState } from "react";
import { Palette, Smile } from "lucide-react";
import { IOS_COLORS } from "../../../utils/constants";

const COLOR_OPTIONS = [
  IOS_COLORS.blue,
  IOS_COLORS.green,
  IOS_COLORS.orange,
  IOS_COLORS.purple,
  IOS_COLORS.pink,
  IOS_COLORS.teal,
  IOS_COLORS.yellow,
  IOS_COLORS.gray,
];

const EMOJI_OPTIONS = ["🍿", "🎬", "🎯", "🔥", "🌟", "💡", "🤝", "🎲", "🧠", "📽️"];

export default function AddPersonCard({ onAdd, existingNames }) {
  const [name, setName] = useState("");
  const [color, setColor] = useState(COLOR_OPTIONS[0]);
  const [emoji, setEmoji] = useState(EMOJI_OPTIONS[0]);
  const [isTrusted, setIsTrusted] = useState(false);
  const [error, setError] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (event) => {
    event.preventDefault();
    const trimmed = name.trim();
    if (!trimmed) {
      setError("Name is required");
      return;
    }

    const lower = trimmed.toLowerCase();
    if (existingNames.some((existing) => existing.toLowerCase() === lower)) {
      setError("Person already exists");
      return;
    }

    setSubmitting(true);
    try {
      await onAdd({
        name: trimmed,
        color,
        emoji,
        isTrusted,
      });
      setName("");
      setIsTrusted(false);
      setError(null);
    } catch (err) {
      setError(err.message || "Unable to add person");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-4">
      <form className="space-y-4" onSubmit={handleSubmit}>
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Name"
          className="ios-input"
          autoComplete="off"
        />

        <div>
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-2 text-ios-secondary-label text-sm font-medium uppercase tracking-wide">
              <Palette className="w-4 h-4" />
              Color
            </div>
            <span className="text-ios-caption2 text-ios-tertiary-label">{color}</span>
          </div>
          <div className="flex flex-wrap gap-2">
            {COLOR_OPTIONS.map((option) => (
              <button
                key={option}
                type="button"
                onClick={() => setColor(option)}
                className={`w-10 h-10 rounded-full border-2 ${
                  color === option ? "border-ios-blue" : "border-transparent"
                }`}
                style={{ backgroundColor: option }}
                aria-label={`Select color ${option}`}
              />
            ))}
          </div>
        </div>

        <div>
          <div className="flex items-center gap-2 text-ios-secondary-label text-sm font-medium uppercase tracking-wide mb-2">
            <Smile className="w-4 h-4" />
            Emoji
          </div>
          <div className="flex flex-wrap gap-2">
            {EMOJI_OPTIONS.map((option) => (
              <button
                key={option}
                type="button"
                onClick={() => setEmoji(option)}
                className={`px-3 py-2 rounded-xl text-lg ${
                  emoji === option ? "bg-ios-blue text-white" : "bg-ios-fill"
                }`}
              >
                {option}
              </button>
            ))}
            <button
              type="button"
              onClick={() => setEmoji(null)}
              className={`px-3 py-2 rounded-xl text-sm font-medium ${
                emoji == null ? "bg-ios-blue/10 text-ios-blue" : "bg-ios-fill text-ios-secondary-label"
              }`}
            >
              None
            </button>
          </div>
        </div>

        <div className="flex items-center justify-between">
          <span className="text-ios-secondary-label">Trusted recommender</span>
          <button
            type="button"
            onClick={() => setIsTrusted((prev) => !prev)}
            className={`px-4 py-1.5 rounded-full text-sm font-medium ${
              isTrusted ? "bg-ios-yellow/20 text-ios-yellow" : "bg-ios-fill text-ios-label"
            }`}
          >
            {isTrusted ? "Trusted" : "Not Trusted"}
          </button>
        </div>

        {error && <p className="text-ios-red text-sm">{error}</p>}

        <button
          type="submit"
          disabled={submitting || !name.trim()}
          className="btn-ios-primary w-full disabled:opacity-50"
        >
          {submitting ? "Adding..." : "Add Person"}
        </button>
      </form>
    </div>
  );
}
