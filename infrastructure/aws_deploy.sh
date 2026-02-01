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
echo "Database setup with generated password."

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

# 7. Start Services (Python Orchestrator Agents)
# nohup python3 /opt/effata/Python/main.py > /var/log/effata.log 2>&1 &

echo "EFFATA Deployment Completed Successfully!"
