FROM alpine:3.19
RUN apk add --no-cache ca-certificates tzdata wget
RUN adduser -D -g '' appuser
WORKDIR /app
COPY muchtodo /app/muchtodo
COPY .env /app/.env
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1
ENTRYPOINT ["/app/muchtodo"]
