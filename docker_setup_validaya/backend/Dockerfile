# ============================================================================
# Dockerfile multistage — Backend Java Spring Boot (ValidaYa QA)
# ============================================================================
# Stage 1 (build): compila el JAR adentro del contenedor, cero deps en host.
# Stage 2 (runtime): JRE Alpine slim, copia solo el JAR final.
# ============================================================================
# Build context esperado: raíz del repo (~/projects/validaya/).
# El path del backend tiene espacio ("validaya backend/") — toleramos
# usando ARG y comillas en COPY.
# ============================================================================

# ─── Build stage ─────────────────────────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-17-alpine AS build

WORKDIR /build

# Copiar pom.xml primero para aprovechar cache de capas en deps.
# Si solo cambia código fuente y no deps, esta capa se reutiliza.
COPY ["validaya backend/pom.xml", "./pom.xml"]
RUN mvn dependency:go-offline -B

# Copiar código fuente y compilar.
COPY ["validaya backend/src", "./src"]
RUN mvn package -DskipTests -B

# ─── Runtime stage ───────────────────────────────────────────────────────────
FROM eclipse-temurin:17-jre-alpine AS runtime

LABEL org.opencontainers.image.title="ValidaYa Backend (QA)"
LABEL org.opencontainers.image.source="https://github.com/PabloQuiroz12/validaya"
LABEL org.opencontainers.image.description="Backend Java Spring Boot reempaquetado para ambiente QA local"

# wget para healthcheck (Spring sin actuator → probamos puerto TCP con nc).
RUN apk add --no-cache curl netcat-openbsd

WORKDIR /app
COPY --from=build /build/target/validaya-0.0.1-SNAPSHOT.jar app.jar

# Locale BO/es — preservamos del Dockerfile original.
ENV JAVA_TOOL_OPTIONS="-Duser.language=es -Duser.region=BO -Duser.country=BO -Duser.timezone=America/La_Paz"

# El backend lee SERVER_PORT desde env (Spring relaxed binding).
# Default 8080 si la env no está seteada.
ENV SERVER_PORT=8080
EXPOSE 8080

# Healthcheck: Spring no tiene actuator (VAL-008 — actuator no incluido en pom).
# Workaround: TCP probe al puerto. No valida que la app esté lista para servir,
# solo que el listener está arriba. Suficiente para que compose espere algo.
HEALTHCHECK --interval=10s --timeout=3s --start-period=60s --retries=5 \
    CMD nc -z localhost ${SERVER_PORT} || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
