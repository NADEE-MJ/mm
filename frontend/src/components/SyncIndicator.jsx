/**
 * SyncIndicator component - iOS Style
 * Shows sync status in the UI
 */

import { useState } from "react";
import { useSync } from "../hooks/useSync";
import {
  WifiOff,
  Cloud,
  CloudOff,
  AlertTriangle,
  CheckCircle,
  RefreshCw,
  X,
  RotateCcw,
  Trash2,
} from "lucide-react";

export default function SyncIndicator() {
  const { syncStatus, triggerSync, retryFailed, clearFailed } = useSync();
  const [showDetails, setShowDetails] = useState(false);
  const [isSyncing, setIsSyncing] = useState(false);

  const handleSync = async () => {
    setIsSyncing(true);
    try {
      await triggerSync();
    } finally {
      setIsSyncing(false);
    }
  };

  const getStatusConfig = () => {
    if (isSyncing || syncStatus.isProcessing || syncStatus.isSyncingFromServer) {
      return { icon: RefreshCw, color: "text-ios-blue", spin: true, label: "Syncing..." };
    }

    switch (syncStatus.status) {
      case "synced":
        return { icon: CheckCircle, color: "text-ios-green", spin: false, label: "Synced" };
      case "syncing":
        return { icon: RefreshCw, color: "text-ios-blue", spin: true, label: "Syncing..." };
      case "retrying":
        return { icon: RefreshCw, color: "text-ios-orange", spin: true, label: "Retrying..." };
      case "error":
        return { icon: AlertTriangle, color: "text-ios-red", spin: false, label: "Error" };
      case "offline":
        return { icon: WifiOff, color: "text-ios-gray", spin: false, label: "Offline" };
      default:
        return { icon: CloudOff, color: "text-ios-gray", spin: false, label: "Unknown" };
    }
  };

  const config = getStatusConfig();
  const Icon = config.icon;

  const hasPendingItems = syncStatus.pendingCount > 0;
  const hasFailedItems = syncStatus.failedCount > 0;

  return (
    <>
      <button
        onClick={() => setShowDetails(true)}
        className="relative ios-icon-button"
        title={config.label}
      >
        <Icon className={`w-5 h-5 ${config.color} ${config.spin ? "animate-spin" : ""}`} />
        {(hasPendingItems || hasFailedItems) && (
          <span className="absolute -top-1 -right-1 w-4 h-4 bg-ios-red text-white text-[10px] font-bold rounded-full flex items-center justify-center">
            {syncStatus.pendingCount + syncStatus.failedCount}
          </span>
        )}
      </button>

      {/* Details Sheet */}
      {showDetails && (
        <div className="fixed inset-0 z-50">
          <div className="ios-sheet-backdrop" onClick={() => setShowDetails(false)} />
          <div className="ios-sheet ios-slide-up">
            <div className="ios-sheet-handle" />
            <div className="ios-sheet-header">
              <h3 className="ios-sheet-title">Sync Status</h3>
              <button onClick={() => setShowDetails(false)} className="ios-sheet-close">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="ios-sheet-content">
              {/* Status Card */}
              <div className="ios-card p-4 mb-6">
                <div className="flex items-center gap-4">
                  <div
                    className={`w-12 h-12 rounded-full flex items-center justify-center ${
                      syncStatus.status === "synced"
                        ? "bg-ios-green/20"
                        : syncStatus.status === "error"
                          ? "bg-ios-red/20"
                          : "bg-ios-blue/20"
                    }`}
                  >
                    <Icon
                      className={`w-6 h-6 ${config.color} ${config.spin ? "animate-spin" : ""}`}
                    />
                  </div>
                  <div>
                    <p className="text-ios-headline font-semibold text-ios-label">{config.label}</p>
                    <p className="text-ios-caption1 text-ios-secondary-label">
                      {syncStatus.lastSync
                        ? `Last synced ${new Date(syncStatus.lastSync).toLocaleTimeString()}`
                        : "Never synced"}
                    </p>
                  </div>
                </div>
              </div>

              {/* Stats */}
              <div className="grid grid-cols-2 gap-3 mb-6">
                <div className="ios-card p-4 text-center">
                  <p className="text-ios-title2 font-bold text-ios-orange">
                    {syncStatus.pendingCount}
                  </p>
                  <p className="text-ios-caption2 text-ios-secondary-label">Pending</p>
                </div>
                <div className="ios-card p-4 text-center">
                  <p className="text-ios-title2 font-bold text-ios-red">{syncStatus.failedCount}</p>
                  <p className="text-ios-caption2 text-ios-secondary-label">Failed</p>
                </div>
              </div>

              {/* Actions */}
              <div className="space-y-3">
                <button
                  onClick={handleSync}
                  disabled={isSyncing || syncStatus.isProcessing}
                  className="w-full btn-ios-primary py-3.5"
                >
                  <RefreshCw className={`w-5 h-5 mr-2 ${isSyncing ? "animate-spin" : ""}`} />
                  {isSyncing ? "Syncing..." : "Sync Now"}
                </button>

                {hasFailedItems && (
                  <>
                    <button onClick={retryFailed} className="w-full btn-ios-secondary py-3">
                      <RotateCcw className="w-5 h-5 mr-2" />
                      Retry Failed ({syncStatus.failedCount})
                    </button>
                    <button onClick={clearFailed} className="w-full py-3 text-ios-red font-medium">
                      <Trash2 className="w-5 h-5 mr-2 inline" />
                      Clear Failed Items
                    </button>
                  </>
                )}
              </div>

              {/* Connection Status */}
              <div className="mt-6 text-center">
                <p className="text-ios-caption1 text-ios-tertiary-label">
                  {navigator.onLine ? (
                    <span className="flex items-center justify-center gap-2">
                      <span className="w-2 h-2 bg-ios-green rounded-full" />
                      Connected
                    </span>
                  ) : (
                    <span className="flex items-center justify-center gap-2">
                      <span className="w-2 h-2 bg-ios-red rounded-full" />
                      Offline - changes will sync when online
                    </span>
                  )}
                </p>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
