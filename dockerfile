# Build stage
FROM node:18 AS build

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy all files
COPY . .

# Generate Prisma Client before running migrations
RUN npx prisma generate

# Build the application
RUN npm run build

# Lighter runtime image
FROM node:18-slim

WORKDIR /app

# Copy built app from build stage
COPY --from=build /app .

# Persist DATABASE_URL in the final image
ARG DATABASE_URL
ENV DATABASE_URL=${DATABASE_URL}

# Ensure Prisma Migrations are applied at runtime
CMD npx prisma migrate deploy && npm start

# Expose port
EXPOSE 3000
