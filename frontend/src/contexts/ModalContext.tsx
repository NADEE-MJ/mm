import { createContext, useContext, useState, useCallback, useEffect } from 'react';

const ModalContext = createContext(null);

/**
 * Modal stack management context
 * Provides automatic z-index management, scroll locking, and backdrop handling for modals
 */
export function ModalProvider({ children }) {
  const [modalStack, setModalStack] = useState([]);

  // Add a modal to the stack
  const openModal = useCallback((modalId) => {
    setModalStack(prev => {
      // Prevent duplicate modals
      if (prev.includes(modalId)) {
        return prev;
      }
      return [...prev, modalId];
    });
  }, []);

  // Remove a modal from the stack
  const closeModal = useCallback((modalId) => {
    setModalStack(prev => prev.filter(id => id !== modalId));
  }, []);

  // Get z-index for a modal
  const getZIndex = useCallback((modalId) => {
    const index = modalStack.indexOf(modalId);
    if (index === -1) return 40; // Default first layer modal z-index

    // Base z-index of 40, increment by 10 for each stacked modal
    return 40 + (index * 10);
  }, [modalStack]);

  // Check if a modal is currently open
  const isModalOpen = useCallback((modalId) => {
    return modalStack.includes(modalId);
  }, [modalStack]);

  // Get the number of open modals
  const getModalCount = useCallback(() => {
    return modalStack.length;
  }, [modalStack]);

  // Check if this is the topmost modal
  const isTopModal = useCallback((modalId) => {
    return modalStack[modalStack.length - 1] === modalId;
  }, [modalStack]);

  // Lock body scroll when modals are open
  useEffect(() => {
    if (modalStack.length > 0) {
      // Save current scroll position
      const scrollY = window.scrollY;

      // Lock scroll
      document.body.style.position = 'fixed';
      document.body.style.top = `-${scrollY}px`;
      document.body.style.width = '100%';
      document.body.style.overflow = 'hidden';

      return () => {
        // Restore scroll
        document.body.style.position = '';
        document.body.style.top = '';
        document.body.style.width = '';
        document.body.style.overflow = '';
        window.scrollTo(0, scrollY);
      };
    }
  }, [modalStack.length]);

  const value = {
    openModal,
    closeModal,
    getZIndex,
    isModalOpen,
    getModalCount,
    isTopModal,
    modalStack,
  };

  return (
    <ModalContext.Provider value={value}>
      {children}
    </ModalContext.Provider>
  );
}

/**
 * Hook to use modal context
 * @returns {object} Modal context methods
 */
export function useModal() {
  const context = useContext(ModalContext);

  if (!context) {
    throw new Error('useModal must be used within a ModalProvider');
  }

  return context;
}

/**
 * Hook to manage a specific modal's lifecycle
 * @param {string} modalId - Unique identifier for the modal
 * @param {boolean} isOpen - Whether the modal is currently open
 * @returns {object} Modal utilities including zIndex and handlers
 */
export function useModalInstance(modalId, isOpen) {
  const { openModal, closeModal, getZIndex, isTopModal } = useModal();

  // Register/unregister modal when isOpen changes
  useEffect(() => {
    if (isOpen) {
      openModal(modalId);
    } else {
      closeModal(modalId);
    }

    // Cleanup on unmount
    return () => {
      closeModal(modalId);
    };
  }, [isOpen, modalId, openModal, closeModal]);

  const zIndex = getZIndex(modalId);
  const isTop = isTopModal(modalId);

  return {
    zIndex,
    isTop,
    close: () => closeModal(modalId),
  };
}
