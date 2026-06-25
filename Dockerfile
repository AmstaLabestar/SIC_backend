# =============================================================================
# SIC - Image backend Django (multi-stage, slim)
# -----------------------------------------------------------------------------
# Les compilateurs ne vivent que dans l'etape "builder" ; l'image finale ne
# contient que Python + les dependances installees + le code applicatif.
# Combine au .dockerignore (exclut sic_mobile/, .git, build...), cela ramene
# l'image de ~8.5 Go a quelques centaines de Mo.
# =============================================================================

# --- Etape 1 : compilation des dependances -----------------------------------
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Outils de build : utiles uniquement si une dependance n'a pas de wheel.
# Ils restent dans cette etape et n'alourdissent pas l'image finale.
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Installe les dependances dans un prefixe isole, recopie tel quel ensuite.
RUN pip install --upgrade pip && \
    pip install --prefix=/install -r requirements.txt

# --- Etape 2 : image finale d'execution --------------------------------------
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Recupere uniquement les paquets Python (aucun compilateur ici).
COPY --from=builder /install /usr/local

# Copie le code applicatif (le .dockerignore filtre tout le superflu).
COPY . .

# Utilisateur non-root pour l'execution.
RUN groupadd -r sic && useradd -r -g sic sic && \
    mkdir -p /app/logs /app/media /app/staticfiles && \
    chown -R sic:sic /app

USER sic

EXPOSE 8000

# Serveur ASGI (Channels/WebSockets). docker-compose surcharge au besoin.
CMD ["daphne", "-b", "0.0.0.0", "-p", "8000", "config.asgi:application"]
