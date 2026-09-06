# Slim base keeps the CVE surface small, which is what Trivy scores
# in the image-scan stage.
FROM python:3.12-slim

# Run as non-root. Checkov and Trivy both flag root containers, and
# Kubernetes Pod Security Standards reject them under 'restricted'.
RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD python -c "import urllib.request;urllib.request.urlopen('http://localhost:8080/health')"

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
