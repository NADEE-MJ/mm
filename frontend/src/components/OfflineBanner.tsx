/**
 * OfflineBanner - Shows when offline with pending sync items
 * Provides clear feedback about offline mode
 */

import { CloudOff, Wifi } from "lucide-react";
import { useSync } from "../hooks/useSync";
import { useState, useEffect } from "react";

export default function OfflineBanner() {
  const { syncStatus } = useSync();
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  const [showBanner, setShowBanner] = useState(false);

  useEffect(() => {
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);

    return () => {
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
    };
  }, []);

  useEffect(() => {
    // Show banner if offline OR if there are pending items
    setShowBanner(!isOnline || syncStatus.pendingCount > 0);
  }, [isOnline, syncStatus.pendingCount]);

  if (!showBanner) return null;

  return (
    <div
      className={`fixed top-0 left-0 right-0 z-50 px-4 py-2 text-center text-sm font-medium transition-colors ${
        !isOnline
          ? "bg-ios-orange text-white"
          : "bg-ios-blue/10 text-ios-blue"
      }`}
    >
      <div className="flex items-center justify-center gap-2">
        {!isOnline ? (
          <>
            <CloudOff className="w-4 h-4" />
            <span>
              Offline - Changes will sync when online
              {syncStatus.pendingCount > 0 && ` (${syncStatus.pendingCount} pending)`}
            </span>
          </>
        ) : (
          <>
            <Wifi className="w-4 h-4" />
            <span>
              Syncing {syncStatus.pendingCount} change{syncStatus.pendingCount !== 1 ? "s" : ""}...
            </span>
          </>
        )}
      </div>
    </div>
  );
}
