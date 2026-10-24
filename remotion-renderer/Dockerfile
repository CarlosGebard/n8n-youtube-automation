FROM node:22-bookworm-slim

WORKDIR /app

# Remotion renders through Chromium and FFmpeg. Keep these Linux libraries in
# the image rather than relying on packages installed on the Docker host.
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        fonts-liberation \
        libasound2 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libcups2 \
        libdbus-1-3 \
        libdrm2 \
        libgbm1 \
        libglib2.0-0 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libpango-1.0-0 \
        libx11-6 \
        libx11-xcb1 \
        libxcb1 \
        libxcomposite1 \
        libxdamage1 \
        libxext6 \
        libxfixes3 \
        libxrandr2 \
        libxrender1 \
        libxshmfence1 \
        libxtst6 \
    && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN npm ci

COPY . ./
RUN chown -R node:node /app

USER node
EXPOSE 3000

CMD ["npm", "run", "studio", "--", "--host=0.0.0.0", "--port=3000"]
