FROM python:3.11-slim

# System deps for typical video + OCR pipelines
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    coreutils \
    findutils \
    gawk \
    sed \
    ffmpeg \
    tesseract-ocr \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install python deps first for better layer caching
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# create these so docker cp/tar have stable targets
RUN mkdir -p /data/input /data/output

# Copy the rest of the project
COPY . /app

# Ensure scripts are executable
RUN chmod +x /app/run.sh /app/steps/*.sh

# Default locations (you can override by passing args)
ENTRYPOINT ["/app/run.sh"]
CMD ["/data/input", "/data/output"]
