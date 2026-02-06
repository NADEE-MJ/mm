import { useNavigate } from "react-router-dom";
import { useMovies } from "../hooks/useMovies";
import { usePeople } from "../hooks/usePeople";
import AddMovie from "../components/AddMovie";

export default function AddMoviePage() {
  const navigate = useNavigate();
  const { addRecommendation } = useMovies();
  const { people, getPeopleNames } = usePeople();

  const handleAdd = async (...args) => {
    await addRecommendation(...args);
    navigate(-1);
  };

  return (
    <>
      <div className="nav-stack-blur-backdrop fade-in-backdrop" onClick={() => navigate(-1)} />
      <div className="nav-stack-page slide-in-right">
        <AddMovie
          onAdd={handleAdd}
          onClose={() => navigate(-1)}
          people={people}
          peopleNames={getPeopleNames()}
        />
      </div>
    </>
  );
}
