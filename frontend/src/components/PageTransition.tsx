import { useRef, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { usePageTransition } from "../hooks/usePageTransition";

/**
 * Wrapper component for pages that need navigation stack transitions
 * Handles slide animations and swipe-to-go-back gesture
 */
export default function PageTransition({ children, showBackdrop = true, onClose }) {
  const { direction } = usePageTransition();
  const navigate = useNavigate();
  const pageRef = useRef(null);
  const startXRef = useRef(null);
  const currentXRef = useRef(null);
  const isDraggingRef = useRef(false);
  const isAnimatingOutRef = useRef(false);

  // Function to handle animated back navigation
  const handleAnimatedBack = useCallback(
    (callback) => {
      const page = pageRef.current;
      if (!page || isAnimatingOutRef.current) return;

      isAnimatingOutRef.current = true;

      // Trigger slide-out animation
      page.style.transition = "transform 0.35s cubic-bezier(0.25, 0.46, 0.45, 0.94)";
      page.style.transform = "translateX(100%)";

      // Fade out backdrop
      const backdrop = document.querySelector(".nav-stack-blur-backdrop");
      if (backdrop) {
        backdrop.style.transition = "opacity 0.35s ease-out";
        backdrop.style.opacity = "0";
      }

      // Navigate after animation completes
      setTimeout(() => {
        if (callback) {
          callback();
        } else if (onClose) {
          onClose();
        } else {
          navigate(-1);
        }
        isAnimatingOutRef.current = false;
      }, 350);
    },
    [navigate, onClose],
  );

  // Handle clicks on back buttons within the page
  useEffect(() => {
    const page = pageRef.current;
    if (!page) return;

    const handleClick = (e) => {
      // Find if the click is on a back button
      const backButton = e.target.closest(".nav-stack-back-button, [data-back-button]");
      if (backButton) {
        e.preventDefault();
        e.stopPropagation();
        handleAnimatedBack();
      }
    };

    page.addEventListener("click", handleClick, true);
    return () => {
      page.removeEventListener("click", handleClick, true);
    };
  }, [handleAnimatedBack]);

  // Handle swipe to go back
  useEffect(() => {
    const page = pageRef.current;
    if (!page) return;

    let startX = 0;
    let currentX = 0;
    let isDragging = false;

    const handleTouchStart = (e) => {
      // Only start drag if touch starts near the left edge
      const touch = e.touches[0];
      if (touch.clientX < 20) {
        startX = touch.clientX;
        currentX = touch.clientX;
        isDragging = true;
        startXRef.current = startX;
        currentXRef.current = currentX;
        isDraggingRef.current = true;
        page.style.transition = "none";
      }
    };

    const handleTouchMove = (e) => {
      if (!isDragging) return;

      const touch = e.touches[0];
      currentX = touch.clientX;
      currentXRef.current = currentX;

      const diff = currentX - startX;

      // Only allow dragging to the right (going back)
      if (diff > 0) {
        e.preventDefault();
        const translate = Math.min(diff, window.innerWidth);
        const opacity = Math.max(0, 1 - translate / window.innerWidth);
        page.style.transform = `translateX(${translate}px)`;

        // Also fade the backdrop if it exists
        const backdrop = document.querySelector(".nav-stack-blur-backdrop");
        if (backdrop) {
          backdrop.style.opacity = opacity;
        }
      }
    };

    const handleTouchEnd = () => {
      if (!isDragging) return;

      const diff = currentX - startX;
      const threshold = window.innerWidth * 0.3; // 30% of screen width

      page.style.transition =
        "transform 0.35s cubic-bezier(0.25, 0.46, 0.45, 0.94), opacity 0.35s ease-out";

      if (diff > threshold) {
        // Complete the back navigation
        handleAnimatedBack();
      } else {
        // Snap back to original position
        page.style.transform = "translateX(0)";
        const backdrop = document.querySelector(".nav-stack-blur-backdrop");
        if (backdrop) {
          backdrop.style.opacity = "1";
        }
      }

      isDragging = false;
      isDraggingRef.current = false;
    };

    page.addEventListener("touchstart", handleTouchStart, { passive: false });
    page.addEventListener("touchmove", handleTouchMove, { passive: false });
    page.addEventListener("touchend", handleTouchEnd);
    page.addEventListener("touchcancel", handleTouchEnd);

    return () => {
      page.removeEventListener("touchstart", handleTouchStart);
      page.removeEventListener("touchmove", handleTouchMove);
      page.removeEventListener("touchend", handleTouchEnd);
      page.removeEventListener("touchcancel", handleTouchEnd);
    };
  }, [handleAnimatedBack]);

  // Only animate when pushing forward, not when popping back
  // On pop, the page being dismissed will animate out, but the revealed page should not animate
  const animationClass = direction === "push" ? "slide-in-right" : "";
  const backdropClass = direction === "push" ? "fade-in-backdrop" : "";

  // Handle backdrop click with animation
  const handleBackdropClick = useCallback(
    (e) => {
      e.preventDefault();
      handleAnimatedBack();
    },
    [handleAnimatedBack],
  );

  return (
    <>
      {showBackdrop && direction === "push" && (
        <div className={`nav-stack-blur-backdrop ${backdropClass}`} onClick={handleBackdropClick} />
      )}
      <div ref={pageRef} className={`nav-stack-page ${animationClass}`}>
        {children}
      </div>
    </>
  );
}
