import { useState, useEffect, useMemo, useRef } from "react";
import { Link, useLocation } from "react-router-dom";
import { Film, Users, Folder, Plus } from "lucide-react";

export default function IOSTabBar({ onAddClick }) {
  const location = useLocation();
  const [sliderStyle, setSliderStyle] = useState({});
  const tabRefs = useRef([]);

  const tabs = [
    { path: "/", icon: Film, label: "Movies" },
    { path: "/people", icon: Users, label: "People" },
    { path: "/lists", icon: Folder, label: "Lists" },
  ];

  const activeTabIndex = useMemo(() => {
    const index = tabs.findIndex((tab) =>
      tab.path === "/" ? location.pathname === "/" : location.pathname.startsWith(tab.path),
    );
    return index >= 0 ? index : 0;
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
      <div className="ios-tabbar-container">
        <div className="ios-tabbar-slider" style={sliderStyle} />
        {tabs.map((tab, index) => {
          const Icon = tab.icon;
          const isActive =
            tab.path === "/" ? location.pathname === "/" : location.pathname.startsWith(tab.path);

          return (
            <Link
              key={tab.path}
              to={tab.path}
              ref={(el) => (tabRefs.current[index] = el)}
              className={`ios-tabbar-item ${isActive ? "active" : ""}`}
            >
              <Icon className="ios-tabbar-icon" />
              <span className="ios-tabbar-label">{tab.label}</span>
            </Link>
          );
        })}
        <button
          onClick={onAddClick}
          className="ios-tabbar-add-button"
          aria-label="Add movie"
        >
          <Plus className="w-6 h-6 md:w-7 md:h-7" strokeWidth={2.5} />
        </button>
      </div>
    </nav>
  );
}
