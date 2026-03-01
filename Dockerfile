FROM python:3.12-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir fastapi uvicorn[standard] python-multipart

# Copy application
COPY app/main.py /app/
COPY static/ /app/static/

# Create data directories
RUN mkdir -p /data/bundles /data/devices /certs

EXPOSE 8081

# Run with uvicorn for production
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8081", "--workers", "1", "--access-log"]
