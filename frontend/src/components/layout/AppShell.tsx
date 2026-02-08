import { useMemo, useState } from "react";
import { useLocation } from "react-router-dom";
import { Plus, Menu } from "lucide-react";
import Sidebar from "./Sidebar";

function getPageTitle(pathname) {
  if (pathname.startsWith("/people/")) return "Person";
  if (pathname.startsWith("/people")) return "People";
  if (pathname.startsWith("/lists")) return "Lists";
  if (pathname.startsWith("/stats")) return "Stats";
  if (pathname.startsWith("/account")) return "Account";
  return "Movies";
}

export default function AppShell({ children, onAddMovie, panelOpen = false }) {
  const location = useLocation();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const pageTitle = useMemo(() => getPageTitle(location.pathname), [location.pathname]);

  return (
    <div className={`app-shell ${panelOpen ? "panel-open" : ""}`}>
      <div
        className={`app-sidebar-backdrop ${mobileOpen ? "open" : ""}`}
        onClick={() => setMobileOpen(false)}
      />

      <Sidebar
        collapsed={collapsed}
        mobileOpen={mobileOpen}
        onToggle={() => {
          if (window.innerWidth < 768) {
            setMobileOpen((prev) => !prev);
            return;
          }
          setCollapsed((prev) => !prev);
        }}
        onCloseMobile={() => setMobileOpen(false)}
      />

      <div className="app-main-column">
        <header className="app-topbar">
          <div className="app-topbar-inner">
            <button
              type="button"
              className="app-icon-button mobile-menu"
              onClick={() => setMobileOpen(true)}
              aria-label="Open navigation"
            >
              <Menu className="w-5 h-5" />
            </button>

            <h1 className="app-page-title">{pageTitle}</h1>

            <button type="button" className="app-add-button" onClick={onAddMovie}>
              <Plus className="w-4 h-4" />
              <span>Add Movie</span>
            </button>
          </div>
        </header>

        <main className="app-main-content">{children}</main>
      </div>
    </div>
  );
}
