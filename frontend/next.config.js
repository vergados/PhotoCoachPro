/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,

  // In local development, proxy /api/* and /health to the Python backend
  // running at http://127.0.0.1:8000 so the frontend never needs to know
  // the backend address. In production Vercel routes these automatically.
  async rewrites() {
    if (process.env.NODE_ENV !== "production") {
      return [
        {
          source: "/api/:path*",
          destination: "http://127.0.0.1:8000/api/:path*",
        },
        {
          source: "/health",
          destination: "http://127.0.0.1:8000/health",
        },
      ];
    }
    return [];
  },
};

module.exports = nextConfig;
