FROM alpine:3.16 as base

RUN apk add --no-cache jq curl

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
