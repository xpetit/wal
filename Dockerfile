# syntax=docker/dockerfile:1
# For more information, please visit: https://docs.docker.com/language/golang/build-images

# Leverage multi-stage build to reduce the final Docker image size
FROM golang:1.17-alpine as builder

# needed for cgo github.com/mattn/go-sqlite3 dependency
RUN apk add --no-cache build-base

WORKDIR /app

# Download and cache all dependencies of the main module
COPY go.mod go.sum ./
RUN go mod download

# Build program
COPY *.go ./
RUN --mount=type=cache,target=/root/.cache/go-build \
	--mount=type=cache,target=/go/pkg \
	go build -ldflags '-s -w -extldflags "-static"' -o main .


FROM alpine

ADD https://github.com/benbjohnson/litestream/releases/download/v0.3.7/litestream-v0.3.7-linux-amd64-static.tar.gz /tmp/
RUN tar -C /usr/local/bin -xf /tmp/litestream-v0.3.7-linux-amd64-static.tar.gz
RUN rm /tmp/litestream-v0.3.7-linux-amd64-static.tar.gz

RUN apk add --no-cache wrk sqlite curl openssh-server openssh-sftp-server openrc

RUN passwd -d root
RUN rc-update add sshd
RUN mkdir -p /run/openrc/softlevel
RUN echo 'PermitEmptyPasswords yes' >> /etc/ssh/sshd_config
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

COPY script.sh .
COPY --from=builder /app/main .

CMD ["sh", "script.sh"]
