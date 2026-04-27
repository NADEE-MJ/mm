/**
 * usePeople hook
 * Server-backed people management for web clients.
 */

import { useState, useEffect, useCallback } from "react";
import api from "../services/api";

function getErrorMessage(err, fallback) {
  return err?.message || fallback;
}

export function usePeople() {
  const [people, setPeople] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const loadPeople = useCallback(async () => {
    try {
      setLoading(true);
      const serverPeople = await api.getPeople();
      setPeople(serverPeople || []);
      setError(null);
    } catch (err) {
      console.error("Error loading people:", err);
      setError(getErrorMessage(err, "Failed to load people"));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadPeople();
  }, [loadPeople]);

  useEffect(() => {
    const handleSyncEvent = (event) => {
      if (!event?.detail?.type || event.detail.type === "peopleUpdated") {
        loadPeople();
      }
    };

    window.addEventListener("mm-sync-event", handleSyncEvent);
    return () => {
      window.removeEventListener("mm-sync-event", handleSyncEvent);
    };
  }, [loadPeople]);

  const addPerson = useCallback(
    async ({
      name,
      isTrusted = false,
      color = "#0a84ff",
      emoji = null,
    }) => {
      const trimmedName = name?.trim();
      if (!trimmedName) {
        throw new Error("Name is required");
      }
      await api.addPerson(trimmedName, { isTrusted, color, emoji });
      await loadPeople();
    },
    [loadPeople],
  );

  const updatePerson = useCallback(
    async (name, updates = {}) => {
      if (!name) {
        throw new Error("Name is required");
      }
      await api.updatePerson(name, updates);
      await loadPeople();
    },
    [loadPeople],
  );

  const updateTrust = useCallback(
    async (name, isTrusted) => {
      await updatePerson(name, { is_trusted: isTrusted });
    },
    [updatePerson],
  );

  const getPeopleNames = useCallback(() => people.map((person) => person.name), [people]);
  const getTrustedPeople = useCallback(
    () => people.filter((person) => person.is_trusted),
    [people],
  );

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
