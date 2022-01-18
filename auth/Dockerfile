FROM golang:alpine
LABEL maintainer="maxmunzel"
RUN mkdir /go/src/auth_server
WORKDIR "/go/src/auth_server"
COPY auth .
RUN ["go", "build"]
CMD ["go",  "run",  "auth_server.go"]
