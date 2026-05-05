# syntax=docker/dockerfile:1

ARG NODE_VERSION=22

# داخل مرحلهٔ build، localhost یعنی خود کانتینر. Verdaccio روی ماشین میزبان یا روی شبکهٔ داکر:
# پیش‌فرض: host.docker.internal (Desktop) — روی Linux با extra_hosts به host-gateway تبدیل کنید.
ARG NPM_REGISTRY=https://npm-registry.darkube.ir/

FROM node:${NODE_VERSION}-alpine AS deps
WORKDIR /app
ARG NPM_REGISTRY
RUN npm config set registry "${NPM_REGISTRY}"

COPY package.json package-lock.json ./
RUN npm ci

FROM node:${NODE_VERSION}-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM node:${NODE_VERSION}-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
