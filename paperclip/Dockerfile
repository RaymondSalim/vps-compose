FROM ghcr.io/paperclipai/paperclip:latest

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends unzip less; \
    rm -rf /var/lib/apt/lists/*; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) aws_arch="x86_64" ;; \
        arm64) aws_arch="aarch64" ;; \
        *) echo "Unsupported architecture: $arch"; exit 1 ;; \
    esac; \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip" -o /tmp/awscliv2.zip; \
    unzip -q /tmp/awscliv2.zip -d /tmp; \
    /tmp/aws/install; \
    rm -rf /tmp/aws /tmp/awscliv2.zip; \
    npm install -g --omit=dev paperclipai@latest; \
    npm cache clean --force; \
    rm -rf /root/.npm; \
    aws --version; \
    paperclipai --version
