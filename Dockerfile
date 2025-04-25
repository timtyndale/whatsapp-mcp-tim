# ────────── 1. BUILD STAGE ─────────────────────────────────────────────
FROM golang:1.22 AS build

# Basic tools Go falls back to for HTTPS / git fetches
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# All subsequent paths live under /src
WORKDIR /src

# ── Copy ONLY the module manifests (cacheable layer) ──
#    Place them in the same sub-folder structure they have in the repo.
COPY whatsapp-bridge/go.mod whatsapp-bridge/go.sum ./whatsapp-bridge/

# Tell Go: “try proxy.golang.org first, then direct git/https”
ENV GOPROXY=https://proxy.golang.org,direct \
    GOSUMDB=sum.golang.org

# Download deps (cached unless go.mod/go.sum change)
WORKDIR /src/whatsapp-bridge

# 👇 TEMP: print verbose module fetch
RUN GODEBUG=x509roots=1 go mod download -x

RUN go mod download

# ── Copy the rest of the source tree and build the binary ──
WORKDIR /src
COPY . .
RUN cd whatsapp-bridge && go build -o /bin/bridge .

# ────────── 2. RUNTIME STAGE ───────────────────────────────────────────
FROM gcr.io/distroless/base-debian12

WORKDIR /app
ENV STORE_DIR=/data \
    PORT=8080          
    # startRESTServer listens on :8080

# Bring in the static binary
COPY --from=build /bin/bridge .

EXPOSE 8080
ENTRYPOINT ["/app/bridge"]