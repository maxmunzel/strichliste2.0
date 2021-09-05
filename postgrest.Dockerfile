FROM alpine
LABEL maintainer="maxmunzel"


#WORKDIR /tmp

COPY ./postgrest ./
RUN ["mkdir", "/conf"]
# RUN ["touch", "postgREST.conf"]
EXPOSE 3000
CMD ["./postgrest", "/conf/postgREST.conf"]
