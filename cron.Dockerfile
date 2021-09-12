FROM postgres:13-alpine
LABEL maintainer="maxmunzel"
CMD [ "/usr/sbin/crond", "-f", "-d8" ]
