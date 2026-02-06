import { useEffect } from "react";
import { X } from "lucide-react";
import { useModalInstance } from "../../contexts/ModalContext";

export default function IOSSheet({ isOpen, onClose, title, children, modalId = "ios-sheet" }) {
  const { zIndex } = useModalInstance(modalId, isOpen);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0" style={{ zIndex }}>
      <div className="ios-sheet-backdrop" onClick={onClose} style={{ zIndex }} />
      <div className="ios-sheet ios-slide-up" style={{ zIndex: zIndex + 1 }}>
        <div className="ios-sheet-handle" />
        <div className="ios-sheet-header">
          <h3 className="ios-sheet-title">{title}</h3>
          <button onClick={onClose} className="ios-sheet-close">
            <X className="w-5 h-5" />
          </button>
        </div>
        <div className="ios-sheet-content">{children}</div>
      </div>
    </div>
  );
}
