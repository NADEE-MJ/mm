import { CheckCircle, RotateCcw, Trash2 } from "lucide-react";
import { MOVIE_STATUS } from "../../../utils/constants";

export default function ActionsBar({ movie, watchHistory, onShowRating, onStatusChange }) {
  return (
    <div className="border-t border-ios-separator p-4 safe-area-bottom bg-ios-bg space-y-3">
      {movie.status === MOVIE_STATUS.TO_WATCH && (
        <>
          {/* Mark as Watched Button */}
          <button
            onClick={onShowRating}
            className="flex-1 btn-ios-primary py-3.5 w-full"
          >
            <CheckCircle className="w-5 h-5 mr-2" />
            Mark as Watched
          </button>

          {/* Delete Button */}
          <button
            onClick={() => onStatusChange(MOVIE_STATUS.DELETED)}
            className="w-full py-3 text-center text-ios-red font-medium active:opacity-70 transition-opacity"
          >
            Delete from List
          </button>
        </>
      )}

      {movie.status === MOVIE_STATUS.WATCHED && (
        <>
          {/* Update Rating Button */}
          <button
            onClick={onShowRating}
            className="flex-1 btn-ios-primary py-3.5 w-full"
          >
            Update Rating
          </button>

          {/* Move to To Watch */}
          <button
            onClick={() => onStatusChange(MOVIE_STATUS.TO_WATCH)}
            className="w-full py-3 text-center text-ios-blue font-medium active:opacity-70 transition-opacity"
          >
            <RotateCcw className="w-4 h-4 inline mr-1" />
            Move to To Watch
          </button>
        </>
      )}

      {movie.status === MOVIE_STATUS.DELETED && (
        <>
          {/* Restore Button */}
          <button
            onClick={() => onStatusChange(MOVIE_STATUS.TO_WATCH)}
            className="flex-1 btn-ios-primary py-3.5 w-full"
          >
            <RotateCcw className="w-5 h-5 mr-2" />
            Restore to To Watch
          </button>
        </>
      )}
    </div>
  );
}
