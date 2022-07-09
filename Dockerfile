FROM casjaysdevdocker/golang:latest AS builder

ENV XDG_CONFIG_HOME /config
ENV XDG_DATA_HOME /data

RUN set -e \
  export XCADDY_SETCAP=1; \
  export version=$(curl -s "https://api.github.com/repos/caddyserver/caddy/releases/latest" | jq -r .tag_name | grep '^' || exit 5); \
  echo ">>>>>>>>>>>>>>> ${version} ###############"

RUN apk -U upgrade && \
  go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest || exit 10; \
  xcaddy build ${version} --output /caddy \
  --with github.com/caddy-dns/route53 \
  --with github.com/caddy-dns/cloudflare \
  --with github.com/caddy-dns/alidns \
  --with github.com/caddy-dns/dnspod \
  --with github.com/caddy-dns/gandi \
  --with github.com/abiosoft/caddy-exec \
  --with github.com/greenpau/caddy-trace \
  --with github.com/hairyhenderson/caddy-teapot-module \
  --with github.com/kirsch33/realip \
  --with github.com/porech/caddy-maxmind-geolocation \
  --with github.com/caddyserver/transform-encoder \
  --with github.com/caddyserver/replace-response

FROM casjaysdevdocker/php:latest as php
COPY --from=builder /caddy /usr/bin/caddy
COPY ./config/Caddyfile /etc/caddy/Caddyfile
COPY ./data/htdocs/. /usr/share/caddy/

COPY ./bin/entrypoint-caddy.sh /usr/local/bin/entrypoint-caddy.sh

FROM php
ARG BUILD_DATE="$(date +'%Y-%m-%d %H:%M')"
LABEL \
  org.label-schema.name="caddy" \
  org.label-schema.description="Alpine based image with caddy and php8." \
  org.label-schema.url="https://hub.docker.com/r/casjaysdevdocker/caddy" \
  org.label-schema.vcs-url="https://github.com/casjaysdevdocker/caddy" \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.version=$BUILD_DATE \
  org.label-schema.vcs-ref=$BUILD_DATE \
  org.label-schema.license="WTFPL" \
  org.label-schema.vcs-type="Git" \
  org.label-schema.schema-version="1.0" \
  org.label-schema.vendor="CasjaysDev" \
  maintainer="CasjaysDev <docker-admin@casjaysdev.com>"

EXPOSE 1-65535

WORKDIR /data/htdocs
VOLUME [ "/data", "/config" ]

HEALTHCHECK CMD ["/usr/local/bin/entrypoint-caddy.sh", "healthcheck"]

ENTRYPOINT ["/usr/local/bin/entrypoint-caddy.sh"]
