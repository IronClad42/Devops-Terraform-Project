FROM node:22.16.0-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 1000

CMD ["node", "index.js"]