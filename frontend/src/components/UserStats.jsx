/**
 * UserStats component - Display user statistics
 */

import { useMemo } from "react";
import { Users, Star, Film, Eye, Clock, TrendingUp, Trash2 } from "lucide-react";
import { usePeople } from "../hooks/usePeople";

export default function UserStats({ movies, user }) {
  const { people } = usePeople();

  const stats = useMemo(() => {
    const toWatch = movies.filter((m) => m.status === "toWatch").length;
    const watched = movies.filter((m) => m.status === "watched").length;
    const deleted = movies.filter((m) => m.status === "deleted").length;
    const totalMovies = movies.length;

    const totalRecommenders = people.length;
    const trustedRecommenders = people.filter((p) => p.is_trusted).length;
    const totalRecs = movies.reduce((acc, m) => acc + (m.recommendations?.length || 0), 0);

    const watchedMovies = movies.filter((m) => m.watchHistory?.myRating);
    const avgRating = watchedMovies.length > 0
      ? watchedMovies.reduce((acc, m) => acc + m.watchHistory.myRating, 0) / watchedMovies.length
      : null;

    return {
      toWatch,
      watched,
      deleted,
      totalMovies,
      totalRecommenders,
      trustedRecommenders,
      totalRecs,
      avgRating,
      watchedWithRating: watchedMovies.length,
    };
  }, [movies, people]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-ios-title1">Statistics</h2>
      </div>

      {/* User Info */}
      <div className="ios-card p-5">
        <div className="flex items-center gap-3">
          <div className="w-14 h-14 rounded-full bg-ios-blue/20 flex items-center justify-center">
            <Users className="w-7 h-7 text-ios-blue" />
          </div>
          <div>
            <p className="text-ios-title3 font-bold text-ios-label">{user?.username}</p>
            <p className="text-ios-caption1 text-ios-secondary-label">Movie Manager User</p>
          </div>
        </div>
      </div>

      {/* Movies Stats */}
      <div>
        <h3 className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wider mb-3">
          Movies
        </h3>
        <div className="grid grid-cols-2 gap-3">
          <div className="ios-card p-4">
            <Film className="w-6 h-6 text-ios-blue mb-2" />
            <p className="text-ios-title1 font-bold text-ios-label">{stats.totalMovies}</p>
            <p className="text-ios-caption1 text-ios-secondary-label">Total Movies</p>
          </div>
          <div className="ios-card p-4">
            <Clock className="w-6 h-6 text-ios-orange mb-2" />
            <p className="text-ios-title1 font-bold text-ios-label">{stats.toWatch}</p>
            <p className="text-ios-caption1 text-ios-secondary-label">To Watch</p>
          </div>
          <div className="ios-card p-4">
            <Eye className="w-6 h-6 text-ios-green mb-2" />
            <p className="text-ios-title1 font-bold text-ios-label">{stats.watched}</p>
            <p className="text-ios-caption1 text-ios-secondary-label">Watched</p>
          </div>
          <div className="ios-card p-4">
            <Trash2 className="w-6 h-6 text-ios-red mb-2" />
            <p className="text-ios-title1 font-bold text-ios-label">{stats.deleted}</p>
            <p className="text-ios-caption1 text-ios-secondary-label">Deleted</p>
          </div>
        </div>
      </div>

      {/* Rating Stats */}
      {stats.avgRating && (
        <div>
          <h3 className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wider mb-3">
            Ratings
          </h3>
          <div className="ios-card p-5 bg-ios-blue/5 border border-ios-blue/20">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <TrendingUp className="w-7 h-7 text-ios-blue" />
                <div>
                  <p className="text-ios-caption1 text-ios-secondary-label">Average Rating</p>
                  <p className="text-ios-caption2 text-ios-tertiary-label">
                    Based on {stats.watchedWithRating} rated {stats.watchedWithRating === 1 ? "movie" : "movies"}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-1">
                <Star className="w-6 h-6 text-ios-blue fill-current" />
                <span className="text-ios-title1 font-bold text-ios-blue">
                  {stats.avgRating.toFixed(1)}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Recommenders Stats */}
      <div>
        <h3 className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wider mb-3">
          Recommenders
        </h3>
        <div className="grid grid-cols-3 gap-3">
          <div className="ios-card p-4 text-center">
            <Users className="w-6 h-6 mx-auto text-ios-label mb-2" />
            <p className="text-ios-title2 font-bold text-ios-label">{stats.totalRecommenders}</p>
            <p className="text-ios-caption2 text-ios-secondary-label">Total</p>
          </div>
          <div className="ios-card p-4 text-center">
            <Star className="w-6 h-6 mx-auto text-ios-yellow fill-current mb-2" />
            <p className="text-ios-title2 font-bold text-ios-yellow">{stats.trustedRecommenders}</p>
            <p className="text-ios-caption2 text-ios-secondary-label">Trusted</p>
          </div>
          <div className="ios-card p-4 text-center">
            <Film className="w-6 h-6 mx-auto text-ios-blue mb-2" />
            <p className="text-ios-title2 font-bold text-ios-blue">{stats.totalRecs}</p>
            <p className="text-ios-caption2 text-ios-secondary-label">Recs</p>
          </div>
        </div>
      </div>
    </div>
  );
}
