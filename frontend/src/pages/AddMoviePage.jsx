import { useNavigate } from "react-router-dom";
import { useMovies } from "../hooks/useMovies";
import { usePeople } from "../hooks/usePeople";
import AddMovie from "../components/AddMovie";
import PageTransition from "../components/PageTransition";

export default function AddMoviePage() {
  const navigate = useNavigate();
  const { addRecommendation } = useMovies();
  const { people, getPeopleNames } = usePeople();

  const handleAdd = async (...args) => {
    await addRecommendation(...args);
  };

  const handleClose = (imdbId) => {
    // If imdbId is provided, navigate to movie detail page
    // Otherwise just go back (e.g., user cancelled)
    if (imdbId) {
      navigate(`/movie/${imdbId}`);
    } else {
      navigate(-1);
    }
  };

  return (
    <PageTransition onClose={() => navigate(-1)}>
      <AddMovie
        onAdd={handleAdd}
        onClose={handleClose}
        people={people}
        peopleNames={getPeopleNames()}
      />
    </PageTransition>
  );
}
