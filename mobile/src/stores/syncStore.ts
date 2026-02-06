import { create } from 'zustand';
import { initSyncProcessor, forceSyncNow, getSyncStatus, processQueue } from '../services/sync/processor';
import { getPendingCount, getAllQueue } from '../services/sync/queue';

interface SyncState {
  isSyncing: boolean;
  lastSync: number;
  pendingCount: number;
  error: string | null;

  // Actions
  initSync: () => Promise<void>;
  triggerSync: () => Promise<void>;
  updateSyncStatus: () => Promise<void>;
  clearError: () => void;
}

export const useSyncStore = create<SyncState>((set, get) => ({
  isSyncing: false,
  lastSync: 0,
  pendingCount: 0,
  error: null,

  initSync: async () => {
    try {
      await initSyncProcessor();
      await get().updateSyncStatus();
      console.log('Sync initialized');
    } catch (error) {
      console.error('Failed to initialize sync:', error);
      set({
        error: error instanceof Error ? error.message : 'Failed to initialize sync',
      });
    }
  },

  triggerSync: async () => {
    set({ isSyncing: true, error: null });

    try {
      await forceSyncNow();
      await get().updateSyncStatus();
    } catch (error) {
      console.error('Sync failed:', error);
      set({
        error: error instanceof Error ? error.message : 'Sync failed',
      });
    } finally {
      set({ isSyncing: false });
    }
  },

  updateSyncStatus: async () => {
    try {
      const status = await getSyncStatus();
      set({
        lastSync: status.lastSync,
        pendingCount: status.pendingCount,
      });
    } catch (error) {
      console.error('Failed to update sync status:', error);
    }
  },

  clearError: () => set({ error: null }),
}));
