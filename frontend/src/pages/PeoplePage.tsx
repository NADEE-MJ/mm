import { useNavigate } from "react-router-dom";
import PeopleManager from "../components/PeopleManager";

export default function PeoplePage({ movies }) {
  const navigate = useNavigate();

  return (
    <PeopleManager
      movies={movies}
      onAddPerson={() => navigate("/people/add")}
      onPersonSelect={(person) => navigate(`/people/${encodeURIComponent(person.name)}`)}
    />
  );
}
