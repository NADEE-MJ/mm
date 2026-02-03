/**
 * PeopleManager component
 * Manage people and their trust status
 */

import { useState } from 'react';
import { Users, Star, StarOff } from 'lucide-react';
import { usePeople } from '../hooks/usePeople';

export default function PeopleManager({ movies }) {
  const { people, updateTrust } = usePeople();
  const [filter, setFilter] = useState('all'); // all, trusted, untrusted

  // Calculate recommendation counts
  const getRecommendationCount = (personName) => {
    return movies.filter(movie =>
      movie.recommendations?.some(rec => rec.person === personName)
    ).length;
  };

  const filteredPeople = people.filter(person => {
    if (filter === 'trusted') return person.is_trusted;
    if (filter === 'untrusted') return !person.is_trusted;
    return true;
  });

  const handleToggleTrust = async (person) => {
    try {
      await updateTrust(person.name, !person.is_trusted);
    } catch (err) {
      console.error('Error toggling trust:', err);
    }
  };

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold flex items-center gap-2">
          <Users className="w-6 h-6" />
          People
        </h2>

        {/* Filter */}
        <div className="flex gap-2">
          <button
            onClick={() => setFilter('all')}
            className={`px-3 py-1 rounded ${
              filter === 'all'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
            }`}
          >
            All
          </button>
          <button
            onClick={() => setFilter('trusted')}
            className={`px-3 py-1 rounded ${
              filter === 'trusted'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
            }`}
          >
            Trusted
          </button>
          <button
            onClick={() => setFilter('untrusted')}
            className={`px-3 py-1 rounded ${
              filter === 'untrusted'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
            }`}
          >
            Untrusted
          </button>
        </div>
      </div>

      {/* People List */}
      {filteredPeople.length === 0 ? (
        <div className="card text-center text-gray-400 py-8">
          <Users className="w-12 h-12 mx-auto mb-2 opacity-50" />
          <p>No people found</p>
        </div>
      ) : (
        <div className="space-y-2">
          {filteredPeople.map(person => (
            <div
              key={person.name}
              className="card flex items-center justify-between"
            >
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <h3 className="text-lg font-medium">{person.name}</h3>
                  {person.is_trusted && (
                    <Star className="w-5 h-5 text-yellow-500 fill-current" />
                  )}
                </div>
                <p className="text-sm text-gray-400">
                  {getRecommendationCount(person.name)} recommendations
                </p>
              </div>

              <button
                onClick={() => handleToggleTrust(person)}
                className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                  person.is_trusted
                    ? 'bg-yellow-600 hover:bg-yellow-700 text-white'
                    : 'bg-gray-700 hover:bg-gray-600 text-gray-300'
                }`}
              >
                {person.is_trusted ? (
                  <span className="flex items-center gap-2">
                    <StarOff className="w-4 h-4" />
                    Untrust
                  </span>
                ) : (
                  <span className="flex items-center gap-2">
                    <Star className="w-4 h-4" />
                    Trust
                  </span>
                )}
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
