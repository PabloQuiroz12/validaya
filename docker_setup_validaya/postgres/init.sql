-- ============================================================================
-- init.sql — Inicialización Postgres para ambiente QA ValidaYa
-- ============================================================================
-- Postgres oficial corre TODO archivo *.sql/*.sh en /docker-entrypoint-initdb.d/
-- al primer arranque del volumen (NO en re-arranques posteriores).
-- POSTGRES_DB ya fue creada por la imagen base — acá sumamos face_db.
-- ============================================================================

-- DB separada para embeddings biométricos del microservicio facial.
-- Aislamos de validaya_db para que datos transaccionales y biométricos no
-- compartan superficie de ataque (principio de menor privilegio cuando se
-- agreguen users por servicio en el futuro).
CREATE DATABASE face_db;

-- El usuario POSTGRES_USER ya es superuser y dueño de validaya_db por default.
-- Le damos ownership explícito sobre face_db también.
ALTER DATABASE face_db OWNER TO validayaadmin;

-- Comentarios para que cualquiera que se conecte con DBeaver/DataGrip entienda.
COMMENT ON DATABASE face_db IS 'Embeddings ArcFace + metadata del microservicio facial Flask (QA local). Separada de validaya_db por defensa en profundidad.';
