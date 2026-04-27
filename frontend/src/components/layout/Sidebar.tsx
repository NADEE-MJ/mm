import { Dumbbell, CalendarDays, ChartNoAxesCombined, Clock3, Home, ListChecks, UserCircle } from "lucide-react";
import { NavLink } from "react-router-dom";

const items = [
  { to: "/", label: "Dashboard", icon: Home, end: true },
  { to: "/log", label: "Log Workout", icon: Dumbbell },
  { to: "/history", label: "History", icon: Clock3 },
  { to: "/exercises", label: "Exercises", icon: ListChecks },
  { to: "/templates", label: "Templates", icon: ListChecks },
  { to: "/schedule", label: "Schedule", icon: CalendarDays },
  { to: "/metrics", label: "Metrics", icon: ChartNoAxesCombined },
  { to: "/account", label: "Account", icon: UserCircle },
];

export default function Sidebar() {
  return (
    <aside className="w-64 border-r border-[var(--color-app-border)] bg-[rgba(16,16,16,0.92)] p-3 hidden md:block">
      <div className="mb-4 px-2 py-3 text-lg font-semibold text-[var(--color-ios-label)]">Gymbo</div>
      <nav className="flex flex-col gap-1">
        {items.map((item) => {
          const Icon = item.icon;
          return (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) =>
                `inline-flex min-h-[42px] items-center gap-2.5 rounded-[10px] px-2.5 text-[0.92rem] font-semibold text-[var(--color-app-text-secondary)] transition-colors ${
                  isActive ? "bg-[rgba(10,132,255,0.20)] text-[var(--color-ios-blue)]" : ""
                }`
              }
            >
              <Icon className="h-5 w-5" />
              <span>{item.label}</span>
            </NavLink>
          );
        })}
      </nav>
    </aside>
  );
}
