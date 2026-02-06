import { useMemo } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
  Star,
  StarOff,
  Film,
  Eye,
  Clock,
  Palette,
  Smile,
  Check,
  TrendingUp,
  ChevronRight,
} from "lucide-react";
import { getPoster, formatRating } from "../utils/helpers";
import { IOS_COLORS } from "../utils/constants";
import { usePeople } from "../hooks/usePeople";

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

export default function PersonDetailPage({ movies = [] }) {
  const navigate = useNavigate();
  const { personName } = useParams();
  const { people, loading, updateTrust, updatePerson } = usePeople();

  const decodedName = decodeURIComponent(personName || "");

  const colorCounts = useMemo(() => {
    return people.reduce((acc, person) => {
      const key = person.color || "default";
      acc[key] = (acc[key] || 0) + 1;
      return acc;
    }, {});
  }, [people]);

  const emojiCounts = useMemo(() => {
    return people.reduce((acc, person) => {
      const key = person.emoji || "none";
      acc[key] = (acc[key] || 0) + 1;
      return acc;
    }, {});
  }, [people]);

  const person = useMemo(() => {
    const personRecord = people.find((entry) => entry.name === decodedName);
    if (!personRecord) return null;

    const recommendations = movies.filter((movie) =>
      movie.recommendations?.some((rec) => rec.person === personRecord.name),
    );

    const toWatch = recommendations.filter((movie) => movie.status === "toWatch").length;
    const watched = recommendations.filter((movie) => movie.status === "watched").length;
    const ratedMovies = recommendations.filter((movie) => movie.watchHistory?.myRating);
    const avgRating =
      ratedMovies.length > 0
        ? ratedMovies.reduce((acc, movie) => acc + movie.watchHistory.myRating, 0) / ratedMovies.length
        : null;

    return {
      ...personRecord,
      totalRecommendations: recommendations.length,
      toWatch,
      watched,
      avgRating,
      movies: recommendations,
    };
  }, [decodedName, people, movies]);

  const handleToggleTrust = async () => {
    if (!person) return;
    await updateTrust(person.name, !person.is_trusted);
  };

  const handleUpdatePerson = async (updates) => {
    if (!person) return;
    await updatePerson(person.name, updates);
  };

  if (loading) {
    return (
      <>
        <div className="nav-stack-blur-backdrop fade-in-backdrop" onClick={() => navigate(-1)} />
        <div className="nav-stack-page slide-in-right">
          <div className="bg-ios-bg min-h-screen">
            <header className="nav-stack-header">
              <button onClick={() => navigate(-1)} className="nav-stack-back-button">
                <ChevronRight className="w-5 h-5 rotate-180" />
                <span>Back</span>
              </button>
            </header>
            <div className="nav-stack-content">
              <p className="text-ios-secondary-label">Loading recommender...</p>
            </div>
          </div>
        </div>
      </>
    );
  }

  if (!person) {
    return (
      <>
        <div className="nav-stack-blur-backdrop fade-in-backdrop" onClick={() => navigate(-1)} />
        <div className="nav-stack-page slide-in-right">
          <div className="bg-ios-bg min-h-screen">
            <header className="nav-stack-header">
              <button onClick={() => navigate(-1)} className="nav-stack-back-button">
                <ChevronRight className="w-5 h-5 rotate-180" />
                <span>Back</span>
              </button>
            </header>
            <div className="nav-stack-content">
              <p className="text-ios-secondary-label">Recommender not found.</p>
            </div>
          </div>
        </div>
      </>
    );
  }

  const avatarColor = person.color || IOS_COLORS.gray;
  const avatarEmoji = person.emoji || person.name.charAt(0).toUpperCase();
  const colorKey = person.color || "default";
  const emojiKey = person.emoji || "none";
  const sharedColors = Math.max(0, (colorCounts[colorKey] || 1) - 1);
  const sharedEmoji = Math.max(0, (emojiCounts[emojiKey] || 1) - 1);

  const stats = [
    {
      label: "Total Movies",
      value: person.totalRecommendations,
      icon: Film,
      color: "text-ios-blue",
    },
    { label: "Watched", value: person.watched, icon: Eye, color: "text-ios-green" },
    { label: "To Watch", value: person.toWatch, icon: Clock, color: "text-ios-orange" },
  ];

  return (
    <>
      <div className="nav-stack-blur-backdrop fade-in-backdrop" onClick={() => navigate(-1)} />
      <div className="nav-stack-page slide-in-right">
        <div className="bg-ios-bg min-h-screen">
          <header className="nav-stack-header">
            <button onClick={() => navigate(-1)} className="nav-stack-back-button">
              <ChevronRight className="w-5 h-5 rotate-180" />
              <span>Back</span>
            </button>
            <h2 className="text-ios-headline font-semibold flex-1 text-center">{person.name}</h2>
            <div className="w-20" />
          </header>

          <div className="nav-stack-content pb-24">
            <div className="ios-card p-4 mb-6">
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-3">
                  <div
                    className="w-12 h-12 rounded-full flex items-center justify-center text-xl font-semibold text-white relative"
                    style={{ backgroundColor: avatarColor }}
                  >
                    {avatarEmoji}
                    {person.is_trusted && (
                      <Star className="w-4 h-4 text-ios-yellow fill-current absolute -bottom-1 -right-1 drop-shadow" />
                    )}
                  </div>
                  <div>
                    <p className="text-ios-body font-semibold text-ios-label">{person.name}</p>
                    <p className="text-ios-caption1 text-ios-secondary-label">
                      {person.is_trusted ? "Trusted Recommender" : "Not Trusted"}
                    </p>
                  </div>
                </div>
                <button
                  onClick={handleToggleTrust}
                  className={`px-4 py-2 rounded-xl text-sm font-medium transition-all active:scale-95 ${
                    person.is_trusted
                      ? "bg-ios-yellow/20 text-ios-yellow"
                      : "bg-ios-fill text-ios-label"
                  }`}
                >
                  {person.is_trusted ? (
                    <>
                      <Star className="w-4 h-4 inline mr-1 fill-current" />
                      Trusted
                    </>
                  ) : (
                    <>
                      <StarOff className="w-4 h-4 inline mr-1" />
                      Mark Trusted
                    </>
                  )}
                </button>
              </div>
            </div>

            <div className="grid grid-cols-3 gap-3 mb-6">
              {stats.map((stat) => (
                <div key={stat.label} className="ios-card p-4 text-center">
                  <stat.icon className={`w-6 h-6 mx-auto mb-2 ${stat.color}`} />
                  <p className="text-ios-title2 font-bold text-ios-label">{stat.value}</p>
                  <p className="text-ios-caption2 text-ios-secondary-label">{stat.label}</p>
                </div>
              ))}
            </div>

            {person.avgRating && (
              <div className="ios-card p-4 mb-6 bg-ios-blue/5 border border-ios-blue/20">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <TrendingUp className="w-6 h-6 text-ios-blue" />
                    <span className="text-ios-body text-ios-label">Average Rating</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <Star className="w-5 h-5 text-ios-blue fill-current" />
                    <span className="text-ios-title2 font-bold text-ios-blue">
                      {person.avgRating.toFixed(1)}
                    </span>
                  </div>
                </div>
              </div>
            )}

            <div className="ios-card p-4 mb-4">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2 text-ios-secondary-label text-sm font-medium uppercase tracking-wide">
                  <Palette className="w-4 h-4" />
                  Color
                </div>
                <span className="text-ios-caption2 text-ios-tertiary-label">
                  {sharedColors === 0 ? "Unique color" : `${sharedColors} other${sharedColors === 1 ? "" : "s"}`}
                </span>
              </div>
              <div className="flex flex-wrap gap-2">
                {COLOR_OPTIONS.map((option) => (
                  <button
                    key={option}
                    type="button"
                    onClick={() => handleUpdatePerson({ color: option })}
                    className={`w-10 h-10 rounded-full border-2 ${
                      person.color === option ? "border-ios-blue" : "border-transparent"
                    }`}
                    style={{ backgroundColor: option }}
                  >
                    {person.color === option && <Check className="w-4 h-4 text-white" />}
                  </button>
                ))}
              </div>
            </div>

            <div className="ios-card p-4 mb-6">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2 text-ios-secondary-label text-sm font-medium uppercase tracking-wide">
                  <Smile className="w-4 h-4" />
                  Emoji
                </div>
                <span className="text-ios-caption2 text-ios-tertiary-label">
                  {sharedEmoji === 0 ? "Unique emoji" : `${sharedEmoji} other${sharedEmoji === 1 ? "" : "s"}`}
                </span>
              </div>
              <div className="flex flex-wrap gap-2">
                {EMOJI_OPTIONS.map((option) => (
                  <button
                    key={option}
                    type="button"
                    onClick={() => handleUpdatePerson({ emoji: option })}
                    className={`px-3 py-2 rounded-xl text-lg ${
                      person.emoji === option ? "bg-ios-blue text-white" : "bg-ios-fill"
                    }`}
                  >
                    {option}
                  </button>
                ))}
                <button
                  type="button"
                  onClick={() => handleUpdatePerson({ emoji: null })}
                  className={`px-3 py-2 rounded-xl text-sm font-medium ${
                    person.emoji == null
                      ? "bg-ios-blue/10 text-ios-blue"
                      : "bg-ios-fill text-ios-secondary-label"
                  }`}
                >
                  None
                </button>
              </div>
            </div>

            {person.movies.length > 0 && (
              <div>
                <h4 className="text-ios-caption1 font-semibold text-ios-secondary-label uppercase tracking-wider mb-3">
                  Movies ({person.movies.length})
                </h4>
                <div className="ios-list">
                  {person.movies.map((movie) => {
                    const title = movie.omdbData?.title || movie.tmdbData?.title || "Unknown";
                    const year = movie.omdbData?.year || movie.tmdbData?.year;
                    const poster = getPoster(movie.omdbData?.poster || movie.tmdbData?.poster);
                    const rating = movie.watchHistory?.myRating;
                    const isWatched = movie.status === "watched";

                    return (
                      <button
                        key={movie.imdbId}
                        onClick={() => navigate(`/movie/${movie.imdbId}`)}
                        className="ios-list-item py-3 w-full text-left"
                      >
                        <div className="flex items-center gap-3 flex-1 min-w-0">
                          <img
                            src={poster}
                            alt={title}
                            className="w-10 h-15 object-cover rounded-lg flex-shrink-0"
                          />
                          <div className="flex-1 min-w-0">
                            <p className="text-ios-body text-ios-label font-medium truncate">{title}</p>
                            <p className="text-ios-caption1 text-ios-secondary-label">
                              {year}
                              {isWatched && <span className="ml-2 text-ios-green">• Watched</span>}
                            </p>
                          </div>
                        </div>
                        {rating && (
                          <div className="flex items-center gap-1 text-ios-blue ml-3">
                            <Star className="w-4 h-4 fill-current" />
                            <span className="text-ios-caption1 font-semibold">{formatRating(rating)}</span>
                          </div>
                        )}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </>
  );
}
