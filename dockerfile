# To Install Dependencies
FROM node:18 AS build

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

#Added Env variables
ENV NODE_ENV=production

#COPY .env .env


RUN npm run build

# To Build lighter Image

FROM node:18-slim

WORKDIR /app

COPY --from=build /app .

EXPOSE 3000

CMD ["npm", "start"]
