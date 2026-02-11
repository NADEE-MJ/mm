import { NavLink } from "react-router-dom";
import { Clapperboard, Users, List, UserCircle, Menu, PanelLeft } from "lucide-react";

const mainItems = [
  { to: "/", label: "Movies", icon: Clapperboard, end: true },
  { to: "/people", label: "People", icon: Users },
  { to: "/lists", label: "Lists", icon: List },
];

export default function Sidebar({ collapsed, mobileOpen, onToggle, onCloseMobile }) {
  const sidebarClasses = [
    "z-30 flex flex-col gap-2 overflow-hidden border-r border-[var(--color-app-border)] bg-[rgba(16,16,16,0.95)] py-3 transition-[width,transform] duration-200 ease-out max-md:fixed max-md:bottom-0 max-md:left-0 max-md:top-0 max-md:w-60 max-md:shadow-[0_16px_30px_rgba(0,0,0,0.5)]",
    collapsed ? "w-16 px-2" : "w-60 px-3",
    mobileOpen ? "max-md:translate-x-0" : "max-md:-translate-x-full",
  ].join(" ");

  const renderLink = (item) => {
    const Icon = item.icon;
    return (
      <NavLink
        key={item.to}
        to={item.to}
        end={item.end}
        className={({ isActive }) =>
          `inline-flex min-h-[42px] items-center gap-2.5 rounded-[10px] px-2.5 text-[0.92rem] font-semibold text-[var(--color-app-text-secondary)] transition-colors ${
            isActive
              ? "bg-[rgba(219,165,6,0.16)] text-[var(--color-ios-yellow)] shadow-[inset_2px_0_0_var(--color-ios-yellow)]"
              : ""
          } ${collapsed ? "justify-center px-0" : ""}`
        }
        onClick={onCloseMobile}
      >
        <Icon className="w-[20px] h-[20px]" />
        {!collapsed && <span>{item.label}</span>}
      </NavLink>
    );
  };

  return (
    <aside className={sidebarClasses}>
      <div className="flex min-h-[42px] items-center">
        <button
          type="button"
          onClick={onToggle}
          className={`inline-flex w-full items-center gap-2 rounded-[10px] bg-white/5 p-[0.55rem] text-[0.78rem] font-extrabold tracking-[0.06em] text-[var(--color-ios-label)] ${collapsed ? "justify-center" : ""}`}
          aria-label="Toggle sidebar"
        >
          {collapsed ? <Menu className="w-[24px] h-[24px]" /> : <PanelLeft className="w-[24px] h-[24px]" />}
          {!collapsed && <span>Collapse</span>}
        </button>
      </div>

      <nav className="flex flex-col gap-1">{mainItems.map(renderLink)}</nav>

      <div className="my-2 border-t border-[var(--color-ios-separator)]" />

      <nav className="mt-auto flex flex-col gap-1">
        {renderLink({ to: "/account", label: "Account", icon: UserCircle })}
      </nav>
    </aside>
  );
}
