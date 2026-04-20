# Phase 3 D-111 - Kiln Elixir sandbox image.
FROM hexpm/elixir:1.19.5-erlang-28.1.1-alpine-3.21

RUN apk add --no-cache git build-base openssl-dev coreutils bash

RUN addgroup -g 1000 kiln && adduser -D -u 1000 -G kiln kiln

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MIX_ENV=test \
    HEX_HOME=/home/kiln/.hex \
    MIX_HOME=/home/kiln/.mix

RUN mkdir -p /home/kiln/.cache /home/kiln/.hex /home/kiln/.mix \
 && chown -R kiln:kiln /home/kiln

USER kiln
WORKDIR /workspace

LABEL kiln.image=elixir \
      kiln.elixir_version=1.19.5 \
      kiln.otp_version=28.1.1 \
      kiln.alpine_version=3.21
