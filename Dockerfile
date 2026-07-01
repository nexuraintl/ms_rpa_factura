# --- Stage 1: Build the frontend ---
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend

COPY frontend/package*.json ./
RUN npm ci

COPY frontend/ ./
RUN npm run build

# --- Stage 2: Run Python and Playwright ---
FROM python:3.11-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PLAYWRIGHT_BROWSERS_PATH=/opt/playwright

WORKDIR /app

# Install basic system packages + clean apt cache in the same layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy and install python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install Chromium and ONLY its required system dependencies, then clean up
RUN playwright install --with-deps chromium \
    && rm -rf /root/.cache/ms-playwright

# Copy built frontend assets from stage 1
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

# Copy backend source code
COPY app.py rpa_bot.py ./

# AJUSTE: La carpeta de descargas debe apuntar a /tmp para Cloud Run
RUN mkdir -p /tmp/facturas_descargadas && ln -s /tmp/facturas_descargadas ./facturas_descargadas

# Cloud Run inyecta el puerto dinámicamente, no fijamos el 8000
EXPOSE 8080

# Start application vinculando el puerto a la variable de entorno $PORT
CMD ["sh", "-c", "python app.py --host 0.0.0.0 --port ${PORT:-8080}"]