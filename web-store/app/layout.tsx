import './globals.css';

export const metadata = {
  title: 'Nile Tropical Industries',
  description: 'Nile Tropical Industries (U) Ltd — natural care, hygiene, botanical and personal care products from Uganda.',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
