FROM alpine:latest
RUN apk add --no-cache postgresql-client
COPY init-extensions.sh /init-extensions.sh
RUN chmod +x /init-extensions.sh
CMD ["/init-extensions.sh"]
