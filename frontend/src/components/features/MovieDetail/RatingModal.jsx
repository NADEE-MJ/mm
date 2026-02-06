import { useState } from "react";
import { IOSSheet } from "../../ui";

export default function RatingModal({ isOpen, onClose, onSave, initialRating = 7.0 }) {
  const [rating, setRating] = useState(initialRating);

  const quickRatings = [5.0, 6.0, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0];

  const handleSave = () => {
    onSave(rating);
    onClose();
  };

  return (
    <IOSSheet isOpen={isOpen} onClose={onClose} title="Rate This Movie" modalId="rating-modal">
      <div className="space-y-6">
        {/* Rating Display */}
        <div className="text-center">
          <div className="text-6xl font-bold text-ios-yellow mb-2">{rating.toFixed(1)}</div>
          <p className="text-ios-secondary-label">out of 10</p>
        </div>

        {/* Quick Rating Buttons */}
        <div>
          <label className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wider mb-3 block">
            Quick Select
          </label>
          <div className="grid grid-cols-5 gap-2">
            {quickRatings.map((r) => (
              <button
                key={r}
                onClick={() => setRating(r)}
                className={`px-3 py-2 rounded-xl text-sm font-medium transition-all ${
                  rating === r
                    ? "bg-ios-yellow text-black font-bold"
                    : "bg-ios-fill text-ios-label active:bg-ios-secondary-fill"
                }`}
              >
                {r.toFixed(1)}
              </button>
            ))}
          </div>
        </div>

        {/* Fine-tune Slider */}
        <div>
          <label className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wider mb-3 block">
            Fine Tune
          </label>
          <input
            type="range"
            min="0"
            max="10"
            step="0.1"
            value={rating}
            onChange={(e) => setRating(parseFloat(e.target.value))}
            className="w-full"
          />
          <div className="flex justify-between text-ios-caption1 text-ios-tertiary-label mt-1">
            <span>0</span>
            <span>10</span>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex gap-3 pt-2">
          <button
            onClick={onClose}
            className="flex-1 btn-ios-secondary py-3"
          >
            Cancel
          </button>
          <button onClick={handleSave} className="flex-1 btn-ios-primary py-3">
            Save Rating
          </button>
        </div>
      </div>
    </IOSSheet>
  );
}
