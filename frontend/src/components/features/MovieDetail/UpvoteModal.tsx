import { useState } from "react";
import { Search, Check } from "lucide-react";
import Modal from "../../ui/Modal";

export default function UpvoteModal({ isOpen, onClose, peopleNames, onAdd }) {
  const [query, setQuery] = useState("");
  const [selectedPerson, setSelectedPerson] = useState(null);

  const availablePeople = peopleNames.filter(name =>
    name.toLowerCase().includes(query.toLowerCase())
  ).slice(0, 10);

  const handleAdd = () => {
    if (!selectedPerson && !query.trim()) return;
    const person = selectedPerson || query.trim();
    onAdd(person);
    setQuery("");
    setSelectedPerson(null);
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Add Recommendation" maxWidth="560px">
      <div className="space-y-4">
        <p className="text-ios-body text-ios-secondary-label">
          Who recommended this movie?
        </p>

        {/* Search Input */}
        <div className="relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-ios-tertiary-label" />
          <input
            type="text"
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              setSelectedPerson(null);
            }}
            placeholder="Search or enter name..."
            className="ios-input input-with-leading-icon"
            autoComplete="off"
          />
        </div>

        {/* People List */}
        {availablePeople.length > 0 && (
          <div className="ios-list max-h-64 overflow-y-auto">
            {availablePeople.map((name) => (
              <button
                key={name}
                onClick={() => {
                  setSelectedPerson(name);
                  setQuery(name);
                }}
                className={`ios-list-item w-full text-left ${
                  selectedPerson === name ? "bg-ios-blue/5" : ""
                }`}
              >
                <span className="text-ios-label">{name}</span>
                {selectedPerson === name && <Check className="w-5 h-5 text-ios-blue" />}
              </button>
            ))}
          </div>
        )}

        {/* Action Buttons */}
        <div className="flex gap-3 pt-2">
          <button
            onClick={onClose}
            className="flex-1 btn-ios-secondary py-3"
          >
            Cancel
          </button>
          <button
            onClick={handleAdd}
            disabled={!selectedPerson && !query.trim()}
            className="flex-1 btn-ios-primary py-3 disabled:opacity-50"
          >
            Add Recommendation
          </button>
        </div>
      </div>
    </Modal>
  );
}
