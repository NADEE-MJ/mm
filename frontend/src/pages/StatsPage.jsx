import UserStats from "../components/UserStats";

export default function StatsPage({ movies, user }) {
  return <UserStats movies={movies} user={user} />;
}
