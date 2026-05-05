# Build
FROM registry.hamdocker.ir/syaser/node:20-alpine AS builder
WORKDIR /app
RUN npm config set registry "https://npm-registry.darkube.ir/"

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# Run
FROM registry.hamdocker.ir/syaser/node:20-alpine  AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.mjs ./

EXPOSE 3000

CMD ["npm", "run", "start"]