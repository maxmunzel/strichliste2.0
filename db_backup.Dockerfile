FROM postgres:13-alpine
LABEL maintainer="maxmunzel"
COPY ./db_backup /etc/periodic/hourly
CMD [ "/usr/sbin/crond", "-f", "-d8" ]
