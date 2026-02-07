import { getToken } from '../auth/secure-storage';
import { API_CONFIG } from '../../utils/constants';

type ChangeHandler = (eventType: string) => void;

let socket: WebSocket | null = null;
let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

function getWsUrl(token: string): string {
  const trimmed = API_CONFIG.BASE_URL.replace(/\/$/, '');
  const wsBase = trimmed
    .replace(/^https:\/\//, 'wss://')
    .replace(/^http:\/\//, 'ws://')
    .replace(/\/api$/, '');
  return `${wsBase}/ws/sync?token=${encodeURIComponent(token)}`;
}

export async function startSyncWebSocket(onServerChange: ChangeHandler): Promise<void> {
  if (socket) return;
  const token = await getToken();
  if (!token) return;

  socket = new WebSocket(getWsUrl(token));

  socket.onmessage = (event) => {
    try {
      const payload = JSON.parse(event.data);
      const eventType = payload?.type;
      if (
        eventType === 'movieUpdated' ||
        eventType === 'movieAdded' ||
        eventType === 'movieDeleted' ||
        eventType === 'peopleUpdated' ||
        eventType === 'listUpdated'
      ) {
        onServerChange(eventType);
      }
    } catch (error) {
      console.warn('Invalid sync websocket payload', error);
    }
  };

  socket.onclose = () => {
    socket = null;
    if (!reconnectTimer) {
      reconnectTimer = setTimeout(() => {
        reconnectTimer = null;
        startSyncWebSocket(onServerChange).catch((err) =>
          console.warn('WebSocket reconnect failed', err)
        );
      }, 5000);
    }
  };

  socket.onerror = (error) => {
    console.warn('Sync websocket error', error);
  };
}

export function stopSyncWebSocket(): void {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
  if (socket) {
    socket.close();
    socket = null;
  }
}

