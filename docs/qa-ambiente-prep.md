# Guía de preparación del ambiente QA — ValidaYa

Guía mínima para levantar el ambiente local de ValidaYa (Postgres + backend + microservicio facial) de forma reproducible. Pensada para que el equipo de QA pueda montar la misma base sin pelear con la configuración.

> **Alcance:** esto prepara el ambiente. **No** ejecuta el Plan de Pruebas ni casos. No toca código de producto, secretos ni evidencia de hallazgos.

---

## 1. Qué rama y commit usar

- **Fork de trabajo:** `PabloQuiroz12/validaya` (no el upstream de Lucas Valcarce).
- **Rama:** `qa/pablo/setup-ambiente`
- **Commit base del ambiente:** `37a16e9` — *chore(qa): estabilizar ambiente docker local*

```bash
git clone git@github.com:PabloQuiroz12/validaya.git
cd validaya
git checkout qa/pablo/setup-ambiente
```

Los fixes de ambiente ya están en esa rama:
- `modelado facial/Dockerfile` → base pineada a `python:3.10-slim-bookworm` (la tag `slim` sin pin derivó a Debian Trixie, que eliminó `libgl1-mesa-glx` y rompía el build).
- `docker-compose.yml` → Postgres publicado en host **5434** (el 5432 suele estar ocupado por otra Postgres local).

---

## 2. Requisitos

- **Docker Desktop** con integración WSL2 activada (Settings → Resources → WSL Integration). Verificar con `docker info` (no debe decir *"could not be found in this WSL 2 distro"*).
- **Node 18+** y **npm** (para el frontend, que corre fuera de Docker).
- Conexión a internet en el **primer build** (baja deps Maven, pip y ~137 MB de pesos ArcFace). Si el build falla descargando dependencias, ver §9 Troubleshooting.

---

## 3. Configurar variables (`.env`)

El compose lee un archivo `.env` (ignorado por git, **nunca se commitea**). Copiar la plantilla y completar:

```bash
cp .env.example .env
```

Variables mínimas a revisar/ajustar en `.env`:

| Variable | Valor sugerido | Nota |
|---|---|---|
| `POSTGRES_USER` | `validayaadmin` | usuario de la DB local |
| `POSTGRES_PASSWORD` | *(local-only)* | password dummy local, no productivo |
| `POSTGRES_DB` | `validaya_db` | base principal |
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://postgres:5432/validaya_db` | **interno** (DNS de red Docker), no el host |
| `SERVER_PORT` | `8080` | pisa el 8081 del `application.properties` vía relaxed binding |
| `SECURITY_JWT_TOKEN_SECRET_KEY` | `openssl rand -base64 32` | generar propio |
| `VALIDAYA_AES_SECRET_KEY` | `openssl rand -base64 32` | **distinto** del JWT |
| `FACIAL_DB_NAME` | `validaya_db` | el facial comparte la tabla `users` del backend; debe apuntar a la misma DB |
| `FACIAL_RECOGNITION_API_URL` | `http://facial-recognition:5000` | interno; **no** el HuggingFace Space del autor |
| `STEREUM_*` | dummy / sandbox | no usar credenciales reales |

> Generar las dos claves con:
> ```bash
> openssl rand -base64 32   # JWT
> openssl rand -base64 32   # AES (distinta)
> ```

---

## 4. Levantar el ambiente Docker

```bash
docker compose up -d --build      # primer arranque (lento: compila JAR + baja modelos)
docker compose ps                 # los 3 deben quedar (healthy)
docker compose logs -f backend    # seguir el boot de Spring
```

Orden de arranque (encadenado por healthcheck): **postgres → facial-recognition → backend**.

Al bootear, el backend crea el schema (Hibernate `ddl-auto=update`) y siembra datos de prueba vía `DataInitializer`. Usuarios semilla útiles para pruebas (CI / `identification`):

| Identificación | Rol |
|---|---|
| `0000000` | admin |
| `1234567` | ciudadano (Juan Pérez) |
| `9876543` | ciudadano (Isabela Ortiz) |
| `3331111` | ciudadano (Pedro Flores, con todos los docs) |

Parar / resetear:
```bash
docker compose down       # para los servicios (la data persiste en el volumen)
docker compose down -v    # para y BORRA la DB (reset total)
```

