import { useMemo } from "react";
import { useNavigate } from "react-router-dom";
import { ChevronRight } from "lucide-react";
import AddPersonCard from "../components/features/People/AddPersonCard";
import { usePeople } from "../hooks/usePeople";
import PageTransition from "../components/PageTransition";

export default function AddPersonPage() {
  const navigate = useNavigate();
  const { people, addPerson } = usePeople();

  const existingNames = useMemo(() => people.map((person) => person.name), [people]);

  const handleAdd = async (payload) => {
    await addPerson(payload);
    navigate(-1);
  };

  return (
    <PageTransition onClose={() => navigate(-1)}>
      <div className="bg-ios-bg min-h-screen">
        <header className="nav-stack-header">
          <button onClick={() => navigate(-1)} className="nav-stack-back-button">
            <ChevronRight className="w-5 h-5 rotate-180" />
            <span>Back</span>
          </button>
          <h2 className="text-ios-headline font-semibold flex-1 text-center">Add Recommender</h2>
          <div className="w-20" />
        </header>

        <div className="nav-stack-content">
          <AddPersonCard onAdd={handleAdd} existingNames={existingNames} />
        </div>
      </div>
    </PageTransition>
  );
}
