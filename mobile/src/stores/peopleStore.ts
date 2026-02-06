import { create } from 'zustand';
import { Person } from '../types';
import * as peopleStorage from '../services/storage/people';
import { addToQueue } from '../services/sync/queue';

interface PeopleState {
  people: Person[];
  isLoading: boolean;
  error: string | null;

  // Actions
  loadPeople: () => Promise<void>;
  getPerson: (name: string) => Promise<Person | null>;
  addPerson: (
    name: string,
    userId: string,
    isTrusted?: boolean,
    isDefault?: boolean,
    color?: string,
    emoji?: string
  ) => Promise<void>;
  updatePerson: (
    name: string,
    updates: {
      is_trusted?: boolean;
      is_default?: boolean;
      color?: string;
      emoji?: string;
    }
  ) => Promise<void>;
  deletePerson: (name: string) => Promise<void>;
  getPersonStats: (name: string) => Promise<any>;
  clearError: () => void;
}

export const usePeopleStore = create<PeopleState>((set, get) => ({
  people: [],
  isLoading: false,
  error: null,

  loadPeople: async () => {
    set({ isLoading: true, error: null });

    try {
      const people = await peopleStorage.getAllPeople();
      set({ people, isLoading: false });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to load people',
        isLoading: false,
      });
    }
  },

  getPerson: async (name: string) => {
    try {
      return await peopleStorage.getPerson(name);
    } catch (error) {
      console.error('Failed to get person:', error);
      return null;
    }
  },

  addPerson: async (
    name: string,
    userId: string,
    isTrusted: boolean = false,
    isDefault: boolean = false,
    color: string = '#0a84ff',
    emoji?: string
  ) => {
    try {
      // Optimistic update
      await peopleStorage.savePerson(name, userId, isTrusted, isDefault, color, emoji);

      // Reload people
      await get().loadPeople();

      // Queue sync action
      await addToQueue('addPerson', {
        name,
        is_trusted: isTrusted,
        is_default: isDefault,
        color,
        emoji,
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to add person',
      });
      throw error;
    }
  },

  updatePerson: async (
    name: string,
    updates: {
      is_trusted?: boolean;
      is_default?: boolean;
      color?: string;
      emoji?: string;
    }
  ) => {
    try {
      // Optimistic update
      await peopleStorage.updatePerson(name, updates);

      // Reload people
      await get().loadPeople();

      // Queue sync action
      await addToQueue('updatePerson', {
        name,
        ...updates,
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to update person',
      });
      throw error;
    }
  },

  deletePerson: async (name: string) => {
    try {
      // Optimistic update
      await peopleStorage.deletePerson(name);

      // Reload people
      await get().loadPeople();

      // Queue sync action
      await addToQueue('deletePerson', { name });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to delete person',
      });
      throw error;
    }
  },

  getPersonStats: async (name: string) => {
    try {
      return await peopleStorage.getPersonStats(name);
    } catch (error) {
      console.error('Failed to get person stats:', error);
      return null;
    }
  },

  clearError: () => set({ error: null }),
}));
