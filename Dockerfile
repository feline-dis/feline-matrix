FROM ghcr.io/element-hq/dendrite-monolith:latest

COPY config/dendrite.yaml /etc/dendrite/dendrite.yaml
COPY scripts/fly-entrypoint.sh /usr/local/bin/fly-entrypoint.sh

RUN chmod +x /usr/local/bin/fly-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/fly-entrypoint.sh"]