---

## 5. Levantar el frontend (fuera de Docker)

El frontend **no** está dockerizado (decisión del grupo): corre en el host con Vite.

```bash
cd "validaya frontend"
npm install
VITE_API_URL=http://localhost:8080/api/v1 npm run dev
```

Vite levanta en `http://localhost:5173`. `VITE_API_URL` debe apuntar al backend en **8080** (donde corre en Docker).

---

## 6. Puertos

| Servicio | Puerto interno (red Docker) | Puerto host | Reachable desde el host |
|---|---|---|---|
| Postgres | `postgres:5432` | `5434` | ✅ `localhost:5434` (DBeaver/DataGrip) |
| Backend | `backend:8080` | `8080` | ✅ `localhost:8080` |
| Facial | `facial-recognition:5000` | `5000` | ⚠️ puede no estar publicado (ver nota) |
| Frontend (Vite) | — | `5173` | ✅ `localhost:5173` |

> **Nota facial / `localhost:5000`:** en algunos entornos Docker Desktop + WSL2 el puerto host `5000` del facial puede no quedar publicado (`docker compose ps` lo muestra como `5000/tcp` sin `0.0.0.0:5000->`). **No bloquea las pruebas E2E**: el backend llega al facial por la red interna (`facial-recognition:5000`), que sí funciona. Solo afecta si querés pegarle al facial directo con curl/Postman desde el host. Si lo necesitás, probá `docker compose up -d --force-recreate facial-recognition` o reiniciar Docker Desktop.

---

## 7. Qué NO tocar

- **`application.properties` original** (`validaya backend/src/main/resources/`): contiene credenciales del autor — es **evidencia de hallazgos de seguridad**, no se edita ni se borra. El compose las neutraliza por env vars.
- **`.env` real:** nunca commitearlo (ya está en `.gitignore`). Usar siempre `.env.example` como plantilla.
- **Archivos originales con bugs** (`DockerfIle` con typo, `start.sh`, `api.js` hardcodeado): son evidencia documentada, se dejan intactos.
- **Código de producto** (Java / Python / React): no se modifica para "arreglar" el ambiente. El principio es: *el ambiente se arregla; los defectos del producto se documentan como VAL-NNN.*
- **Upstream** (`LucasValcarce/validaya`): no se le hace push, PR ni issues.
- **Secretos reales** (Neon, JWT/AES, Stereum): no se rotan ni se usan; se documentan.

---

## 8. Validación rápida (sin correr el Plan de Pruebas)

Confirmar que la base está lista para ejecutar casos:

```bash
# Los 3 healthy
docker compose ps

# Backend sirve y valida (responde 400 por faltar faceBase64 → endpoint vivo)
curl -s -X POST http://localhost:8080/api/v1/auth/identify \
  -H "Content-Type: application/json" -d '{"identification":"1234567"}'

# Facial responde internamente
docker exec validaya-qa-facial curl -s http://localhost:5000/health
```

Si los 3 contenedores están `healthy`, el backend responde y el facial da `{"status":"ok"}`, **el ambiente base está listo para ejecutar el Plan de Pruebas.**

---

## 9. Troubleshooting

**El build falla descargando dependencias (PyPI / Maven).** Si el `docker compose build` aborta con errores de **certificado**, **hashes que no coinciden**, **timeout** o **conexión rechazada** al bajar paquetes:

- Probá correr el build desde **otra red estable** antes de tocar nada. Algunas redes (proxies, VPNs, filtrado TLS) interfieren con la descarga de dependencias; el problema suele ser la red, no el Dockerfile.
- Una vez que las capas quedan cacheadas, los rebuilds posteriores ya no tocan la red.
- **No** uses `--trusted-host` ni desactives la validación TLS como solución por defecto: enmascara el problema, debilita la seguridad del build y quedaría commiteado. Si hace falta una excepción real, discutirla con el equipo primero.

---

## Hallazgos oportunistas pendientes (no documentados aún como VAL)

- `GET /v3/api-docs` → HTTP 500: incompatibilidad `springdoc-openapi 2.5.0` con Spring Boot 4 / Spring Framework 7. Candidato a VAL futuro (no es ambiente, es producto).
- Publish de `localhost:5000` del facial (detalle Docker Desktop/WSL, opcional).
