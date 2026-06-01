# ============================================================================
# Dockerfile — Microservicio facial Flask + DeepFace (ValidaYa QA)
# ============================================================================
# Filename intencionalmente "Dockerfile" con D mayúscula seguida de minúsculas
# (el `DockerfIle` original con I mayúscula no es detectado por `docker build`
# en Linux — bug documentado como VAL nuevo). Mantenemos el original sin tocar
# como evidencia; este archivo es el que usa docker-compose.
# ============================================================================
# FIX AMBIENTE (QA): base pineada a -slim-bookworm. La tag `python:3.10-slim`
# sin pin derivó a Debian 13 (Trixie), donde `libgl1-mesa-glx` fue eliminado y
# `libglib2.0-0` renombrado a `libglib2.0-0t64` → `apt-get install` fallaba.
# Bookworm conserva los nombres de paquete originales. Solo cambia la base
# image; la lógica Python, CMD, puertos, env y volúmenes quedan intactos.
# ============================================================================

FROM python:3.10-slim-bookworm

# OpenCV runtime deps (no incluidas en slim).
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Cache deps en capa propia: solo cambia si requirements.txt cambia.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-descarga pesos ArcFace en build (no en runtime — runtime sería lento
# en el primer request). El `|| true` evita fallar el build si la descarga
# remota está caída temporalmente.
RUN python -c "from deepface import DeepFace; import numpy as np; \
    DeepFace.represent(img_path=np.zeros((112,112,3), dtype='uint8'), \
    model_name='ArcFace', detector_backend='opencv', enforce_detection=False)" \
    || true

# Código fuente (al final para que cambios en code no invaliden capa de deps).
COPY . .

# Puerto via env — default 5000 para QA local, 7860 si se redeploya en HF Space.
# El Dockerfile original hardcodeaba 7860 (convención HuggingFace) y no leía
# la env var — incompatible con setup local donde el backend Java espera 5000.
ENV PORT=5000
EXPOSE 5000

ENV FLASK_ENV=production
ENV PYTHONUNBUFFERED=1

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=5 \
    CMD curl -fsS http://localhost:${PORT}/health || exit 1

# `sh -c` permite que ${PORT} se expanda en runtime (CMD en exec form no expande).
CMD ["sh", "-c", "gunicorn -w 2 -b 0.0.0.0:${PORT} --timeout 120 app:app"]
