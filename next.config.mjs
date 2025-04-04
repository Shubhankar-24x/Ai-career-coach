// /** @type {import('next').NextConfig} */
// const nextConfig = {
//   // distDir: ".next", // Ensures build output is in `.next`
//   images: {
//     remotePatterns: [
//       {
//         protocol: "https",
//         hostname: "randomuser.me",
//       },
//     ],
//   },
// };

// export default nextConfig; // Keep using ES module export

/** @type {import('next').NextConfig} */
import path from "path";

const nextConfig = {
  reactStrictMode: true, // Enables React strict mode for better debugging

  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "randomuser.me",
      },
    ],
  },

  webpack: (config) => {
    config.resolve.alias = {
      ...config.resolve.alias,
      "@": path.resolve(__dirname), // Alias '@' to the root directory
    };
    return config;
  },
};

export default nextConfig;
