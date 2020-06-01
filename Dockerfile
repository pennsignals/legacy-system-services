FROM grafana/grafana

# Install npm and setup mongodb proxy (https://github.com/JamesOsgood/mongodb-grafana.git)
USER root
WORKDIR /var/lib/grafana/plugins
RUN apk add git
RUN git clone https://github.com/JamesOsgood/mongodb-grafana.git

WORKDIR /var/lib/grafana/plugins/mongodb-grafana
RUN apk add nodejs-current-npm
RUN npm install
# TODO: npm run server in background

EXPOSE 3333
RUN nohup bash -c "npm run server &" && sleep 5

# reset to grafana user and workdir
WORKDIR /usr/share/grafana
USER grafana