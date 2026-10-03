import './globals.css';

export const metadata = {
  title: 'Engager',
  description: 'Coordinate LinkedIn engagement with your classmates.',
};

export const viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: '#B5272C',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
