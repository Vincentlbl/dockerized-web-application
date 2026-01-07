FROM node:20-alpine

WORKDIR /app

# Dépendances reproductibles
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Code applicatif
COPY . .

# Sécurité : utilisateur non-root
RUN addgroup -S app && adduser -S app -G app
USER app

EXPOSE 4000

CMD ["node", "src/index.js"]
