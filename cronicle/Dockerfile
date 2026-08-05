FROM cronicle/edge:v1.14.4

LABEL org.opencontainers.image.title="cronicle-micasa" \
      org.opencontainers.image.description="Cronicle scheduler with HMS job scripts" \
      org.opencontainers.image.source="https://github.com/RaymondSalim/vps-compose"

RUN mkdir -p /opt/cronicle/logs/hms /opt/cronicle/jobs

COPY --chown=root:root jobs/ /opt/cronicle/jobs/

RUN find /opt/cronicle/jobs -type f -name "*.sh" -exec chmod 755 {} +
