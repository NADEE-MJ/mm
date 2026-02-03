/**
 * usePeople hook
 * Manages people data from IndexedDB
 */

import { useState, useEffect } from 'react';
import { getAllPeople, savePerson, addToSyncQueue } from '../services/storage';

export function usePeople() {
  const [people, setPeople] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Load people from IndexedDB
  const loadPeople = async () => {
    try {
      setLoading(true);
      const allPeople = await getAllPeople();
      setPeople(allPeople);
      setError(null);
    } catch (err) {
      console.error('Error loading people:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadPeople();
  }, []);

  // Add a person
  const addPerson = async (name, isTrusted = false) => {
    try {
      const person = { name, is_trusted: isTrusted };
      await savePerson(person);

      // Add to sync queue
      await addToSyncQueue('addPerson', {
        name,
        is_trusted: isTrusted,
      });

      await loadPeople();
    } catch (err) {
      console.error('Error adding person:', err);
      throw err;
    }
  };

  // Update person trust status
  const updateTrust = async (name, isTrusted) => {
    try {
      const person = people.find(p => p.name === name);
      if (!person) throw new Error('Person not found');

      person.is_trusted = isTrusted;
      await savePerson(person);

      // Add to sync queue
      await addToSyncQueue('updatePersonTrust', {
        name,
        is_trusted: isTrusted,
      });

      await loadPeople();
    } catch (err) {
      console.error('Error updating trust:', err);
      throw err;
    }
  };

  // Get people names for autocomplete
  const getPeopleNames = () => {
    return people.map(p => p.name);
  };

  // Get trusted people
  const getTrustedPeople = () => {
    return people.filter(p => p.is_trusted);
  };

  return {
    people,
    loading,
    error,
    loadPeople,
    addPerson,
    updateTrust,
    getPeopleNames,
    getTrustedPeople,
  };
}
