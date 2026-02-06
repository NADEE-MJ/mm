import { apiClient, handleApiError } from './client';
import { SyncResponse, ServerSyncData, ApiResponse } from '../../types';

/**
 * Send sync action to server
 */
export async function sendSyncAction(
  action: string,
  data: any,
  timestamp: number
): Promise<SyncResponse> {
  try {
    const response = await apiClient.post<ApiResponse<SyncResponse>>('/sync', {
      action,
      data,
      timestamp,
    });

    return response.data.data;
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}

/**
 * Fetch changes from server since last sync
 */
export async function fetchServerChanges(
  since: number
): Promise<ServerSyncData> {
  try {
    const response = await apiClient.get<ApiResponse<ServerSyncData>>('/sync', {
      params: { since },
    });

    return response.data.data;
  } catch (error) {
    throw new Error(handleApiError(error));
  }
}
