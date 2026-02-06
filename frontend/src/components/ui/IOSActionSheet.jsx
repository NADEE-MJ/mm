import { useModalInstance } from "../../contexts/ModalContext";

export default function IOSActionSheet({ isOpen, onClose, actions, modalId = "ios-action-sheet" }) {
  const { zIndex } = useModalInstance(modalId, isOpen);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 flex items-end justify-center" style={{ zIndex }}>
      <div className="ios-sheet-backdrop" onClick={onClose} style={{ zIndex }} />
      <div className="ios-action-sheet ios-slide-up" style={{ zIndex: zIndex + 1 }}>
        <div className="ios-action-group">
          {actions.map((action, idx) => (
            <button
              key={idx}
              onClick={() => {
                action.onClick();
                onClose();
              }}
              className={`ios-action-item ${action.destructive ? "destructive" : ""}`}
            >
              {action.icon && <action.icon className="w-5 h-5" />}
              <span>{action.label}</span>
            </button>
          ))}
        </div>
        <button onClick={onClose} className="ios-action-cancel">
          Cancel
        </button>
      </div>
    </div>
  );
}
