/**
 * RatingPrompt component - iOS Style
 * Prompts user when rating is below threshold
 */

import { useState } from "react";
import { AlertTriangle, Trash2, CheckCircle, X } from "lucide-react";
import { RATING_THRESHOLD } from "../utils/constants";

export default function RatingPrompt({ movie, recommenders, onAction, onClose }) {
  const [selectedAction, setSelectedAction] = useState(null);
  const [processing, setProcessing] = useState(false);

  if (!movie || !recommenders || recommenders.length === 0) return null;

  const handleAction = async () => {
    if (!selectedAction) return;
    setProcessing(true);
    try {
      await onAction(selectedAction);
    } finally {
      setProcessing(false);
    }
  };

  const actions = [
    {
      value: "keep",
      icon: CheckCircle,
      label: "Keep Movies",
      description: "Give them another chance",
      color: "ios-green",
    },
    {
      value: "delete",
      icon: Trash2,
      label: "Delete All",
      description: "Remove their recommendations",
      color: "ios-red",
    },
  ];

  return (
    <div className="fixed inset-0 z-50">
      <div className="ios-sheet-backdrop" onClick={onClose} />
      <div className="ios-sheet ios-slide-up">
        <div className="ios-sheet-handle" />

        {/* Header */}
        <div className="p-6 text-center">
          <div className="w-16 h-16 bg-ios-orange/20 rounded-full flex items-center justify-center mx-auto mb-4">
            <AlertTriangle className="w-8 h-8 text-ios-orange" />
          </div>
          <h2 className="text-ios-title2 font-bold text-ios-label mb-2">Low Rating</h2>
          <p className="text-ios-body text-ios-secondary-label">
            You rated this movie below {RATING_THRESHOLD}/10
          </p>
        </div>

        <div className="px-4 pb-6">
          {/* Recommenders */}
          <div className="ios-card p-4 mb-6">
            <p className="text-ios-caption1 text-ios-secondary-label mb-3">Recommended by:</p>
            <div className="flex flex-wrap gap-2">
              {recommenders.map((rec) => (
                <span
                  key={rec.person}
                  className="px-3 py-1.5 bg-ios-fill rounded-full text-ios-body text-ios-label"
                >
                  {rec.person}
                </span>
              ))}
            </div>
          </div>

          {/* Question */}
          <p className="text-ios-body text-ios-label mb-4 text-center">
            What would you like to do with their other recommendations?
          </p>

          {/* Actions */}
          <div className="space-y-3 mb-6">
            {actions.map((action) => {
              const Icon = action.icon;
              const isSelected = selectedAction === action.value;
              const colorClasses =
                action.color === "ios-red"
                  ? "border-ios-red bg-ios-red/10"
                  : "border-ios-green bg-ios-green/10";

              return (
                <button
                  key={action.value}
                  onClick={() => setSelectedAction(action.value)}
                  className={`w-full p-4 rounded-2xl flex items-center gap-4 transition-all border-2 ${
                    isSelected ? colorClasses : "border-transparent bg-ios-secondary-fill"
                  }`}
                >
                  <div
                    className={`w-10 h-10 rounded-full flex items-center justify-center ${
                      action.color === "ios-red" ? "bg-ios-red/20" : "bg-ios-green/20"
                    }`}
                  >
                    <Icon
                      className={`w-5 h-5 ${
                        action.color === "ios-red" ? "text-ios-red" : "text-ios-green"
                      }`}
                    />
                  </div>
                  <div className="flex-1 text-left">
                    <p className="text-ios-body font-semibold text-ios-label">{action.label}</p>
                    <p className="text-ios-caption1 text-ios-secondary-label">
                      {action.description}
                    </p>
                  </div>
                  {isSelected && (
                    <CheckCircle
                      className={`w-6 h-6 ${
                        action.color === "ios-red" ? "text-ios-red" : "text-ios-green"
                      }`}
                    />
                  )}
                </button>
              );
            })}
          </div>

          {/* Action Buttons */}
          <div className="flex gap-3">
            <button onClick={onClose} className="flex-1 btn-ios-secondary py-3.5">
              Cancel
            </button>
            <button
              onClick={handleAction}
              disabled={!selectedAction || processing}
              className={`flex-1 py-3.5 rounded-xl font-semibold transition-all disabled:opacity-50 ${
                selectedAction === "delete" ? "bg-ios-red text-white" : "btn-ios-primary"
              }`}
            >
              {processing ? "Processing..." : "Confirm"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
