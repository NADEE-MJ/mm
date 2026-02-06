import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.jsx";
import { AuthProvider } from "./contexts/AuthContext";
import { registerSW } from "virtual:pwa-register";

// Register service worker for PWA functionality
const updateSW = registerSW({
  onNeedRefresh() {
    console.log("[PWA] New content available, reload to update");
    // You could show a toast/banner here asking user to reload
  },
  onOfflineReady() {
    console.log("[PWA] App ready to work offline");
  },
  onRegistered(registration) {
    console.log("[PWA] Service Worker registered");

    // Listen for messages from service worker
    navigator.serviceWorker.addEventListener("message", (event) => {
      if (event.data && event.data.type === "SYNC_REQUESTED") {
        // Dispatch custom event for the app to handle
        window.dispatchEvent(new CustomEvent("sw-sync-requested"));
      }
    });
  },
  onRegisterError(error) {
    console.error("[PWA] Service Worker registration error", error);
  },
});

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <AuthProvider>
      <App />
    </AuthProvider>
  </StrictMode>,
);
