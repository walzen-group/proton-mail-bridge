# renovate: datasource=github-releases depName=ProtonMail/proton-bridge
ARG BRIDGE_VERSION=3.27.1

FROM golang:1.26-trixie AS build
ARG BRIDGE_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends libsecret-1-dev libfido2-dev libcbor-dev libssl-dev pkg-config git make \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "v${BRIDGE_VERSION}" https://github.com/ProtonMail/proton-bridge /src
WORKDIR /src
RUN make build-nogui

FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      pass gnupg libsecret-1-0 libfido2-1 ca-certificates golang-docker-credential-helpers \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --uid 1000 --create-home --home-dir /home/bridge bridge
COPY --from=build /src/bridge /usr/local/bin/bridge
COPY start.sh /usr/local/bin/start.sh
USER 1000
ENV HOME=/home/bridge
ENTRYPOINT ["/usr/local/bin/start.sh"]
CMD ["--noninteractive"]
