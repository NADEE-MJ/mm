import { useState, useEffect, useMemo, useRef } from "react";
import { Link, useLocation } from "react-router-dom";
import { Clapperboard, Users, Folder, UserCog, Plus } from "lucide-react";
import SyncIndicator from "../SyncIndicator";

export default function IOSTabBar({ onAddClick }) {
  const location = useLocation();
  const [sliderStyle, setSliderStyle] = useState({});
  const tabRefs = useRef([]);

  const tabs = [
    { path: "/", icon: Clapperboard, label: "Movies" },
    { path: "/people", icon: Users, label: "Recommenders" },
    { path: "/lists", icon: Folder, label: "Lists" },
    { path: "/account", icon: UserCog, label: "Account" },
  ];

  const activeTabIndex = useMemo(() => {
    // Don't change active tab when on stacked pages (add, movie detail, etc)
    if (location.pathname.startsWith("/add")) {
      // Keep the last main page highlighted (default to Movies)
      const lastMainTab = tabs.findIndex((tab) =>
        tab.path === "/" ? location.pathname === "/" : location.pathname.startsWith(tab.path),
      );
      return lastMainTab >= 0 ? lastMainTab : 0;
    }
    if (location.pathname.startsWith("/movie")) {
      return 0;
    }
    const index = tabs.findIndex((tab) =>
      tab.path === "/" ? location.pathname === "/" : location.pathname.startsWith(tab.path),
    );
    return index;
  }, [location.pathname]);

  useEffect(() => {
    const activeTab = tabRefs.current[activeTabIndex];
    if (activeTab) {
      const { offsetLeft, offsetWidth } = activeTab;
      setSliderStyle({
        left: `${offsetLeft}px`,
        width: `${offsetWidth}px`,
      });
    }
  }, [activeTabIndex]);

  return (
    <nav className="ios-tabbar">
      <div className="ios-tabbar-wrapper">
        <div className="ios-tabbar-container">
          {activeTabIndex >= 0 && <div className="ios-tabbar-slider" style={sliderStyle} />}
          {tabs.map((tab, index) => {
            const Icon = tab.icon;
            const isActive =
              tab.path === "/" ? location.pathname === "/" : location.pathname.startsWith(tab.path);

            return (
              <Link
                key={tab.path}
                to={tab.path}
                ref={(el) => (tabRefs.current[index] = el)}
                className={`ios-tabbar-item ${isActive ? "active" : ""} ${tab.label === "Account" ? "relative" : ""}`}
              >
                <Icon className="ios-tabbar-icon" />
                <span className="ios-tabbar-label">{tab.label}</span>
                {tab.label === "Account" && (
                  <div className="absolute top-0 right-1/4 z-10">
                    <SyncIndicator iconOnly={true} />
                  </div>
                )}
              </Link>
            );
          })}
        </div>
        {/* Add Button - Next to tab bar with gap */}
        <button onClick={onAddClick} className="ios-tabbar-add-button" aria-label="Add movie">
          <Plus className="w-6 h-6 md:w-7 md:h-7" strokeWidth={2.5} />
        </button>
      </div>
    </nav>
  );
}
