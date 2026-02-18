FROM ghcr.io/element-hq/dendrite-monolith:latest

COPY config/dendrite.yaml /etc/dendrite/dendrite.yaml
COPY config/matrix_key.pem /etc/dendrite/matrix_key.pem
COPY scripts/fly-entrypoint.sh /usr/local/bin/fly-entrypoint.sh

RUN chmod +x /usr/local/bin/fly-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/fly-entrypoint.sh"]
