# To Install Dependencies
FROM node:18 AS build

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

# Generate Prisma Client
RUN npx prisma generate

# Run Prisma Migrations (Ensure Neon DB is ready before running this)
RUN npx prisma migrate deploy

RUN npm run build

# To Build lighter Image

FROM node:18-slim

WORKDIR /app

COPY --from=build /app .

EXPOSE 3000

CMD ["npm", "start"]
