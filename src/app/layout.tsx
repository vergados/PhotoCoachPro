/**
 * Photo Coach Pro — App Layout
 * Name: Jason E Alaounis
 * Email: Philotimo71@gmail.com
 * Company: ALÁON
 */

import "./globals.css";
import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = {
  title: "Photo Coach Pro",
  description:
    "Upload a photo and get instant AI-powered critique: exposure, sharpness, color, and a 0–100 score.",
  openGraph: {
    title: "Photo Coach Pro",
    description: "Instant photo critique — exposure, sharpness, color, score.",
    type: "website",
  },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-zinc-50 text-zinc-900 antialiased">
        <div className="mx-auto max-w-5xl px-6 py-10">
          {/* Header */}
          <header className="flex items-start justify-between gap-6">
            <div>
              <h1 className="text-xl font-bold tracking-tight text-zinc-900">
                Photo Coach Pro
              </h1>
              <p className="mt-0.5 text-sm text-zinc-500">
                Upload a photo — get critique in seconds.
              </p>
            </div>

            <div className="flex shrink-0 items-center gap-2">
              <span className="rounded-full border border-zinc-200 bg-white px-3 py-1 text-xs font-medium text-zinc-500 shadow-sm">
                v1.0
              </span>
              <span className="rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-xs font-medium text-emerald-700">
                Live
              </span>
            </div>
          </header>

          {/* Page content */}
          <main className="mt-10">{children}</main>

          {/* Footer */}
          <footer className="mt-20 border-t border-zinc-200 pt-6 text-xs text-zinc-400">
            © {new Date().getFullYear()} ALÁON — Photo Coach Pro
          </footer>
        </div>
      </body>
    </html>
  );
}
