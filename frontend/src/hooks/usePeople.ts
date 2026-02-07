/**
 * usePeople hook
 * Server-backed people management for web clients.
 */

import { useState, useEffect, useCallback } from "react";
import api from "../services/api";
import { DEFAULT_RECOMMENDERS } from "../utils/constants";

function mergeWithDefaults(serverPeople) {
  const merged = [...(serverPeople || [])];
  const existing = new Set(merged.map((person) => person.name));
  for (const rec of DEFAULT_RECOMMENDERS) {
    if (!existing.has(rec.name)) {
      merged.push({
        name: rec.name,
        is_trusted: false,
        is_default: true,
        color: rec.color || "#0a84ff",
        emoji: rec.emoji || null,
      });
    }
  }
  return merged;
}

export function usePeople() {
  const [people, setPeople] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const loadPeople = useCallback(async () => {
    try {
      setLoading(true);
      let serverPeople = await api.getPeople();
      const existing = new Set((serverPeople || []).map((person) => person.name));
      const missingDefaults = DEFAULT_RECOMMENDERS.filter((rec) => !existing.has(rec.name));

      if (missingDefaults.length > 0) {
        await Promise.all(
          missingDefaults.map((rec) =>
            api
              .addPerson(rec.name, {
                isTrusted: false,
                isDefault: true,
                color: rec.color || "#0a84ff",
                emoji: rec.emoji || null,
              })
              .catch(() => null),
          ),
        );
        serverPeople = await api.getPeople();
      }

      setPeople(mergeWithDefaults(serverPeople));
      setError(null);
    } catch (err) {
      console.error("Error loading people:", err);
      setError(err.message);
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

  const addPerson = async ({
    name,
    isTrusted = false,
    color = "#0a84ff",
    emoji = null,
    isDefault = false,
  }) => {
    const trimmedName = name?.trim();
    if (!trimmedName) {
      throw new Error("Name is required");
    }
    await api.addPerson(trimmedName, { isTrusted, color, emoji, isDefault });
    await loadPeople();
  };

  const updatePerson = async (name, updates = {}) => {
    if (!name) {
      throw new Error("Name is required");
    }
    await api.updatePerson(name, updates);
    await loadPeople();
  };

  const updateTrust = async (name, isTrusted) => {
    await updatePerson(name, { is_trusted: isTrusted });
  };

  const getPeopleNames = () => people.map((person) => person.name);
  const getTrustedPeople = () => people.filter((person) => person.is_trusted);

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
