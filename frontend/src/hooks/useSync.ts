/**
 * useSync hook
 * WebSocket-driven sync status for web clients.
 */

import { useState, useEffect, useCallback, useRef } from "react";
import { getAuthToken } from "../contexts/AuthContext";

const WS_RECONNECT_DELAY = 5000;

function buildWebSocketUrl(token) {
  const base = (import.meta.env.VITE_API_URL || window.location.origin).replace(/\/$/, "");
  const protocol = base.startsWith("https") ? "wss" : "ws";
  const wsBase = base.replace(/^https?/, protocol).replace(/\/api$/, "");
  return `${wsBase}/ws/sync?token=${encodeURIComponent(token)}`;
}

export function useSync() {
  const reconnectRef = useRef(null);
  const socketRef = useRef(null);
  const connectSocketRef = useRef(() => {});
  const [syncStatus, setSyncStatus] = useState({
    status: "synced",
    pending: 0,
    failed: 0,
    retrying: 0,
    pendingCount: 0,
    failedCount: 0,
    isOnline: navigator.onLine,
    isProcessing: false,
    isSyncingFromServer: false,
    isRealtimeConnected: false,
    queueItems: [],
    lastSync: 0,
  });

  const updateOnlineStatus = useCallback(() => {
    setSyncStatus((prev) => ({
      ...prev,
      isOnline: navigator.onLine,
      status: navigator.onLine ? prev.status : "offline",
    }));
  }, []);

  const closeSocket = useCallback(() => {
    if (reconnectRef.current) {
      clearTimeout(reconnectRef.current);
      reconnectRef.current = null;
    }
    if (socketRef.current) {
      try {
        socketRef.current.close();
      } catch (error) {
        console.warn("Error closing sync socket", error);
      }
      socketRef.current = null;
    }
  }, []);

  const connectSocket = useCallback(() => {
    if (!navigator.onLine || socketRef.current) {
      return;
    }
    const token = getAuthToken();
    if (!token) {
      return;
    }

    try {
      socketRef.current = new WebSocket(buildWebSocketUrl(token));
    } catch (error) {
      console.error("Failed to connect WebSocket:", error);
      return;
    }

    socketRef.current.onopen = () => {
      setSyncStatus((prev) => ({
        ...prev,
        status: "synced",
        isRealtimeConnected: true,
      }));
    };

    socketRef.current.onmessage = (event) => {
      try {
        const payload = JSON.parse(event.data);
        const eventType = payload?.type;
        if (
          eventType === "movieAdded" ||
          eventType === "movieUpdated" ||
          eventType === "movieDeleted" ||
          eventType === "peopleUpdated" ||
          eventType === "listUpdated"
        ) {
          window.dispatchEvent(new CustomEvent("mm-sync-event", { detail: payload }));
          setSyncStatus((prev) => ({
            ...prev,
            status: "synced",
            isRealtimeConnected: true,
            lastSync: Date.now(),
          }));
        }
      } catch (error) {
        console.warn("Invalid WebSocket payload", error);
      }
    };

    socketRef.current.onclose = () => {
      socketRef.current = null;
      setSyncStatus((prev) => ({
        ...prev,
        isRealtimeConnected: false,
        status: navigator.onLine ? "synced" : "offline",
      }));
      if (navigator.onLine && !reconnectRef.current) {
        reconnectRef.current = setTimeout(() => {
          reconnectRef.current = null;
          connectSocketRef.current();
        }, WS_RECONNECT_DELAY);
      }
    };

    socketRef.current.onerror = (error) => {
      console.warn("WebSocket sync error:", error);
    };
  }, []);

  useEffect(() => {
    connectSocketRef.current = connectSocket;
  }, [connectSocket]);

  useEffect(() => {
    connectSocket();

    const handleOnline = () => {
      updateOnlineStatus();
      connectSocket();
    };
    const handleOffline = () => {
      updateOnlineStatus();
      closeSocket();
    };

    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);

    return () => {
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
      closeSocket();
    };
  }, [closeSocket, connectSocket, updateOnlineStatus]);

  const updateStatus = useCallback(async () => {
    updateOnlineStatus();
    setSyncStatus((prev) => ({
      ...prev,
      status: navigator.onLine ? "synced" : "offline",
      pending: 0,
      failed: 0,
      retrying: 0,
      pendingCount: 0,
      failedCount: 0,
      isProcessing: false,
      isSyncingFromServer: false,
      queueItems: [],
    }));
  }, [updateOnlineStatus]);

  const triggerSync = useCallback(async () => {
    window.dispatchEvent(new CustomEvent("mm-force-refresh"));
    setSyncStatus((prev) => ({ ...prev, status: "synced", lastSync: Date.now() }));
    return { success: true };
  }, []);

  const retryFailed = useCallback(async () => {}, []);
  const clearFailed = useCallback(async () => {}, []);

  return {
    syncStatus,
    updateStatus,
    triggerSync,
    retryFailed,
    clearFailed,
  };
}
