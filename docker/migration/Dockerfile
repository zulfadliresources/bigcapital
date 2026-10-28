# Runs system + tenant migrations against the database.
#
# The base image is the server image built from this same commit. When built
# by CI the SERVER_IMAGE build arg points at the freshly pushed GHCR tag; when
# built locally it defaults to the locally tagged `bigcapital-server:local`.
ARG SERVER_IMAGE=bigcapital-server:local
FROM ${SERVER_IMAGE}

ARG DB_HOST=host.docker.internal \
  DB_PORT=3306 \
  DB_USER= \
  DB_PASSWORD= \
  DB_CHARSET= \
  # System database.
  SYSTEM_DB_NAME= \
  SYSTEM_DB_PASSWORD= \
  SYSTEM_DB_USER= \
  SYSTEM_DB_HOST= \
  SYSTEM_DB_PORT= \
  SYSTEM_DB_CHARSET= \
  # Tenant databases.
  TENANT_DB_NAME_PERFIX= \
  TENANT_DB_USER= \
  TENANT_DB_PASSWORD= \
  TENANT_DB_HOST= \
  TENANT_DB_PORT=

ENV DB_HOST=$DB_HOST \
  DB_PORT=$DB_PORT \
  DB_USER=$DB_USER \
  DB_PASSWORD=$DB_PASSWORD \
  DB_CHARSET=$DB_CHARSET \
  # System database.
  SYSTEM_DB_HOST=$SYSTEM_DB_HOST \
  SYSTEM_DB_PORT=$SYSTEM_DB_PORT \
  SYSTEM_DB_USER=$SYSTEM_DB_USER \
  SYSTEM_DB_PASSWORD=$SYSTEM_DB_PASSWORD \
  SYSTEM_DB_NAME=$SYSTEM_DB_NAME \
  SYSTEM_DB_CHARSET=$SYSTEM_DB_CHARSET \
  # Tenant databases.
  TENANT_DB_NAME_PERFIX=$TENANT_DB_NAME_PERFIX \
  TENANT_DB_HOST=$TENANT_DB_HOST \
  TENANT_DB_PORT=$TENANT_DB_PORT \
  TENANT_DB_USER=$TENANT_DB_USER \
  TENANT_DB_PASSWORD=$TENANT_DB_PASSWORD

USER root
RUN apk update && \
  apk upgrade

RUN apk add --no-cache bash netcat-openbsd

# Change working dir to the server package.
WORKDIR /app/packages/server

# Wait for the database port (host-aware, no fixed `mysql` hostname), then run
# both migration sets.
CMD ["sh", "-c", "\
HOST=\"${SYSTEM_DB_HOST:-$DB_HOST}\"; \
PORT=\"${SYSTEM_DB_PORT:-$DB_PORT}\"; \
echo \"Waiting for database at $HOST:$PORT ...\"; \
i=0; \
until nc -z \"$HOST\" \"$PORT\" 2>/dev/null; do \
i=$((i+1)); \
if [ $i -ge 60 ]; then echo \"Database $HOST:$PORT unreachable, giving up.\"; exit 1; fi; \
sleep 2; \
done; \
echo \"Database is up, running migrations ...\"; \
node dist/cli.js system:migrate:latest && \
node dist/cli.js tenants:migrate:latest"]
