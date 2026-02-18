FROM golang:1.25-alpine AS builder

WORKDIR /build
COPY registration/ ./
RUN go build -o registration-proxy .

FROM alpine:latest

COPY --from=builder /build/registration-proxy /usr/local/bin/registration-proxy

ENTRYPOINT ["/usr/local/bin/registration-proxy"]
