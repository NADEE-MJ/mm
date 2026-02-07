import { create } from 'zustand';
import { CustomList } from '../types';
import * as listsStorage from '../services/storage/lists';
import { addToQueue } from '../services/sync/queue';

interface ListsState {
  lists: CustomList[];
  isLoading: boolean;
  error: string | null;

  // Actions
  loadLists: () => Promise<void>;
  getList: (id: string) => Promise<CustomList | null>;
  createList: (
    id: string,
    userId: string,
    name: string,
    color?: string,
    icon?: string,
    position?: number
  ) => Promise<void>;
  updateList: (
    id: string,
    updates: {
      name?: string;
      color?: string;
      icon?: string;
      position?: number;
    }
  ) => Promise<void>;
  deleteList: (id: string) => Promise<void>;
  getListMovieCount: (listId: string) => Promise<number>;
  clearError: () => void;
}

export const useListsStore = create<ListsState>((set, get) => ({
  lists: [],
  isLoading: false,
  error: null,

  loadLists: async () => {
    set({ isLoading: true, error: null });

    try {
      const lists = await listsStorage.getAllLists();
      set({ lists, isLoading: false });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to load lists',
        isLoading: false,
      });
    }
  },

  getList: async (id: string) => {
    try {
      return await listsStorage.getList(id);
    } catch (error) {
      console.error('Failed to get list:', error);
      return null;
    }
  },

  createList: async (
    id: string,
    userId: string,
    name: string,
    color: string = '#DBA506',
    icon: string = 'list',
    position: number = 0
  ) => {
    try {
      // Optimistic update
      await listsStorage.createList(id, userId, name, color, icon, position);

      // Reload lists
      await get().loadLists();

      // Queue sync action
      await addToQueue('addList', {
        id,
        name,
        color,
        icon,
        position,
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to create list',
      });
      throw error;
    }
  },

  updateList: async (
    id: string,
    updates: {
      name?: string;
      color?: string;
      icon?: string;
      position?: number;
    }
  ) => {
    try {
      // Optimistic update
      await listsStorage.updateList(id, updates);

      // Reload lists
      await get().loadLists();

      // Queue sync action
      await addToQueue('updateList', {
        id,
        ...updates,
      });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to update list',
      });
      throw error;
    }
  },

  deleteList: async (id: string) => {
    try {
      // Optimistic update
      await listsStorage.deleteList(id);

      // Reload lists
      await get().loadLists();

      // Queue sync action
      await addToQueue('deleteList', { id });
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : 'Failed to delete list',
      });
      throw error;
    }
  },

  getListMovieCount: async (listId: string) => {
    try {
      return await listsStorage.getListMovieCount(listId);
    } catch (error) {
      console.error('Failed to get list movie count:', error);
      return 0;
    }
  },

  clearError: () => set({ error: null }),
}));
