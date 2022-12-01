ARG NGINX_VERSION=1.23.1-alpine

FROM nginx:$NGINX_VERSION

RUN set -x && apk add --no-cache jq

COPY nginx/docker-entrypoint.sh /docker-entrypoint.sh

RUN rm -rf /docker-entrypoint.d/
COPY nginx/docker-entrypoint.d/20-envsubst-on-templates.sh /docker-entrypoint.d/
COPY nginx/bin/* /usr/local/bin/