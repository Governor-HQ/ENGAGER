import { Bricolage_Grotesque, DM_Sans } from 'next/font/google';
import { connection } from 'next/server';
import './globals.css';

// Downloaded at build time and served from this site, so the CSP font-src 'self' holds.
const display = Bricolage_Grotesque({
  subsets: ['latin'],
  weight: ['600', '800'],
  display: 'swap',
  variable: '--font-bricolage',
});

const body = DM_Sans({
  subsets: ['latin'],
  weight: ['400', '500', '700'],
  display: 'swap',
  variable: '--font-dm-sans',
});

const description =
  'One LinkedIn post a day. Everyone engages with everyone. Built for the Tech4Youth cohort.';

export const metadata = {
  metadataBase: new URL(
    process.env.VERCEL_PROJECT_PRODUCTION_URL
      ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
      : 'http://localhost:3000'
  ),
  title: 'Engager',
  description,
  openGraph: {
    title: 'Engager',
    description,
    siteName: 'Engager',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Engager',
    description,
  },
};

export const viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: '#B5272C',
};

export default async function RootLayout({ children }) {
  // Render every page per request so Next.js can add the CSP nonce to its scripts.
  await connection();

  return (
    <html lang="en" className={`${display.variable} ${body.variable}`}>
      <body>
        {children}
        <footer className="site-footer">© 2026 GovernorHQ</footer>
      </body>
    </html>
  );
}
