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

COPY .build .build
RUN go build ./.build

# Build program
COPY main.go .
# -ldflags "-s -w" reduces the binary size (-s: disable symbol table, -w: disable DWARF generation)
RUN go build -ldflags "-s -w" -o main .


FROM alpine

RUN apk add --no-cache wrk sqlite curl

# Create unprivileged user for the service
# -D: Don't assign a password
RUN adduser -D user
USER user:user

WORKDIR /home/user

COPY script.sh .

# Copy binary
COPY --from=builder /app/main .

CMD ["sh", "/home/user/script.sh"]
