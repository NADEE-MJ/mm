/**
 * SyncIndicator component
 * Shows sync status in the UI
 */

import { useSync } from '../hooks/useSync';
import { WifiOff, Cloud, CloudOff, AlertCircle, CheckCircle } from 'lucide-react';

export default function SyncIndicator() {
  const { syncStatus, triggerSync } = useSync();

  const getIcon = () => {
    switch (syncStatus.status) {
      case 'synced':
        return <CheckCircle className="w-5 h-5 text-green-500" />;
      case 'pending':
        return <Cloud className="w-5 h-5 text-yellow-500 animate-pulse" />;
      case 'conflict':
        return <AlertCircle className="w-5 h-5 text-orange-500" />;
      case 'offline':
        return <WifiOff className="w-5 h-5 text-gray-500" />;
      default:
        return <CloudOff className="w-5 h-5 text-gray-500" />;
    }
  };

  const getLabel = () => {
    switch (syncStatus.status) {
      case 'synced':
        return 'Synced';
      case 'pending':
        return `Syncing ${syncStatus.pending}...`;
      case 'conflict':
        return `${syncStatus.failed} failed`;
      case 'offline':
        return 'Offline';
      default:
        return 'Unknown';
    }
  };

  return (
    <button
      onClick={triggerSync}
      disabled={syncStatus.status === 'offline'}
      className="flex items-center gap-2 px-3 py-2 rounded-lg bg-gray-800 hover:bg-gray-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
      title="Click to sync now"
    >
      {getIcon()}
      <span className="text-sm font-medium">{getLabel()}</span>
    </button>
  );
}
