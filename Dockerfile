FROM golang:1.25-alpine AS builder

WORKDIR /build
COPY registration/ ./
RUN go build -o registration-proxy .

FROM ghcr.io/element-hq/dendrite-monolith:latest

COPY --from=builder /build/registration-proxy /usr/local/bin/registration-proxy
COPY config/dendrite.yaml /etc/dendrite/dendrite.yaml
COPY scripts/fly-entrypoint.sh /usr/local/bin/fly-entrypoint.sh

RUN chmod +x /usr/local/bin/fly-entrypoint.sh /usr/local/bin/registration-proxy

ENTRYPOINT ["/usr/local/bin/fly-entrypoint.sh"]
