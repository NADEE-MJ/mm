import { useState } from "react";
import { useLocation } from "react-router-dom";
import { Menu } from "lucide-react";
import Sidebar from "./Sidebar";

export default function AppShell({ children, panelOpen = false }) {
  const location = useLocation();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const isWideLayout =
    location.pathname === "/" ||
    location.pathname === "/people" ||
    location.pathname.startsWith("/lists");
  const hasDetailPanelInset =
    location.pathname === "/" || location.pathname.startsWith("/lists");
  const contentInsetClasses =
    panelOpen && hasDetailPanelInset
      ? "lg:pr-[min(520px,_42vw)] min-[1920px]:pr-[560px]"
      : "";

  return (
    <div className="flex min-h-screen">
      <div
        className={
          mobileOpen
            ? "fixed inset-0 z-[25] bg-black/45 md:hidden"
            : "hidden"
        }
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

      <div className="min-w-0 flex-1 flex flex-col">
        <button
          type="button"
          className="fixed left-3 top-3 z-24 hidden h-9 w-9 items-center justify-center rounded-[10px] border border-[var(--color-app-border)] bg-[rgba(12,12,12,0.82)] text-[var(--color-ios-label)] backdrop-blur-[8px] md:hidden"
          onClick={() => setMobileOpen(true)}
          aria-label="Open navigation"
        >
          <Menu className="w-5 h-5" />
        </button>

        <main
          className={`mx-auto w-full max-w-[1520px] px-4 pb-5 pt-4 min-[1280px]:px-6 min-[1600px]:px-8 max-md:pt-14 ${isWideLayout ? "max-w-none" : ""} ${contentInsetClasses}`}
        >
          {children}
        </main>
      </div>
    </div>
  );
}
