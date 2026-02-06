import { ChevronRight } from "lucide-react";

export default function IOSHeader({ title, subtitle, rightContent, onBack }) {
  return (
    <header className="ios-header safe-area-top">
      <div className="ios-header-content">
        {onBack && (
          <button onClick={onBack} className="ios-header-back">
            <ChevronRight className="w-5 h-5 rotate-180" />
            <span>Back</span>
          </button>
        )}
        <div className="ios-header-title-group">
          <h1 className="ios-header-title">{title}</h1>
          {subtitle && <p className="ios-header-subtitle">{subtitle}</p>}
        </div>
        {rightContent && <div className="ios-header-right">{rightContent}</div>}
      </div>
    </header>
  );
}
