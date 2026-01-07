# ===== 1) Build =====
FROM node:20-alpine AS build
WORKDIR /app

# Dépendances (cache Docker)
COPY package*.json ./
RUN npm ci

# Code puis build
COPY . .
RUN npm run build


# ===== 2) Runtime =====
FROM nginx:alpine
# On remplace la conf nginx par une conf SPA (Vite => index.html fallback)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# On ne copie que le résultat du build
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
