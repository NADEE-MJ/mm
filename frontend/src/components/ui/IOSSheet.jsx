import { useEffect, useRef, useState } from "react";
import { X } from "lucide-react";
import { useModalInstance } from "../../contexts/ModalContext";

export default function IOSSheet({ isOpen, onClose, title, children, modalId = "ios-sheet" }) {
  const { zIndex } = useModalInstance(modalId, isOpen);
  const sheetRef = useRef(null);
  const backdropRef = useRef(null);
  const [isDragging, setIsDragging] = useState(false);
  const [isClosing, setIsClosing] = useState(false);
  const [startY, setStartY] = useState(0);
  const [currentY, setCurrentY] = useState(0);

  // Handle animated close
  const handleAnimatedClose = () => {
    if (isClosing) return;

    setIsClosing(true);
    const sheet = sheetRef.current;
    const backdrop = backdropRef.current;

    if (sheet) {
      sheet.style.transition = "transform 0.3s ease-out";
      sheet.style.transform = "translateY(100%)";
    }
    if (backdrop) {
      backdrop.style.transition = "opacity 0.3s ease-out";
      backdrop.style.opacity = "0";
    }

    setTimeout(() => {
      setIsClosing(false);
      onClose();
    }, 300);
  };

  useEffect(() => {
    if (!isOpen || !sheetRef.current) return;

    const sheet = sheetRef.current;
    const backdrop = backdropRef.current;
    let touchStartY = 0;
    let touchCurrentY = 0;
    let dragging = false;

    const handleTouchStart = (e) => {
      // Only start drag from the handle area or top of sheet
      const touch = e.touches[0];
      const sheetTop = sheet.getBoundingClientRect().top;

      if (touch.clientY - sheetTop < 60) {
        touchStartY = touch.clientY;
        touchCurrentY = touch.clientY;
        dragging = true;
        setIsDragging(true);
        setStartY(touchStartY);
        setCurrentY(touchCurrentY);
        sheet.style.transition = "none";
        if (backdrop) backdrop.style.transition = "none";
      }
    };

    const handleTouchMove = (e) => {
      if (!dragging) return;

      const touch = e.touches[0];
      touchCurrentY = touch.clientY;
      setCurrentY(touchCurrentY);

      const diff = touchCurrentY - touchStartY;

      // Only allow dragging down
      if (diff > 0) {
        e.preventDefault();
        sheet.style.transform = `translateY(${diff}px)`;

        // Fade backdrop proportionally
        if (backdrop) {
          const maxDrag = 400; // Max distance for full fade
          const opacity = Math.max(0, 1 - diff / maxDrag);
          backdrop.style.opacity = opacity;
        }
      }
    };

    const handleTouchEnd = () => {
      if (!dragging) return;

      const diff = touchCurrentY - touchStartY;
      const threshold = 100; // Pixels to drag down to dismiss

      sheet.style.transition = "transform 0.3s ease-out";
      if (backdrop) backdrop.style.transition = "opacity 0.3s ease-out";

      if (diff > threshold) {
        // Dismiss the sheet and apply changes
        sheet.style.transform = "translateY(100%)";
        if (backdrop) backdrop.style.opacity = "0";
        setTimeout(() => {
          onClose();
        }, 300);
      } else {
        // Snap back
        sheet.style.transform = "translateY(0)";
        if (backdrop) backdrop.style.opacity = "1";
      }

      dragging = false;
      setIsDragging(false);
    };

    sheet.addEventListener("touchstart", handleTouchStart);
    sheet.addEventListener("touchmove", handleTouchMove, { passive: false });
    sheet.addEventListener("touchend", handleTouchEnd);
    sheet.addEventListener("touchcancel", handleTouchEnd);

    return () => {
      sheet.removeEventListener("touchstart", handleTouchStart);
      sheet.removeEventListener("touchmove", handleTouchMove);
      sheet.removeEventListener("touchend", handleTouchEnd);
      sheet.removeEventListener("touchcancel", handleTouchEnd);
    };
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  // Ensure z-index is above tab bar (60) and add button (61)
  const backdropZIndex = Math.max(zIndex, 70);
  const sheetZIndex = backdropZIndex + 1;

  return (
    <div className="fixed inset-0" style={{ zIndex: backdropZIndex }}>
      <div
        ref={backdropRef}
        className="ios-sheet-backdrop"
        onClick={handleAnimatedClose}
        style={{ zIndex: backdropZIndex, transition: "opacity 0.3s ease-out" }}
      />
      <div ref={sheetRef} className="ios-sheet ios-slide-up" style={{ zIndex: sheetZIndex }}>
        <div className="ios-sheet-handle" />
        <div className="ios-sheet-header">
          <h3 className="ios-sheet-title">{title}</h3>
          <button onClick={handleAnimatedClose} className="ios-sheet-close">
            <X className="w-5 h-5" />
          </button>
        </div>
        <div className="ios-sheet-content">{children}</div>
      </div>
    </div>
  );
}
