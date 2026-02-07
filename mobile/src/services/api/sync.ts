import { apiClient, handleApiError } from './client';
import { SyncResponse, ServerSyncData, BatchSyncResponse } from '../../types';

/**
 * Send sync action to server
 */
export async function sendSyncAction(
  action: string,
  data: any,
  timestamp: number
): Promise<SyncResponse> {
  try {
    const response = await apiClient.post<SyncResponse>('/sync', {
      action,
      data,
      timestamp,
    });

    return response.data;
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

export async function sendBatchSync(
  actions: Array<{ action: string; data: any; timestamp: number }>
): Promise<BatchSyncResponse> {
  try {
    const response = await apiClient.post<BatchSyncResponse>('/sync/batch', {
      actions,
      client_timestamp: Date.now(),
    });
    return response.data;
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Fetch changes from server since last sync
 */
export async function fetchServerChanges(
  since: number,
  limit: number = 100,
  offset: number = 0
): Promise<ServerSyncData> {
  try {
    const response = await apiClient.get<ServerSyncData>('/sync/changes', {
      params: { since, limit, offset },
    });

    return response.data;
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}
