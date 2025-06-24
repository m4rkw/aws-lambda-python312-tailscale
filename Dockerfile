FROM amazonlinux:2023 AS builder
RUN dnf install -y gcc python3.12 python3.12-devel pkgconf-pkg-config && dnf clean all
RUN yum groupinstall -y "Development Tools"
RUN yum install -y gcc make openssl-devel readline-devel libproxy libproxy-devel && yum clean all

RUN curl -LO http://www.dest-unreach.org/socat/download/socat-1.8.0.3.tar.gz
RUN tar xzf socat-1.8.0.3.tar.gz -C /root

WORKDIR /root/socat-1.8.0.3

RUN ./configure
RUN make

FROM public.ecr.aws/lambda/python:3.12

COPY --from=builder /root/socat-1.8.0.3/socat /usr/bin/socat

ENV LAMBDA_TASK_ROOT=/var/task
ENV PYTHONPATH=$LAMBDA_TASK_ROOT

COPY --from=docker.io/tailscale/tailscale:stable /usr/local/bin/tailscaled /var/runtime/tailscaled
COPY --from=docker.io/tailscale/tailscale:stable /usr/local/bin/tailscale /var/runtime/tailscale
RUN mkdir -p /var/run && ln -s /tmp/tailscale /var/run/tailscale && \
    mkdir -p /var/cache && ln -s /tmp/tailscale /var/cache/tailscale && \
    mkdir -p /var/lib && ln -s /tmp/tailscale /var/lib/tailscale && \
    mkdir -p /var/task && ln -s /tmp/tailscale /var/task/tailscale

ADD tailscale_bootstrap /var/task/tailscale_bootstrap
ADD uuidgen /var/task/uuidgen

ENTRYPOINT [ "/var/task/tailscale_bootstrap" ]
