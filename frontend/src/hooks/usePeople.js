/**
 * usePeople hook
 * Manages people data from IndexedDB
 */

import { useState, useEffect } from 'react';
import { getAllPeople, savePerson, addToSyncQueue } from '../services/storage';
import { DEFAULT_RECOMMENDERS } from '../utils/constants';

export function usePeople() {
  const [people, setPeople] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Load people from IndexedDB
  const loadPeople = async () => {
    try {
      setLoading(true);
      let allPeople = await getAllPeople();
      
      // Initialize default recommenders if they don't exist
      const existingNames = new Set(allPeople.map(p => p.name));
      const missingDefaultRecs = DEFAULT_RECOMMENDERS.filter(
        defaultRec => !existingNames.has(defaultRec.name)
      );

      if (missingDefaultRecs.length > 0) {
        const results = await Promise.allSettled(
          missingDefaultRecs.map(defaultRec => 
            savePerson({
              name: defaultRec.name,
              is_trusted: false,
              is_default: true,
              color: defaultRec.color || '#0a84ff',
              emoji: defaultRec.emoji || null,
            })
          )
        );
        
        // Log any failures but continue
        const failed = results.filter(r => r.status === 'rejected');
        if (failed.length > 0) {
          console.warn(`Failed to initialize ${failed.length} default recommender(s)`);
        }
        
        allPeople = await getAllPeople();
      }
      
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
  const addPerson = async ({ name, isTrusted = false, color = '#0a84ff', emoji = null, isDefault = false }) => {
    try {
      const trimmedName = name?.trim();
      if (!trimmedName) {
        throw new Error('Name is required');
      }

      const person = {
        name: trimmedName,
        is_trusted: isTrusted,
        is_default: isDefault,
        color,
        emoji,
      };

      await savePerson(person);

      // Add to sync queue
      await addToSyncQueue('addPerson', {
        name: trimmedName,
        is_trusted: isTrusted,
        is_default: isDefault,
        color,
        emoji,
      });

      await loadPeople();
    } catch (err) {
      console.error('Error adding person:', err);
      throw err;
    }
  };

  const updatePerson = async (name, updates = {}) => {
    try {
      const person = people.find(p => p.name === name);
      if (!person) throw new Error('Person not found');

      const updatedPerson = { ...person, ...updates };
      await savePerson(updatedPerson);

      await addToSyncQueue('updatePerson', {
        name,
        ...updates,
      });

      await loadPeople();
    } catch (err) {
      console.error('Error updating person:', err);
      throw err;
    }
  };

  // Update person trust status
  const updateTrust = async (name, isTrusted) => {
    try {
      const person = people.find(p => p.name === name);
      if (!person) throw new Error('Person not found');

      await updatePerson(name, { is_trusted: isTrusted });
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
    updatePerson,
    updateTrust,
    getPeopleNames,
    getTrustedPeople,
  };
}
