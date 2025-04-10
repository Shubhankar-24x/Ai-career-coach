/** @type {import('next').NextConfig} */
const nextConfig = {
  // distDir: ".next", // Ensures build output is in `.next`
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "randomuser.me",
      },
    ],
  },
};

export default nextConfig; // Keep using ES module export


