FROM grafana/grafana
USER root
WORKDIR /var/lib/grafana/plugins
RUN apk add git
RUN git clone https://github.com/JamesOsgood/mongodb-grafana.git

WORKDIR /var/lib/grafana/plugins/mongodb-grafana
RUN apk add nodejs-current-npm
