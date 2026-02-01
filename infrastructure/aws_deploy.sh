#!/bin/bash
# AWS Lightsail/EC2 Deployment Script for EFFATA Orchestrator
# Copyright 2025, EFFATA Trading Systems

echo "Starting EFFATA Cloud Deployment..."

# 1. Update System
sudo apt-get update && sudo apt-get upgrade -y

# 2. Install Dependencies
sudo apt-get install -y git wget curl unzip build-essential postgresql postgresql-contrib

# 3. Setup PostgreSQL
# Use environment variables for sensitive information
DB_PASSWORD=${EFFATA_DB_PASSWORD:-$(openssl rand -base64 12)}
sudo -u postgres psql -c "CREATE DATABASE effata_trading;"
sudo -u postgres psql -c "CREATE USER effata_admin WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE effata_trading TO effata_admin;"

# Create tables for Trading Journal
sudo -u postgres psql -d effata_trading -c "
CREATE TABLE IF NOT EXISTS trading_journal (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    account_id TEXT,
    ticket TEXT,
    symbol TEXT,
    action INT,
    lots DOUBLE PRECISION,
    entry_price DOUBLE PRECISION,
    profit DOUBLE PRECISION,
    reasoning TEXT,
    market_state TEXT
);"

echo "Database and tables setup with generated password."

# 4. Install MetaTrader 5 (via Wine if needed for Linux, or just preparation for Windows Instance)
# On Linux:
# sudo dpkg --add-architecture i386
# sudo apt-get update
# sudo apt-get install -y wine32 wine64

# 5. Clone Repository
# git clone https://github.com/adriangainzahuep2/effata.git /opt/effata

# 6. Configure Environment
cat <<EOF > /opt/effata/.env
DB_HOST=localhost
DB_NAME=effata_trading
DB_USER=effata_admin
DB_PASS=$DB_PASSWORD
AWS_REGION=us-east-1
EOF

# 7. Start Services (Python Multi-Broker Hub)
# Create systemd service for EFFATA Data Bridge
cat <<EOF | sudo tee /etc/systemd/system/effata-hub.service
[Unit]
Description=EFFATA Multi-Broker Hub
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/effata/Python/data_bridge.py
WorkingDirectory=/opt/effata/Python
Restart=always
User=ubuntu

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable effata-hub
sudo systemctl start effata-hub

echo "EFFATA Deployment Completed Successfully!"
