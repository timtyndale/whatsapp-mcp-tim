# ---------- build stage ----------
    FROM golang:1.22 AS build
    WORKDIR /src
    COPY . .
    RUN go mod download
    RUN go build -o /bin/bridge ./whatsapp-bridge
    
    # ---------- runtime stage ----------
    FROM gcr.io/distroless/base-debian12
    WORKDIR /app
    COPY --from=build /bin/bridge .
    ENV STORE_DIR=/data \
        PORT=8080
    EXPOSE 8080
    ENTRYPOINT ["/app/bridge"]
