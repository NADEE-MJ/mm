import { useMemo } from "react";
import { Link } from "react-router-dom";
import { Trash2, ChevronRight, Folder, Plus } from "lucide-react";
import { MOVIE_STATUS } from "../utils/constants";

export default function ListsPage({ movies }) {
  const deletedMovies = useMemo(
    () => movies.filter((m) => m.status === MOVIE_STATUS.DELETED),
    [movies],
  );

  return (
    <div className="space-y-6">
      <h2 className="text-ios-title1">Lists</h2>

      {/* Built-in Lists */}
      <div className="ios-list">
        <Link to="/lists/deleted" className="ios-list-item">
          <div className="flex items-center gap-3">
            <div className="ios-list-icon bg-ios-red/20">
              <Trash2 className="w-5 h-5 text-ios-red" />
            </div>
            <span>Deleted</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-ios-secondary-label">{deletedMovies.length}</span>
            <ChevronRight className="w-5 h-5 text-ios-tertiary-label" />
          </div>
        </Link>
      </div>

      {/* Custom Lists Section */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-ios-headline">Custom Lists</h3>
          <button className="text-ios-blue text-sm font-medium">
            <Plus className="w-4 h-4 inline mr-1" />
            New List
          </button>
        </div>
        <div className="ios-card text-center py-8">
          <Folder className="w-12 h-12 mx-auto mb-3 text-ios-tertiary-label" />
          <p className="text-ios-secondary-label text-sm">
            Create custom lists to organize your movies
          </p>
        </div>
      </div>
    </div>
  );
}
