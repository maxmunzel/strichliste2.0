FROM golang:alpine
LABEL maintainer="maxmunzel"
RUN mkdir /go/src/auth_server
WORKDIR "/go/src/auth_server"
RUN ["go", "mod", "init"]
RUN ["go", "get", "golang.org/x/crypto/sha3"]
CMD ["go",  "run",  "auth_server.go"]
