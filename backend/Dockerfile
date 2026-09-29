# ───── build ─────
FROM node:22-alpine AS build
WORKDIR /app
RUN apk add --no-cache openssl
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npx prisma generate && npm run build && npm run build:seed && npm prune --omit=dev

# ───── runtime ─────
FROM node:22-alpine
WORKDIR /app
RUN apk add --no-cache openssl tini
ENV NODE_ENV=production
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --from=build --chown=node:node /app/dist-seed ./dist-seed
COPY --from=build --chown=node:node /app/prisma ./prisma
COPY --from=build --chown=node:node /app/package.json ./package.json
USER node
EXPOSE 3000
ENTRYPOINT ["/sbin/tini", "--"]
# Apply pending migrations (idempotent), then start the API.
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main.js"]
