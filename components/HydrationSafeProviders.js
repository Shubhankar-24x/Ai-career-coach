"use client"; // Client Component

import { ClerkProvider } from "@clerk/nextjs";
import { ThemeProvider } from "next-themes";
import { Toaster } from "sonner";
import { dark } from "@clerk/themes";
import { useEffect, useState } from "react";

export default function HydrationSafeProviders({ children }) {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  return (
    <ClerkProvider appearance={{ baseTheme: dark }}>
      <ThemeProvider attribute="class" defaultTheme="dark" enableSystem>
        {mounted ? children : null} {/* Prevents SSR hydration mismatch */}
        <Toaster richColors />
      </ThemeProvider>
    </ClerkProvider>
  );
}
