FROM golang:alpine
LABEL maintainer="maxmunzel"
RUN mkdir /go/src/api
WORKDIR "/go/src/api"
RUN ["go", "mod", "init"]
RUN ["go", "get", "golang.org/x/crypto/sha3"]
RUN ["go", "get", "golang.org/x/image/draw"]
CMD ["go",  "run",  "api.go"]
