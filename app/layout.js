import './globals.css';

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

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        {children}
        <footer className="site-footer">© 2026 GovernorHQ</footer>
      </body>
    </html>
  );
}
