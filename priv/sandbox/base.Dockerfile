# Phase 3 D-111 - Kiln sandbox shared base.
# Reference base for per-language Dockerfiles.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

RUN addgroup -g 1000 kiln && adduser -D -u 1000 -G kiln kiln

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN mkdir -p /home/kiln/.cache && chown -R kiln:kiln /home/kiln

USER kiln
WORKDIR /workspace

LABEL kiln.image=base \
      kiln.image_purpose="sandbox base - extend per-language"
