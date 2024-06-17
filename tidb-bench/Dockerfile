FROM alpine:latest

RUN apk add --no-cache mysql-client sysbench

COPY sysbench /sysbench

WORKDIR /sysbench/

ENTRYPOINT ["/sysbench/entrypoint.sh"]
