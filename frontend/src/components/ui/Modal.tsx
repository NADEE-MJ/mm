import { useEffect } from "react";
import { X } from "lucide-react";

export default function Modal({
  isOpen,
  onClose,
  title,
  children,
  maxWidth = "720px",
}) {
  useEffect(() => {
    if (!isOpen) {
      return undefined;
    }

    const handleEscape = (event) => {
      if (event.key === "Escape") {
        onClose();
      }
    };

    window.addEventListener("keydown", handleEscape);
    document.body.style.overflow = "hidden";

    return () => {
      window.removeEventListener("keydown", handleEscape);
      document.body.style.overflow = "";
    };
  }, [isOpen, onClose]);

  if (!isOpen) {
    return null;
  }

  return (
    <div className="app-modal-root" role="dialog" aria-modal="true" aria-label={title || "Dialog"}>
      <div className="app-modal-backdrop" onClick={onClose} />
      <div className="app-modal" style={{ maxWidth }}>
        {(title || onClose) && (
          <header className="app-modal-header">
            <h2 className="app-modal-title">{title}</h2>
            <button type="button" className="app-icon-button" onClick={onClose} aria-label="Close">
              <X className="w-4 h-4" />
            </button>
          </header>
        )}
        <div className="app-modal-content">{children}</div>
      </div>
    </div>
  );
}
