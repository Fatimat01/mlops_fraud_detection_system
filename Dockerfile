# Dockerfile for FastAPI-based SageMaker container
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip install --no-cache-dir \
    numpy==1.24.3 \
    pandas==2.0.3 \
    scikit-learn==1.3.0 \
    xgboost==2.0.3 \
    joblib==1.3.2 \
    fastapi==0.104.1 \
    uvicorn[standard]==0.24.0 \
    python-multipart==0.0.6 \
    pydantic==2.5.0

# Set up environment
ENV PYTHONUNBUFFERED=TRUE
ENV PYTHONDONTWRITEBYTECODE=TRUE
ENV MODEL_PATH=/opt/ml/model

# Create SageMaker model directory (where SageMaker mounts model.tar.gz)
RUN mkdir -p /opt/ml/model \
    && mkdir -p /opt/ml/output \
    && mkdir -p /opt/ml/code \
    && mkdir -p /opt/ml/input \
    && mkdir -p /opt/app

# Copy application code
COPY app /opt/app
WORKDIR /opt/app
RUN chmod +x serve.py
# Expose port 8080 (SageMaker expects this)
EXPOSE 8080

# # Run FastAPI with Uvicorn
# CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"]

# Use ENTRYPOINT for SageMaker compatibility
ENTRYPOINT ["python", "serve.py"]