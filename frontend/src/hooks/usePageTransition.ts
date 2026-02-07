import { useEffect, useState } from "react";
import { useLocation, useNavigationType } from "react-router-dom";

/**
 * Hook to track navigation direction for page transitions
 * Returns 'push' for forward navigation, 'pop' for back navigation
 */
export function usePageTransition() {
  const location = useLocation();
  const navigationType = useNavigationType();
  const [direction, setDirection] = useState("push");
  const [isAnimating, setIsAnimating] = useState(false);

  useEffect(() => {
    // Determine animation direction based on navigation type
    if (navigationType === "POP") {
      setDirection("pop");
    } else {
      setDirection("push");
    }

    // Set animating flag
    setIsAnimating(true);
    const timer = setTimeout(() => {
      setIsAnimating(false);
    }, 350); // Match animation duration

    return () => clearTimeout(timer);
  }, [location, navigationType]);

  return { direction, isAnimating };
}
