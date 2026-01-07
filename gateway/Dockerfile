FROM node:20-alpine

WORKDIR /app

# Dépendances reproductibles
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Code
COPY . .

# Sécurité : user non-root
RUN addgroup -S app && adduser -S app -G app
USER app

# Ports
EXPOSE 8443
EXPOSE 8080

CMD ["node", "src/index.js"]
