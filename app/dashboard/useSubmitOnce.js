'use client';

import { useEffect, useRef } from 'react';

// Blocks repeat submits (double-taps) from the moment the first one fires,
// before React has re-rendered the button as disabled.
export default function useSubmitOnce(pending) {
  const inFlight = useRef(false);

  useEffect(() => {
    if (!pending) inFlight.current = false;
  }, [pending]);

  return function onSubmit(event) {
    if (inFlight.current) {
      event.preventDefault();
      return;
    }
    inFlight.current = true;
  };
}
