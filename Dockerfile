################################################################################
# Build Arguments
################################################################################

ARG GOLANG_IMAGE_DOMAIN="docker.io/library/golang"
ARG GOLANG_IMAGE_BRANCH="alpine"
ARG ALPINE_IMAGE_DOMAIN="docker.io/library/alpine"
ARG ALPINE_IMAGE_BRANCH="latest"

################################################################################
# Builder stage
################################################################################

FROM ${GOLANG_IMAGE_DOMAIN}:${GOLANG_IMAGE_BRANCH} AS builder

ENV DOCKERIZE_VERSION v0.6.1
RUN wget -q https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz
RUN tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz
RUN chown root:root /usr/local/bin/dockerize
RUN rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

ENV CGO_ENABLED="0"

COPY hraftd /go/src/github.com/otoolep/hraftd
WORKDIR /go/src/github.com/otoolep/hraftd
RUN go mod download
RUN go build -a -o /usr/local/bin/hraftd .

################################################################################
# Service stage
################################################################################

FROM ${ALPINE_IMAGE_DOMAIN}:${ALPINE_IMAGE_BRANCH} AS service

RUN apk --no-cache --update add tzdata dumb-init runit su-exec ca-certificates

COPY --from=builder /usr/local/bin/dockerize /usr/local/bin/dockerize
COPY --from=builder /usr/local/bin/hraftd /usr/local/bin/hraftd
COPY injection/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["dumb-init", "--", "docker-entrypoint.sh"]
CMD ["hraftd"]
