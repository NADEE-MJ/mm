import { VOTE_TYPE } from "./constants";

// Movies land in the neutral middle of the 1-10 scale before they're ranked or rated.
const NEUTRAL_SCORE = 5.5;

export function getPeopleMetaCounts(people) {
  return people.reduce(
    (acc, person) => {
      const colorKey = person.color || "default";
      const emojiKey = person.emoji || "none";
      acc.color[colorKey] = (acc.color[colorKey] || 0) + 1;
      acc.emoji[emojiKey] = (acc.emoji[emojiKey] || 0) + 1;
      return acc;
    },
    { color: {}, emoji: {} },
  );
}

/**
 * Recommender score: rewards a person for upvoting movies that turned out great
 * (high ranked/rated score) and for downvoting movies that turned out bad, and
 * penalizes the opposite. Only movies with a known score (ranked or my-rated)
 * count. Range is roughly -4.5 (always wrong) to +4.5 (always right).
 */
function computeRecommenderScore(recommendations, rankingByImdbId) {
  let total = 0;
  let count = 0;
  for (const { movie, rec } of recommendations) {
    const ranking = rankingByImdbId?.[movie.imdbId];
    const movieScore = ranking?.score ?? movie.watchHistory?.myRating;
    if (movieScore == null) continue;
    const isDownvote = rec?.vote_type === VOTE_TYPE.DOWNVOTE;
    total += isDownvote ? NEUTRAL_SCORE - movieScore : movieScore - NEUTRAL_SCORE;
    count += 1;
  }
  return count > 0 ? total / count : null;
}

export function buildPersonStats(person, movies, rankingByImdbId = {}) {
  const recommendations = movies
    .map((movie) => ({
      movie,
      rec: movie.recommendations?.find((r) => r.person === person.name),
    }))
    .filter((entry) => entry.rec);

  const recommendedMovies = recommendations.map((entry) => entry.movie);
  const toWatch = recommendedMovies.filter((movie) => movie.status === "toWatch").length;
  const watched = recommendedMovies.filter((movie) => movie.status === "watched").length;
  const ratedMovies = recommendedMovies.filter((movie) => movie.watchHistory?.myRating);
  const avgRating =
    ratedMovies.length > 0
      ? ratedMovies.reduce((acc, movie) => acc + movie.watchHistory.myRating, 0) / ratedMovies.length
      : null;
  const recommenderScore = computeRecommenderScore(recommendations, rankingByImdbId);

  return {
    ...person,
    totalRecommendations: recommendedMovies.length,
    toWatch,
    watched,
    avgRating,
    recommenderScore,
    movies: recommendedMovies,
    isDefault: Boolean(person.quick_key),
  };
}

export function buildPeopleWithStats(people, movies, rankingByImdbId = {}) {
  return people
    .map((person) => buildPersonStats(person, movies, rankingByImdbId))
    .sort((a, b) => b.totalRecommendations - a.totalRecommendations);
}
