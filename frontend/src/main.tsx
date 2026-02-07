import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App";
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
  onRegistered() {
    console.log("[PWA] Service Worker registered");
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
