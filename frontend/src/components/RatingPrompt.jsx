/**
 * RatingPrompt component
 * Prompts user when rating is below threshold
 */

import { useState } from 'react';
import { AlertCircle } from 'lucide-react';
import { MOVIE_STATUS, RATING_THRESHOLD } from '../utils/constants';

export default function RatingPrompt({ movie, recommenders, onAction, onClose }) {
  const [selectedAction, setSelectedAction] = useState(null);

  if (!movie || !recommenders || recommenders.length === 0) return null;

  const handleAction = async () => {
    if (!selectedAction) return;

    await onAction(selectedAction);
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-75 z-50 flex items-center justify-center p-4">
      <div className="bg-gray-800 rounded-lg shadow-xl max-w-md w-full p-6">
        {/* Icon */}
        <div className="flex justify-center mb-4">
          <AlertCircle className="w-16 h-16 text-yellow-500" />
        </div>

        {/* Title */}
        <h2 className="text-2xl font-bold text-center mb-4">
          Low Rating Detected
        </h2>

        {/* Message */}
        <p className="text-gray-300 text-center mb-6">
          You rated this movie below {RATING_THRESHOLD}. This movie was recommended by:
        </p>

        {/* Recommenders */}
        <div className="mb-6 p-4 bg-gray-700 rounded">
          <ul className="list-disc list-inside space-y-1">
            {recommenders.map(rec => (
              <li key={rec.person} className="text-white">
                {rec.person}
              </li>
            ))}
          </ul>
        </div>

        {/* Question */}
        <p className="text-gray-300 text-center mb-6">
          What would you like to do with {recommenders.length > 1 ? 'their' : 'this person\'s'} other recommendations?
        </p>

        {/* Actions */}
        <div className="space-y-3">
          <button
            onClick={() => setSelectedAction('questionable')}
            className={`w-full py-3 rounded-lg font-medium transition-colors ${
              selectedAction === 'questionable'
                ? 'bg-yellow-600 text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
            }`}
          >
            Move to Questionable
          </button>
          <button
            onClick={() => setSelectedAction('keep')}
            className={`w-full py-3 rounded-lg font-medium transition-colors ${
              selectedAction === 'keep'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
            }`}
          >
            Keep in To Watch
          </button>
          <button
            onClick={() => setSelectedAction('delete')}
            className={`w-full py-3 rounded-lg font-medium transition-colors ${
              selectedAction === 'delete'
                ? 'bg-red-600 text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
            }`}
          >
            Delete Recommendations
          </button>
        </div>

        {/* Confirm/Cancel */}
        <div className="flex gap-3 mt-6">
          <button
            onClick={handleAction}
            disabled={!selectedAction}
            className="flex-1 btn-primary disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Confirm
          </button>
          <button
            onClick={onClose}
            className="flex-1 btn-secondary"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
}
