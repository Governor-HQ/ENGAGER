import { ImageResponse } from 'next/og';

export const alt = 'Engager';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

export default function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          background: '#B5272C',
          color: '#ffffff',
        }}
      >
        <div style={{ fontSize: 140, fontWeight: 800, letterSpacing: '-0.02em' }}>Engager</div>
        <div style={{ fontSize: 44, marginTop: 16 }}>Daily LinkedIn engagement for the cohort</div>
      </div>
    ),
    { ...size }
  );
}
