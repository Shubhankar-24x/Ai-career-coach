import { Inter } from "next/font/google";
import "./globals.css";
import Header from "@/components/header";
import HydrationSafeProviders from "@/components/HydrationSafeProviders"; // Import Client Component

const inter = Inter({ subsets: ["latin"] });

export const metadata = {
  title: "AI Career Coach",
  description: "",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <link rel="icon" href="/logo.png" sizes="any" />
      </head>
      <body className={`${inter.className}`}>
        <HydrationSafeProviders>
          <Header />
          <main className="min-h-screen">{children}</main>
          <footer className="bg-muted/50 py-12">
            <div className="container mx-auto px-4 text-center text-gray-200">
              <p>Made with 💗 by Maverick Coders</p>
            </div>
          </footer>
        </HydrationSafeProviders>
      </body>
    </html>
  );
}
