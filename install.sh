#!/bin/bash

#Variables for running the script
BinaryLocation=/usr/local/bin
PrometheusLibDir=/var/lib/prometheus/
PrometheusConfDir=/etc/prometheus/
LokiConfDir=/etc/loki/
LokiDataDir=/data/loki/
PromtailConfDir=/etc/promtail/
PromtailDataDir=/data/promtail/
LokiVer=v2.8.7
PromtailVer=v2.8.7
NodeExporterVer=1.7.0
PrometheusVer=2.48.1

#Prometheus
echo "Create prometheus user and group"
sudo groupadd --system prometheus 
sudo useradd -s /sbin/nologin --system -g prometheus prometheus

echo "Create prometheus configuration and data directory"
sudo mkdir $PrometheusLibDir
for i in rules rules.d files_sd; do sudo mkdir -p $PrometheusConfDir${i}; done

echo "Download and install prometheus"
sudo apt-get update 
sudo apt-get -y install wget curl unzip zip
wget https://github.com/prometheus/prometheus/releases/download/v${PrometheusVer}/prometheus-${PrometheusVer}.linux-amd64.tar.gz

echo "Move prometheus binary and tools"
tar -xvf prometheus*.tar.gz
sudo cp -R prometheus*/prometheus promtool $BinaryLocation
sudo cp -R prometheus*/consoles/ console_libraries/ $PrometheusConfDir

echo "Copy prometheus configuration in $PrometheusConfDir"
sudo cp -R config/prometheus.yaml $PrometheusConfDir

echo "Create prometheus systemd configuration"
sudo tee /etc/systemd/system/prometheus.service<<EOF
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yaml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.external-url=

SyslogIdentifier=prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Change directory permissions"
for i in rules rules.d files_sd; do sudo chown -R prometheus:prometheus /etc/prometheus/${i}; done
for i in rules rules.d files_sd; do sudo chmod -R 775 /etc/prometheus/${i}; done
sudo chown -R prometheus:prometheus /var/lib/prometheus/

echo "Reload systemd daemon and start prometheus services"
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus

#Node_Exporters
echo "Download node_exporter"
wget https://github.com/prometheus/node_exporter/releases/download/v${NodeExporterVer}/node_exporter-${NodeExporterVer}.linux-amd64.tar.gz

echo "Extract and move binary files"
tar -xvf node_exporter*.tar.gz
sudo cp -R node_exporter*/node_exporter $BinaryLocation

echo "Create node_exporter systemd configuration"
sudo tee /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF

echo "Check node_exporter version"
node_exporter --version

echo "Reload systemd daemon and start node_exporter services"
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter


echo "Restart prometheus services"
sudo systemctl restart prometheus

#Loki
echo "Download loki"
wget https://github.com/grafana/loki/releases/download/${LokiVer}/loki-linux-amd64.zip

echo "Extract and move binary files"
unzip loki-linux-amd64.zip -d loki
sudo chmod a+x loki-linux-amd64
sudo mv loki/loki-linux-amd64 $BinaryLocation/loki

echo "Create loki configuration and data directory"
sudo mkdir $LokiConfDir
sudo mkdir -p $LokiDataDir

echo "Copy loki configuration"
sudo cp -R config/loki-config.yaml $LokiConfDir

echo "Create loki systemd configuration"
sudo tee /etc/systemd/system/loki.service<<EOF
[Unit]
Description=Loki service
After=network.target

[Service]
Type=simple
User=root

ExecStart=/usr/local/bin/loki -config.file /etc/loki/loki-config.yaml

[Install]
WantedBy=multi-user.target
EOF

echo "Reload systemd daemon and start loki services"

sudo systemctl daemon-reload
sudo systemctl start loki
sudo systemctl enable loki

#Promtail
echo "Download promtail"
wget https://github.com/grafana/loki/releases/download/${LokiVer}/promtail-linux-amd64.zip

echo "Extract and move binary files"
unzip promtail-linux-amd64.zip
sudo chmod a+x promtail-linux-amd64
sudo mv promtail-linux-amd64 $BinaryLocation/promtail

echo "Create promtail configuration and data directory"
sudo mkdir $PromtailConfDir
sudo mkdir -p $PromtailDataDir

echo "Copy promtail configuration"
sudo cp -R config/promtail-config.yaml $PromtailConfDir

echo "Create promtail systemd configuration"
sudo tee /etc/systemd/system/promtail.service<<EOF
[Unit]
Description=Promtail service
After=network.targe

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail -config.file /etc/promtail/promtail-config.yaml

[Install]
WantedBy=multi-user.target
EOF

echo "Reload systemd daemon and start loki services"
sudo systemctl daemon-reload
sudo systemctl start promtail
sudo systemctl enable promtail


echo "Check all service"
sudo systemctl is-active node_exporter --quiet && echo "Node Exporter is Running" || echo "Node Exporter Failed to start"
sudo systemctl is-active promtail --quiet && echo "Promtail is Running" || echo "Promtail Failed to start"
sudo systemctl is-active prometheus --quiet && echo "Prometheus is Running" || echo "Prometheus Failed to start"
sudo systemctl is-active loki --quiet && echo "Loki is Running" || echo "Loki Failed to start"
