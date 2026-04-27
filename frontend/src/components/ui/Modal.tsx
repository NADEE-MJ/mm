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
    <div
      className="fixed inset-0 z-[80] flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
      aria-label={title || "Dialog"}
    >
      <div className="absolute inset-0 bg-black/60" onClick={onClose} />
      <div
        className="relative z-[1] flex max-h-[calc(100vh-2rem)] w-full flex-col overflow-hidden rounded-2xl border border-[var(--color-ios-separator)] bg-[#0f0f0f]"
        style={{ maxWidth }}
      >
        {(title || onClose) && (
          <header className="flex items-center justify-between gap-4 border-b border-[var(--color-ios-separator)] px-4 py-3.5">
            <h2 className="m-0 text-base font-bold">{title}</h2>
            <button
              type="button"
              className="inline-flex h-9 w-9 items-center justify-center rounded-[10px] bg-white/10"
              onClick={onClose}
              aria-label="Close"
            >
              <X className="w-4 h-4" />
            </button>
          </header>
        )}
        <div className="overflow-auto p-4">{children}</div>
      </div>
    </div>
  );
}
