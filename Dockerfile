# ---------- 1. Build stage ----------------------------------------------------
# We keep this stage separate so its layers can be cached.
FROM golang:1.22 AS build

# Install the minimal tools Go needs to fetch modules via HTTPS/Git.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Copy ONLY go.mod and go.sum first —
# this lets `go mod download` be cached in CI if the source code hasn’t changed.
COPY go.mod go.sum ./

# Speed & reliability tweaks for CI networks:
#  * try proxy.golang.org first, fall back to a direct Git/HTTPS fetch
#  * leave checksum DB enabled (secure) but override if your runner blocks it
ENV GOPROXY=https://proxy.golang.org,direct \
    GOSUMDB=sum.golang.org

RUN go mod download

# Now bring in the rest of the source tree and build the WhatsApp bridge.
COPY . .
RUN go build -o /bin/bridge ./whatsapp-bridge

# ---------- 2. Runtime stage --------------------------------------------------
# Distroless keeps the final image tiny (~20 MB) and non-root by default.
FROM gcr.io/distroless/base-debian12

# Bridge expects STORE_DIR to hold whatsapp.db / messages.db
WORKDIR /app
ENV STORE_DIR=/data \
    PORT=8080            # startRESTServer listens on :8080

# Copy the statically linked binary from the build stage.
COPY --from=build /bin/bridge .

# Make port visible to orchestration platforms (Railway, Fly, etc.)
EXPOSE 8080

# Launch!
ENTRYPOINT ["/app/bridge"]
