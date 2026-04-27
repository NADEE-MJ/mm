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

export function buildPersonStats(person, movies) {
  const recommendations = movies.filter((movie) =>
    movie.recommendations?.some((rec) => rec.person === person.name),
  );
  const toWatch = recommendations.filter((movie) => movie.status === "toWatch").length;
  const watched = recommendations.filter((movie) => movie.status === "watched").length;
  const ratedMovies = recommendations.filter((movie) => movie.watchHistory?.myRating);
  const avgRating =
    ratedMovies.length > 0
      ? ratedMovies.reduce((acc, movie) => acc + movie.watchHistory.myRating, 0) / ratedMovies.length
      : null;

  return {
    ...person,
    totalRecommendations: recommendations.length,
    toWatch,
    watched,
    avgRating,
    movies: recommendations,
    isDefault: Boolean(person.quick_key),
  };
}

export function buildPeopleWithStats(people, movies) {
  return people
    .map((person) => buildPersonStats(person, movies))
    .sort((a, b) => b.totalRecommendations - a.totalRecommendations);
}
