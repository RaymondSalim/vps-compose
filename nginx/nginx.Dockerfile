FROM nginx:1.27.5-alpine3.21

LABEL org.opencontainers.image.title="nginx-vps-compose" \
      org.opencontainers.image.source="https://github.com/RaymondSalim/vps-compose"

RUN apk add --no-cache certbot \
    && mkdir -p /etc/nginx/ssl /usr/share/nginx/html

COPY nginx.conf /etc/nginx/nginx.conf

WORKDIR /usr/share/nginx/html

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
