#!/bin/bash

set -e

echo "🔧 Installing dependencies..."
sudo dnf install -y wget tar

# ---------- PROMETHEUS ----------
echo "📦 Installing Prometheus..."

cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.43.0/prometheus-2.43.0.linux-amd64.tar.gz
tar -xf prometheus-2.43.0.linux-amd64.tar.gz
sudo mv prometheus-2.43.0.linux-amd64/prometheus prometheus-2.43.0.linux-amd64/promtool /usr/local/bin/

sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo mv prometheus-2.43.0.linux-amd64/console_libraries prometheus-2.43.0.linux-amd64/consoles /etc/prometheus
rm -rf prometheus-2.43.0.linux-amd64*

cat <<EOF | sudo tee /etc/prometheus/prometheus.yml
global:
  scrape_interval: 10s

scrape_configs:
  - job_name: 'prometheus_metrics'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node_exporter_metrics'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9100', 'worker-1:9100', 'worker-2:9100']
EOF

sudo useradd -rs /bin/false prometheus
sudo chown -R prometheus: /etc/prometheus /var/lib/prometheus

cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
sudo systemctl status prometheus --no-pager


# ---------- GRAFANA ----------
echo "📦 Installing Grafana (v10.4.1)..."

cd /tmp
wget https://dl.grafana.com/oss/release/grafana-10.4.1-1.x86_64.rpm
sudo dnf install -y ./grafana-10.4.1-1.x86_64.rpm

sudo systemctl enable --now grafana-server
sudo systemctl status grafana-server --no-pager


# ---------- NODE EXPORTER ----------
echo "📦 Installing Node Exporter..."

cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz
tar -xf node_exporter-1.5.0.linux-amd64.tar.gz
sudo mv node_exporter-1.5.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.5.0.linux-amd64*

sudo useradd -rs /bin/false node_exporter

cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl status node_exporter --no-pager

echo "✅ Prometheus, Grafana, and Node Exporter setup is complete on Amazon Linux 2023!"
