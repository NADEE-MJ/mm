import { NavLink } from "react-router-dom";
import { Clapperboard, Users, List, BarChart3, UserCircle, Menu, PanelLeft } from "lucide-react";

const mainItems = [
  { to: "/", label: "Films", icon: Clapperboard, end: true },
  { to: "/people", label: "People", icon: Users },
  { to: "/lists", label: "Lists", icon: List },
  { to: "/stats", label: "Stats", icon: BarChart3 },
];

export default function Sidebar({ collapsed, mobileOpen, onToggle, onCloseMobile }) {
  const sidebarClasses = [
    "app-sidebar",
    collapsed ? "collapsed" : "expanded",
    mobileOpen ? "mobile-open" : "",
  ]
    .filter(Boolean)
    .join(" ");

  const renderLink = (item) => {
    const Icon = item.icon;
    return (
      <NavLink
        key={item.to}
        to={item.to}
        end={item.end}
        className={({ isActive }) =>
          `app-sidebar-link ${isActive ? "active" : ""} ${collapsed ? "icon-only" : ""}`
        }
        onClick={onCloseMobile}
      >
        <Icon className="w-4 h-4" />
        {!collapsed && <span>{item.label}</span>}
      </NavLink>
    );
  };

  return (
    <aside className={sidebarClasses}>
      <div className="app-sidebar-top">
        <button type="button" onClick={onToggle} className="app-sidebar-toggle" aria-label="Toggle sidebar">
          {collapsed ? <Menu className="w-5 h-5" /> : <PanelLeft className="w-5 h-5" />}
          {!collapsed && <span>MOVIES</span>}
        </button>
      </div>

      <nav className="app-sidebar-nav">{mainItems.map(renderLink)}</nav>

      <div className="app-sidebar-divider" />

      <nav className="app-sidebar-nav account">{renderLink({ to: "/account", label: "Account", icon: UserCircle })}</nav>
    </aside>
  );
}
