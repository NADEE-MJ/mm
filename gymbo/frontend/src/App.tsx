import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import AuthScreen from "./components/AuthScreen";
import AppShell from "./components/layout/AppShell";
import { useAuth } from "./contexts/AuthContext";
import AccountPage from "./pages/AccountPage";
import ActiveSessionPage from "./pages/ActiveSessionPage";
import AdminPage from "./pages/AdminPage";
import DashboardPage from "./pages/DashboardPage";
import ExercisesPage from "./pages/ExercisesPage";
import HistoryPage from "./pages/HistoryPage";
import LogPage from "./pages/LogPage";
import MetricsPage from "./pages/MetricsPage";
import SchedulePage from "./pages/SchedulePage";
import TemplatesPage from "./pages/TemplatesPage";

function ProtectedApp() {
  return (
    <AppShell>
      <Routes>
        <Route path="/" element={<DashboardPage />} />
        <Route path="/log" element={<LogPage />} />
        <Route path="/log/:sessionId" element={<ActiveSessionPage />} />
        <Route path="/history" element={<HistoryPage />} />
        <Route path="/exercises" element={<ExercisesPage />} />
        <Route path="/templates" element={<TemplatesPage />} />
        <Route path="/schedule" element={<SchedulePage />} />
        <Route path="/metrics" element={<MetricsPage />} />
        <Route path="/account" element={<AccountPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AppShell>
  );
}

function Root() {
  const { isAuthenticated, isLoading } = useAuth();

  if (isLoading) {
    return <div className="p-6">Loading...</div>;
  }

  if (!isAuthenticated) {
    return <AuthScreen />;
  }

  return <ProtectedApp />;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/admin" element={<AdminPage />} />
        <Route path="/*" element={<Root />} />
      </Routes>
    </BrowserRouter>
  );
}
