import type { Metadata } from 'next';
import { JetBrains_Mono, DM_Sans } from 'next/font/google';
import './globals.css';

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-jetbrains-mono',
  display: 'swap',
  weight: ['400', '500', '600', '700', '800'],
});

const dmSans = DM_Sans({
  subsets: ['latin'],
  variable: '--font-dm-sans',
  display: 'swap',
  weight: ['400', '500'],
});

export const metadata: Metadata = {
  title: 'Hypersync — Your team\'s AI tools, always in sync',
  description:
    'One app keeps Cursor, Claude Code, and more configured with your team\'s shared skills and rules. Set it up once — it handles the rest.',
  metadataBase: new URL('https://hypersync.sh'),
  openGraph: {
    title: 'Hypersync — Keep your team\'s AI skills in sync',
    description:
      'One app keeps Cursor, Claude Code, and more configured with your team\'s shared skills and rules.',
    url: 'https://hypersync.sh',
    siteName: 'Hypersync',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Hypersync — Keep your team\'s AI skills in sync',
      },
    ],
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Hypersync — Keep your team\'s AI skills in sync',
    description:
      'One app keeps Cursor, Claude Code, and more configured with your team\'s shared skills and rules.',
    images: ['/og-image.png'],
  },
  icons: {
    icon: '/app-icon.png',
    apple: '/app-icon.png',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`${jetbrainsMono.variable} ${dmSans.variable}`}>
      <body className="font-body">{children}</body>
    </html>
  );
}
