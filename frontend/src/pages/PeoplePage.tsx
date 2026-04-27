import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import PeopleManager from "../components/PeopleManager";
import AddPersonCard from "../components/features/People/AddPersonCard";
import Modal from "../components/ui/Modal";
import { usePeople } from "../hooks/usePeople";

export default function PeoplePage({ movies }) {
  const navigate = useNavigate();
  const { people, addPerson } = usePeople();
  const [showAddPerson, setShowAddPerson] = useState(false);

  const existingNames = useMemo(() => people.map((person) => person.name), [people]);

  const handleAdd = async (payload) => {
    await addPerson(payload);
    setShowAddPerson(false);
  };

  return (
    <>
      <PeopleManager
        movies={movies}
        onAddPerson={() => setShowAddPerson(true)}
        onPersonSelect={(person) => navigate(`/people/${encodeURIComponent(person.name)}`)}
      />

      <Modal
        isOpen={showAddPerson}
        onClose={() => setShowAddPerson(false)}
        title="Add Recommender"
        maxWidth="640px"
      >
        <AddPersonCard onAdd={handleAdd} existingNames={existingNames} />
      </Modal>
    </>
  );
}
