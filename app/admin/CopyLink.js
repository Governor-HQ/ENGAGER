'use client';

import { useRef, useState } from 'react';
import styles from './admin.module.css';

export default function CopyLink({ url, label }) {
  const inputRef = useRef(null);
  const [status, setStatus] = useState('idle'); // idle | copied | manual

  async function copy() {
    try {
      await navigator.clipboard.writeText(url);
      setStatus('copied');
      setTimeout(() => setStatus('idle'), 2000);
    } catch {
      // Clipboard blocked: show the link selected so it can be copied by hand.
      setStatus('manual');
      setTimeout(() => {
        inputRef.current?.focus();
        inputRef.current?.select();
      }, 0);
    }
  }

  return (
    <span className={styles.copyWrap}>
      <button
        type="button"
        className="btn btn-ghost"
        onClick={copy}
        aria-label={`Copy join link for ${label}`}
      >
        {status === 'copied' ? 'Copied' : 'Copy link'}
      </button>
      {status === 'manual' && (
        <input
          ref={inputRef}
          type="text"
          readOnly
          value={url}
          aria-label={`Join link for ${label}`}
          className={styles.copyInput}
          onFocus={(e) => e.target.select()}
        />
      )}
      <span className="sr-only" role="status">
        {status === 'copied' ? 'Link copied' : ''}
      </span>
    </span>
  );
}
