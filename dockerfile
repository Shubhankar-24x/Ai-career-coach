# Build stage
FROM node:18 AS build

WORKDIR /app

# Install OpenSSL for Prisma
RUN apt-get update && apt-get clean && apt-get install -y openssl


# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy all files
COPY . .

# Receive build-time environment variables
ARG NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
ARG DATABASE_URL

# Persist them as environment variables inside the build container
ENV NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=${NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY}
ENV DATABASE_URL=${DATABASE_URL}

# Generate Prisma Client before running migrations
RUN npx prisma generate

# Build the application
RUN npm run build

# Lighter runtime image
FROM node:18-slim

WORKDIR /app


# Install OpenSSL for Prisma compatibility
RUN apt-get update && apt-get clean && apt-get install -y openssl


# Copy built app from build stage
COPY --from=build /app .

# Persist environment variables in the final runtime container
ARG NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY
ARG DATABASE_URL

ENV NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=${NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY}
ENV DATABASE_URL=${DATABASE_URL}

# Expose port
EXPOSE 3000

# Start the application
CMD ["npm", "start"]
