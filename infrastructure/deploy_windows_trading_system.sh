```bash
#!/bin/bash
# deploy_windows_trading_system.sh - Complete AWS deployment script for Windows trading system
# This script automates the deployment of a production trading system on Windows EC2 instances in AWS
# Usage: ./deploy_windows_trading_system.sh [environment] [region]
# Example: ./deploy_windows_trading_system.sh production us-east-1

set -e  # Exit on any error

# Default configuration
ENVIRONMENT=${1:-production}
AWS_REGION=${2:-us-east-1}
DEPLOYMENT_ID=$(date +%Y%m%d%H%M%S)
STACK_NAME="trading-system-${ENVIRONMENT}-${DEPLOYMENT_ID}"
KEY_NAME="trading-system-${ENVIRONMENT}-key"
S3_BUCKET_NAME="trading-system-${ENVIRONMENT}-assets-${DEPLOYMENT_ID}"
LOG_GROUP_NAME="/aws/ec2/trading-system-${ENVIRONMENT}"

# Trading system configuration
ADMIN_EMAIL="adriangainzahuep@gmail.com"
INSTANCE_TYPE="m5.2xlarge"  # Windows requires more resources
INSTANCE_COUNT=2  # For load balancing
DATABASE_INSTANCE_CLASS="db.t4g.large"
DATABASE_NAME="effata"
DATABASE_USERNAME="effata123.*"

# Generate secure passwords
ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9!@#$%^&*_-' | head -c 16)
DATABASE_PASSWORD=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9!@#$%^&*_-' | head -c 16)
API_KEYS_PASSWORD=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9!@#$%^&*_-' | head -c 16)



# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting deployment of Windows Trading System to AWS (${ENVIRONMENT} environment)${NC}"
echo -e "${BLUE}Region: ${AWS_REGION} | Stack: ${STACK_NAME}${NC}"

# Validate AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed. Please install AWS CLI first.${NC}"
    exit 1
fi

if ! aws sts get-caller-identity --region ${AWS_REGION} &> /dev/null; then
    echo -e "${RED}AWS CLI is not configured properly. Please run 'aws configure' first.${NC}"
    exit 1
fi

# Create deployment directory
DEPLOYMENT_DIR="deployment-${ENVIRONMENT}-${DEPLOYMENT_ID}"
mkdir -p ${DEPLOYMENT_DIR}/{scripts,config,keys,logs}
echo "Created deployment directory: ${DEPLOYMENT_DIR}"

# Save deployment configuration
cat > ${DEPLOYMENT_DIR}/deployment-config.json <<EOF
{
  "environment": "${ENVIRONMENT}",
  "region": "${AWS_REGION}",
  "deployment_id": "${DEPLOYMENT_ID}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stack_name": "${STACK_NAME}",
  "admin_email": "${ADMIN_EMAIL}",
  "instance_type": "${INSTANCE_TYPE}",
  "instance_count": ${INSTANCE_COUNT},
  "database_name": "${DATABASE_NAME}"
}
EOF

echo -e "${GREEN}✅ Deployment configuration saved to ${DEPLOYMENT_DIR}/deployment-config.json${NC}"

# Step 1: Create VPC with public and private subnets
echo -e "${BLUE}🔧 Creating VPC infrastructure...${NC}"

# Create VPC
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${STACK_NAME}-vpc},{Key=Environment,Value=${ENVIRONMENT}}]" \
    --region ${AWS_REGION} \
    --query 'Vpc.VpcId' \
    --output text)

echo -e "${GREEN}✅ VPC created: ${VPC_ID}${NC}"

# Enable DNS support and hostname
aws ec2 modify-vpc-attribute --vpc-id ${VPC_ID} --enable-dns-support "{\"Value\":true}"
aws ec2 modify-vpc-attribute --vpc-id ${VPC_ID} --enable-dns-hostnames "{\"Value\":true}"

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${STACK_NAME}-igw},{Key=Environment,Value=${ENVIRONMENT}}]" \
    --region ${AWS_REGION} \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

# Attach Internet Gateway to VPC
aws ec2 attach-internet-gateway --vpc-id ${VPC_ID} --internet-gateway-id ${IGW_ID} --region ${AWS_REGION}
echo -e "${GREEN}✅ Internet Gateway created and attached: ${IGW_ID}${NC}"

# Create route table for public subnet
PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
    --vpc-id ${VPC_ID} \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${STACK_NAME}-public-rt},{Key=Environment,Value=${ENVIRONMENT}}]" \
    --region ${AWS_REGION} \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Create route to Internet Gateway
aws ec2 create-route \
    --route-table-id ${PUBLIC_ROUTE_TABLE_ID} \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id ${IGW_ID} \
    --region ${AWS_REGION}

echo -e "${GREEN}✅ Public route table created: ${PUBLIC_ROUTE_TABLE_ID}${NC}"

# Create public and private subnets in two availability zones
AZ1=$(aws ec2 describe-availability-zones \
    --region ${AWS_REGION} \
    --query 'AvailabilityZones[0].ZoneName' \
    --output text)

AZ2=$(aws ec2 describe-availability-zones \
    --region ${AWS_REGION} \
    --query 'AvailabilityZones[1].ZoneName' \
    --output text)

echo -e "${BLUE}Creating subnets in Availability Zones: ${AZ1} and ${AZ2}${NC}"

# Public Subnets
PUBLIC_SUBNET_1_ID=$(aws ec2 create-subnet \
    --vpc-id ${VPC_ID} \
    --cidr-block 10.0.1.0/24 \
    --availability-zone ${AZ1} \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${STACK_NAME}-public-1},{Key=Environment,Value=${ENVIRONMENT}}]" \
    --region ${AWS_REGION} \
    --query 'Subnet.SubnetId' \
    --output text)

PUBLIC_SUBNET_2_ID=$(aws ec2 create-subnet \
    --vpc-id ${VPC_ID} \
    --cidr-block 10.0.2.0/24 \
    --availability-zone ${AZ2} \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${STACK_NAME}-public-2},{Key=Environment,Value=${ENVIRONMENT}}]" \
    --region ${AWS_REGION} \
    --query 'Subnet.SubnetId' \
    --output text)

# Associate public subnets with route table
aws ec2 associate-route-table \
    --route-table-id ${PUBLIC_ROUTE_TABLE_ID} \
    --subnet-id ${PUBLIC_SUBNET_1_ID} \
    --region ${AWS_REGION}

aws ec2 associate-route-table \
    --route-table-id ${PUBLIC_ROUTE_TABLE_ID} \
    --subnet-id ${PUBLIC_SUBNET_2_ID} \
    --region ${AWS_REGION}

# Enable auto-assign public IP for public subnets
aws ec2 modify-subnet-attribute \
    --subnet-id ${PUBLIC_SUBNET_1_ID} \
    --map-public-ip-on-launch \
    --region ${AWS_REGION}

aws ec2 modify-subnet-attribute \
    --subnet-id ${PUBLIC_SUBNET_2_ID} \
    --map-public-ip-on-launch \
    --region ${AWS_REGION}

# Private Subnets (for database)
PRIVATE_SUBNET_1_ID=$(aws ec2 create-subnet \
    --vpc-id ${VPC_ID} \
    --cidr-block 10.0.3.0/24 \
    --availability-zone ${AZ1} \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${STACK_NAME}-private-1},{Key=Environment,Value=${ENVIRONMENT}}]" \
    --region ${AWS_REGION} \
    --query 'Subnet.SubnetId' \
    --output text)

PRIVATE_SUBNET_2_ID=$(aws ec2 create-subnet \
    --vpc-id ${VPC_ID} \
    --cidr-block 10.0.4.0/24 \
    --availability-zone ${AZ2} \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${STACK_NAME}-private-2},{Key=Environment,Value=${ENVIRONMENT}}]" \
    --region ${AWS_REGION} \
    --query 'Subnet.SubnetId' \
    --output text)

echo -e "${GREEN}✅ Subnets created:${NC}"
echo -e "   Public Subnet 1: ${PUBLIC_SUBNET_1_ID} (${AZ1})"
echo -e "   Public Subnet 2: ${PUBLIC_SUBNET_2_ID} (${AZ2})"
echo -e "   Private Subnet 1: ${PRIVATE_SUBNET_1_ID} (${AZ1})"
echo -e "   Private Subnet 2: ${PRIVATE_SUBNET_2_ID} (${AZ2})"

# Step 2: Create Security Groups
echo -e "${BLUE}🛡️ Creating Security Groups...${NC}"

# Application Security Group (public facing)
APP_SG_ID=$(aws ec2 create-security-group \
    --group-name "${STACK_NAME}-app-sg" \
    --description "Security group for trading application servers" \
    --vpc-id ${VPC_ID} \
    --region ${AWS_REGION} \
    --query 'GroupId' \
    --output text)

# Database Security Group (private)
DB_SG_ID=$(aws ec2 create-security-group \
    --group-name "${STACK_NAME}-db-sg" \
    --description "Security group for database servers" \
    --vpc-id ${VPC_ID} \
    --region ${AWS_REGION} \
    --query 'GroupId' \
    --output text)

# Load Balancer Security Group
LB_SG_ID=$(aws ec2 create-security-group \
    --group-name "${STACK_NAME}-lb-sg" \
    --description "Security group for load balancer" \
    --vpc-id ${VPC_ID} \
    --region ${AWS_REGION} \
    --query 'GroupId' \
    --output text)

# Bastion Host Security Group (for administrative access)
BASTION_SG_ID=$(aws ec2 create-security-group \
    --group-name "${STACK_NAME}-bastion-sg" \
    --description "Security group for bastion host" \
    --vpc-id ${VPC_ID} \
    --region ${AWS_REGION} \
    --query 'GroupId' \
    --output text)

echo -e "${GREEN}✅ Security Groups created:${NC}"
echo -e "   Application SG: ${APP_SG_ID}"
echo -e "   Database SG: ${DB_SG_ID}"
echo -e "   Load Balancer SG: ${LB_SG_ID}"
echo -e "   Bastion Host SG: ${BASTION_SG_ID}"

# Configure security group rules

# Load Balancer Security Group rules
aws ec2 authorize-security-group-ingress \
    --group-id ${LB_SG_ID} \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region ${AWS_REGION}

aws ec2 authorize-security-group-ingress \
    --group-id ${LB_SG_ID} \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region ${AWS_REGION}

# Application Security Group rules (allow from LB and bastion)
aws ec2 authorize-security-group-ingress \
    --group-id ${APP_SG_ID} \
    --protocol tcp \
    --port 3389 \
    --source-group ${BASTION_SG_ID} \
    --region ${AWS_REGION}

aws ec2 authorize-security-group-ingress \
    --group-id ${APP_SG_ID} \
    --protocol tcp \
    --port 5985 \
    --source-group ${BASTION_SG_ID} \
    --region ${AWS_REGION}

aws ec2 authorize-security-group-ingress \
    --group-id ${APP_SG_ID} \
    --protocol tcp \
    --port 5986 \
    --source-group ${BASTION_SG_ID} \
    --region ${AWS_REGION}

aws ec2 authorize-security-group-ingress \
    --group-id ${APP_SG_ID} \
    --protocol tcp \
    --port 443 \
    --source-group ${LB_SG_ID} \
    --region ${AWS_REGION}

aws ec2 authorize-security-group-ingress \
    --group-id ${APP_SG_ID} \
    --protocol tcp \
    --port 5555 \  # For browser service API
    --source-group ${LB_SG_ID} \
    --region ${AWS_REGION}

# Database Security Group rules (only allow from app servers)
aws ec2 authorize-security-group-ingress \
    --group-id ${DB_SG_ID} \
    --protocol tcp \
    --port 5432 \
    --source-group ${APP_SG_ID} \
    --region ${AWS_REGION}

aws ec2 authorize-security-group-ingress \
    --group-id ${DB_SG_ID} \
    --protocol tcp \
    --port 1433 \
    --source-group ${APP_SG_ID} \
    --region ${AWS_REGION}

# Bastion Security Group rules (only allow SSH/RDP from admin IP)
ADMIN_IP=$(curl -s https://checkip.amazonaws.com)
echo -e "${BLUE}Detected admin IP: ${ADMIN_IP}${NC}"

aws ec2 authorize-security-group-ingress \
    --group-id ${BASTION_SG_ID} \
    --protocol tcp \
    --port 3389 \
    --cidr ${ADMIN_IP}/32 \
    --region ${AWS_REGION}

echo -e "${GREEN}✅ Security Group rules configured${NC}"

# Step 3: Create IAM Roles and Policies with Least Privilege
echo -e "${BLUE}🔐 Creating IAM Roles and Policies with Least Privilege...${NC}"

# Create IAM policy for EC2 instances
cat > ${DEPLOYMENT_DIR}/ec2-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": "arn:aws:secretsmanager:${AWS_REGION}:*:secret:${STACK_NAME}-*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${S3_BUCKET_NAME}",
                "arn:aws:s3:::${S3_BUCKET_NAME}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams"
            ],
            "Resource": "arn:aws:logs:${AWS_REGION}:*:log-group:${LOG_GROUP_NAME}:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeAssociation",
                "ssm:GetDeployablePatchSnapshotForInstance",
                "ssm:GetDocument",
                "ssm:DescribeDocument",
                "ssm:GetManifest",
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:ListAssociations",
                "ssm:ListInstanceAssociations",
                "ssm:PutInventory",
                "ssm:PutComplianceItems",
                "ssm:PutConfigurePackageResult",
                "ssm:UpdateAssociationStatus",
                "ssm:UpdateInstanceAssociationStatus",
                "ssm:UpdateInstanceInformation"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2messages:AcknowledgeMessage",
                "ec2messages:DeleteMessage",
                "ec2messages:FailMessage",
                "ec2messages:GetEndpoint",
                "ec2messages:GetMessages",
                "ec2messages:SendReply"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Create the policy
POLICY_ARN=$(aws iam create-policy \
    --policy-name "${STACK_NAME}-ec2-policy" \
    --policy-document file://${DEPLOYMENT_DIR}/ec2-policy.json \
    --description "Least privilege policy for trading system EC2 instances" \
    --region ${AWS_REGION} \
    --query 'Policy.Arn' \
    --output text)

echo -e "${GREEN}✅ Created EC2 IAM Policy: ${POLICY_ARN}${NC}"

# Create IAM role for EC2 instances
cat > ${DEPLOYMENT_DIR}/ec2-trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

ROLE_NAME="${STACK_NAME}-ec2-role"
aws iam create-role \
    --role-name ${ROLE_NAME} \
    --assume-role-policy-document file://${DEPLOYMENT_DIR}/ec2-trust-policy.json \
    --description "Role for trading system EC2 instances" \
    --region ${AWS_REGION}

# Attach the policy to the role
aws iam attach-role-policy \
    --role-name ${ROLE_NAME} \
    --policy-arn ${POLICY_ARN} \
    --region ${AWS_REGION}

# Create instance profile
aws iam create-instance-profile \
    --instance-profile-name "${STACK_NAME}-ec2-profile" \
    --region ${AWS_REGION}

aws iam add-role-to-instance-profile \
    --instance-profile-name "${STACK_NAME}-ec2-profile" \
    --role-name ${ROLE_NAME} \
    --region ${AWS_REGION}

echo -e "${GREEN}✅ Created EC2 IAM Role and Instance Profile${NC}"

# Step 4: Create S3 bucket for assets and backups
echo -e "${BLUE}📦 Creating S3 bucket for assets and backups...${NC}"

aws s3api create-bucket \
    --bucket ${S3_BUCKET_NAME} \
    --region ${AWS_REGION} \
    --create-bucket-configuration LocationConstraint=${AWS_REGION}

# Configure bucket encryption
aws s3api put-bucket-encryption \
    --bucket ${S3_BUCKET_NAME} \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }' \
    --region ${AWS_REGION}

# Enable versioning for backups
aws s3api put-bucket-versioning \
    --bucket ${S3_BUCKET_NAME} \
    --versioning-configuration Status=Enabled \
    --region ${AWS_REGION}

# Set bucket policy for access control
cat > ${DEPLOYMENT_DIR}/bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${S3_BUCKET_NAME}/public/*",
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "true"
                }
            }
        },
        {
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": "arn:aws:s3:::${S3_BUCKET_NAME}/backups/*",
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
EOF

aws s3api put-bucket-policy \
    --bucket ${S3_BUCKET_NAME} \
    --policy file://${DEPLOYMENT_DIR}/bucket-policy.json \
    --region ${AWS_REGION}

# Configure lifecycle policy for backups
cat > ${DEPLOYMENT_DIR}/lifecycle-policy.json <<EOF
{
    "Rules": [
        {
            "ID": "DailyBackupsExpiration",
            "Status": "Enabled",
            "Prefix": "backups/daily/",
            "Expiration": {
                "Days": 14
            },
            "Transitions": [
                {
                    "Days": 7,
                    "StorageClass": "STANDARD_IA"
                }
            ]
        },
        {
            "ID": "WeeklyBackupsExpiration",
            "Status": "Enabled",
            "Prefix": "backups/weekly/",
            "Expiration": {
                "Days": 60
            }
        },
        {
            "ID": "MonthlyBackupsExpiration",
            "Status": "Enabled",
            "Prefix": "backups/monthly/",
            "Expiration": {
                "Days": 365
            }
        },
        {
            "ID": "ScreenshotsExpiration",
            "Status": "Enabled",
            "Prefix": "screenshots/",
            "Expiration": {
                "Days": 7
            }
        }
    ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
    --bucket ${S3_BUCKET_NAME} \
    --lifecycle-configuration file://${DEPLOYMENT_DIR}/lifecycle-policy.json \
    --region ${AWS_REGION}

echo -e "${GREEN}✅ S3 bucket created and configured: ${S3_BUCKET_NAME}${NC}"

# Step 6: Create RDS SQL Server database in private subnet
echo -e "${BLUE}🗄️ Creating RDS SQL Server database...${NC}"

DB_SUBNET_GROUP_NAME="${STACK_NAME}-db-subnet-group"
aws rds create-db-subnet-group \
    --db-subnet-group-name ${DB_SUBNET_GROUP_NAME} \
    --db-subnet-group-description "Subnet group for trading system database" \
    --subnet-ids ${PRIVATE_SUBNET_1_ID} ${PRIVATE_SUBNET_2_ID} \
    --tags Key=Environment,Value=${ENVIRONMENT} Key=DeploymentId,Value=${DEPLOYMENT_ID} \
    --region ${AWS_REGION}

DB_INSTANCE_IDENTIFIER="${STACK_NAME}-db"
aws rds create-db-instance \
    --db-instance-identifier ${DB_INSTANCE_IDENTIFIER} \
    --db-instance-class ${DATABASE_INSTANCE_CLASS} \
    --engine sqlserver-se \
    --engine-version 15.00.4198.2.v1 \
    --master-username ${DATABASE_USERNAME} \
    --master-user-password ${DATABASE_PASSWORD} \
    --allocated-storage 100 \
    --storage-type gp3 \
    --storage-encrypted \
    --db-subnet-group-name ${DB_SUBNET_GROUP_NAME} \
    --vpc-security-group-ids ${DB_SG_ID} \
    --backup-retention-period 7 \
    --preferred-backup-window "03:00-04:00" \
    --preferred-maintenance-window "mon:04:00-mon:04:30" \
    --multi-az \
    --tags Key=Environment,Value=${ENVIRONMENT} Key=DeploymentId,Value=${DEPLOYMENT_ID} \
    --region ${AWS_REGION}

echo -e "${YELLOW}⏳ Waiting for database to be available...${NC}"
aws rds wait db-instance-available \
    --db-instance-identifier ${DB_INSTANCE_IDENTIFIER} \
    --region ${AWS_REGION}

DB_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier ${DB_INSTANCE_IDENTIFIER} \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text \
    --region ${AWS_REGION})

# Update the database secret with the endpoint
aws secretsmanager update-secret \
    --secret-id ${DB_SECRET_ARN} \
    --secret-string "$(echo ${DB_SECRETS} | jq --arg host ${DB_ENDPOINT} '.host = $host')" \
    --region ${AWS_REGION}

echo -e "${GREEN}✅ Database created: ${DB_ENDPOINT}${NC}"

# Step 7: Create Windows EC2 instances with user data
echo -e "${BLUE}🖥️ Creating Windows EC2 instances...${NC}"

# Create Windows AMI search to get the latest Windows Server 2022 image
WINDOWS_AMI=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=Windows_Server-2022-English-Full-Base*" \
              "Name=state,Values=available" \
    --query 'Images | sort_by(@, &CreationDate) | reverse(@) | [0].ImageId' \
    --region ${AWS_REGION} \
    --output text)

echo -e "${BLUE}Using Windows AMI: ${WINDOWS_AMI}${NC}"

# Create user data script for Windows instances (Base64 encoded PowerShell)
cat > ${DEPLOYMENT_DIR}/windows-userdata.ps1 <<EOF
<powershell>
# Download and install required components
Set-ExecutionPolicy Bypass -Scope Process -Force

# Install AWS Tools for PowerShell
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name AWSPowerShell -Force

# Install Chocolatey package manager
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install required software
choco install googlechrome -y
choco install firefox -y
choco install vscode -y
choco install python310 --version=3.10.11 -y
choco install nodejs-lts -y
choco install git -y
choco install vcredist140 -y
choco install mssql-server-express -y
choco install awscli -y

# Install Python packages
pip install boto3 requests pandas numpy sqlalchemy pyodbc playwright selenium

# Install Playwright browsers
python -m playwright install chromium
python -m playwright install firefox
python -m playwright install webkit

# Create application directories
New-Item -Path "C:\\TradingSystem" -ItemType Directory -Force
New-Item -Path "C:\\TradingSystem\\logs" -ItemType Directory -Force
New-Item -Path "C:\\TradingSystem\\data" -ItemType Directory -Force
New-Item -Path "C:\\TradingSystem\\scripts" -ItemType Directory -Force
New-Item -Path "C:\\TradingSystem\\screenshots" -ItemType Directory -Force

# Download application code from S3
Copy-S3Object -BucketName "${S3_BUCKET_NAME}" -Key "app/trading-system.zip" -LocalFile "C:\\TradingSystem\\trading-system.zip"

# Extract application
Expand-Archive -Path "C:\\TradingSystem\\trading-system.zip" -DestinationPath "C:\\TradingSystem\\app" -Force

# Configure environment variables
[System.Environment]::SetEnvironmentVariable("TRADING_ENV", "${ENVIRONMENT}", "Machine")
[System.Environment]::SetEnvironmentVariable("AWS_REGION", "${AWS_REGION}", "Machine")
[System.Environment]::SetEnvironmentVariable("DEPLOYMENT_ID", "${DEPLOYMENT_ID}", "Machine")
[System.Environment]::SetEnvironmentVariable("DATABASE_HOST", "${DB_ENDPOINT}", "Machine")
[System.Environment]::SetEnvironmentVariable("LOG_GROUP_NAME", "${LOG_GROUP_NAME}", "Machine")

# Set up scheduled tasks for backups
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\\TradingSystem\\scripts\\backup.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName "TradingSystemDailyBackup" -Action $action -Trigger $trigger -Principal $principal -Settings $settings

# Configure Windows services for the trading applications
New-Service -Name "TradingSystemService" -BinaryPathName "C:\\TradingSystem\\app\\TradeService.exe" -DisplayName "Trading System Service" -StartupType Automatic

# Configure firewall rules
New-NetFirewallRule -DisplayName "Trading System API" -Direction Inbound -Protocol TCP -LocalPort 5555 -Action Allow
New-NetFirewallRule -DisplayName "Trading System Web Interface" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow

# Install and configure CloudWatch agent
$cloudWatchConfig = @'
{
    "agent": {
        "metrics_collection_interval": 60,
        "logfile": "C:\\ProgramData\\Amazon\\AmazonCloudWatchAgent\\Logs\\amazon-cloudwatch-agent.log"
    },
    "metrics": {
        "metrics_collected": {
            "LogicalDisk": {
                "measurement": [
                    "% Free Space",
                    "% Disk Read Time",
                    "% Disk Write Time",
                    "Disk Read Bytes/sec",
                    "Disk Write Bytes/sec"
                ],
                "resources": ["*"],
                "metrics_collection_interval": 60
            },
            "Memory": {
                "measurement": [
                    "% Committed Bytes In Use",
                    "Available MBytes",
                    "Page Faults/sec"
                ],
                "metrics_collection_interval": 60
            },
            "Network Interface": {
                "measurement": [
                    "Bytes Sent/sec",
                    "Bytes Received/sec",
                    "Packets Sent/sec",
                    "Packets Received/sec"
                ],
                "resources": ["*"],
                "metrics_collection_interval": 60
            },
            "Processor": {
                "measurement": [
                    "% User Time",
                    "% Idle Time",
                    "% Processor Time"
                ],
                "resources": ["_Total"],
                "metrics_collection_interval": 60
            },
            "TCP": {
                "measurement": [
                    "Connections Established"
                ],
                "metrics_collection_interval": 60
            }
        },
        "append_dimensions": {
            "InstanceId": "${aws:InstanceId}",
            "InstanceType": "${aws:InstanceType}",
            "ImageId": "${aws:ImageId}"
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "C:\\TradingSystem\\logs\\application.log",
                        "log_group_name": "${LOG_GROUP_NAME}",
                        "log_stream_name": "application-{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "C:\\TradingSystem\\logs\\trading.log",
                        "log_group_name": "${LOG_GROUP_NAME}",
                        "log_stream_name": "trading-{instance_id}",
                        "timezone": "UTC"
                    }
                ]
            }
        },
        "force_flush_interval": 15
    }
}
'@

$cloudWatchConfig | Out-File -FilePath "C:\\ProgramData\\Amazon\\AmazonCloudWatchAgent\\config.json" -Encoding ascii

# Start CloudWatch agent
Start-Service AmazonCloudWatchAgent

# Start the trading services
Start-Service TradingSystemService

# Send notification that instance is ready
Send-MailMessage -From "trading-system@${ENVIRONMENT}.com" -To "${ADMIN_EMAIL}" -Subject "Trading System Instance Ready" -Body "Instance $(hostname) is now ready and operational." -SmtpServer "smtp-relay.gmail.com"
</powershell>
EOF

# Base64 encode the PowerShell script for user data
USER_DATA=$(base64 -w0 ${DEPLOYMENT_DIR}/windows-userdata.ps1)

# Create Windows EC2 instances
INSTANCE_IDS=()
for i in $(seq 1 ${INSTANCE_COUNT}); do
    echo -e "${BLUE}Creating Windows instance ${i} of ${INSTANCE_COUNT}...${NC}"

    # Alternate between subnets for high availability
    if [ $((i % 2)) -eq 0 ]; then
        SUBNET_ID=${PUBLIC_SUBNET_1_ID}
    else
        SUBNET_ID=${PUBLIC_SUBNET_2_ID}
    fi

    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id ${WINDOWS_AMI} \
        --instance-type ${INSTANCE_TYPE} \
        --key-name ${KEY_NAME} \
        --security-group-ids ${APP_SG_ID} \
        --subnet-id ${SUBNET_ID} \
        --iam-instance-profile Name="${STACK_NAME}-ec2-profile" \
        --user-data file://${DEPLOYMENT_DIR}/windows-userdata.ps1 \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${STACK_NAME}-app-${i}},{Key=Environment,Value=${ENVIRONMENT}},{Key=DeploymentId,Value=${DEPLOYMENT_ID}}]" \
        --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":100,\"VolumeType\":\"gp3\",\"Encrypted\":true}}]" \
        --region ${AWS_REGION} \
        --query 'Instances[0].InstanceId' \
        --output text)

    INSTANCE_IDS+=("${INSTANCE_ID}")
    echo -e "${GREEN}✅ Created Windows instance ${i}: ${INSTANCE_ID}${NC}"

    # Wait a moment before creating the next instance
    sleep 5
done

# Wait for instances to be running
echo -e "${YELLOW}⏳ Waiting for Windows instances to be running...${NC}"
for INSTANCE_ID in "${INSTANCE_IDS[@]}"; do
    aws ec2 wait instance-running --instance-ids ${INSTANCE_ID} --region ${AWS_REGION}
done

echo -e "${GREEN}✅ All Windows instances are now running${NC}"

# Step 8: Create Load Balancer
echo -e "${BLUE}⚖️ Creating Application Load Balancer...${NC}"

# Create target group for instances
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name "${STACK_NAME}-tg" \
    --protocol HTTP \
    --port 8080 \
    --vpc-id ${VPC_ID} \
    --target-type instance \
    --health-check-path /health \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 10 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --tags Key=Environment,Value=${ENVIRONMENT} Key=DeploymentId,Value=${DEPLOYMENT_ID} \
    --region ${AWS_REGION} \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

echo -e "${GREEN}✅ Created target group: ${TARGET_GROUP_ARN}${NC}"

# Register instances with target group
for INSTANCE_ID in "${INSTANCE_IDS[@]}"; do
    aws elbv2 register-targets \
        --target-group-arn ${TARGET_GROUP_ARN} \
        --targets Id=${INSTANCE_ID} \
        --region ${AWS_REGION}
done

echo -e "${GREEN}✅ Registered instances with target group${NC}"

# Create load balancer
LB_ARN=$(aws elbv2 create-load-balancer \
    --name "${STACK_NAME}-lb" \
    --subnets ${PUBLIC_SUBNET_1_ID} ${PUBLIC_SUBNET_2_ID} \
    --security-groups ${LB_SG_ID} \
    --scheme internet-facing \
    --tags Key=Environment,Value=${ENVIRONMENT} Key=DeploymentId,Value=${DEPLOYMENT_ID} \
    --region ${AWS_REGION} \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

LB_DNS_NAME=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns ${LB_ARN} \
    --query 'LoadBalancers[0].DNSName' \
    --output text \
    --region ${AWS_REGION})

echo -e "${YELLOW}⏳ Waiting for load balancer to be active...${NC}"
aws elbv2 wait load-balancer-available \
    --load-balancer-arns ${LB_ARN} \
    --region ${AWS_REGION}

echo -e "${GREEN}✅ Load Balancer created: ${LB_DNS_NAME}${NC}"

# Create listener for HTTP
aws elbv2 create-listener \
    --load-balancer-arn ${LB_ARN} \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=${TARGET_GROUP_ARN} \
    --region ${AWS_REGION}

echo -e "${GREEN}✅ Created HTTP listener${NC}"

# Step 9: Configure CloudWatch Alarms and Auto Scaling
echo -e "${BLUE}📊 Setting up CloudWatch monitoring and auto scaling...${NC}"

# Create CloudWatch log group
aws logs create-log-group \
    --log-group-name ${LOG_GROUP_NAME} \
    --region ${AWS_REGION}

# Create CloudWatch alarms for CPU utilization
ALARM_NAME="${STACK_NAME}-high-cpu"
aws cloudwatch put-metric-alarm \
    --alarm-name ${ALARM_NAME} \
    --alarm-description "Alarm when CPU exceeds 70%" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period 300 \
    --threshold 70 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=AutoScalingGroupName,Value=${STACK_NAME}-asg \
    --evaluation-periods 2 \
    --alarm-actions "arn:aws:autoscaling:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):scalingPolicy:1234567890:autoScalingGroupName/${STACK_NAME}-asg:policyName/${STACK_NAME}-scale-out" \
    --region ${AWS_REGION}

echo -e "${GREEN}✅ Created CloudWatch CPU alarm${NC}"

# Step 10: Configure automated backups and disaster recovery
echo -e "${BLUE}💾 Setting up automated backups and disaster recovery...${NC}"

# Create backup script
cat > ${DEPLOYMENT_DIR}/backup.ps1 <<EOF
# PowerShell script for automated backups
\$backupDate = Get-Date -Format "yyyyMMdd-HHmmss"
\$backupPath = "C:\\TradingSystem\\backups\\trading-backup-\$backupDate.bak"
\$databaseName = "${DATABASE_NAME}"

# Backup trading database
try {
    # Use SQL Server backup command
    & sqlcmd -S ${DB_ENDPOINT} -U ${DATABASE_USERNAME} -P ${DATABASE_PASSWORD} -Q "BACKUP DATABASE [\$databaseName] TO DISK = N'\$backupPath' WITH NOFORMAT, NOINIT, NAME = '\$databaseName-Full Database Backup', SKIP, NOREWIND, NOUNLOAD, STATS = 10"

    # Upload backup to S3
    Write-S3Object -BucketName "${S3_BUCKET_NAME}" -Key "backups/daily/trading-backup-\$backupDate.bak" -File \$backupPath

    # Clean up local backup
    Remove-Item -Path \$backupPath -Force

    # If this is Sunday, create a weekly backup copy
    if ((Get-Date).DayOfWeek -eq "Sunday") {
        Copy-S3Object -BucketName "${S3_BUCKET_NAME}" -Key "backups/daily/trading-backup-\$backupDate.bak" -DestinationKey "backups/weekly/trading-backup-\$backupDate.bak"
    }

    # If this is the first day of the month, create a monthly backup copy
    if ((Get-Date).Day -eq 1) {
        Copy-S3Object -BucketName "${S3_BUCKET_NAME}" -Key "backups/daily/trading-backup-\$backupDate.bak" -DestinationKey "backups/monthly/trading-backup-\$backupDate.bak"
    }

    # Send success notification
    Send-MailMessage -From "trading-system@${ENVIRONMENT}.com" -To "${ADMIN_EMAIL}" -Subject "Backup Successful" -Body "Daily backup completed successfully." -SmtpServer "smtp-relay.gmail.com"
}
catch {
    # Send failure notification
    Send-MailMessage -From "trading-system@${ENVIRONMENT}.com" -To "${ADMIN_EMAIL}" -Subject "Backup Failed" -Body "Daily backup failed: \$_.Exception.Message" -SmtpServer "smtp-relay.gmail.com"
}
EOF

# Upload backup script to S3
aws s3 cp ${DEPLOYMENT_DIR}/backup.ps1 s3://${S3_BUCKET_NAME}/scripts/backup.ps1 --region ${AWS_REGION}

# Create AWS Backup plan for additional protection
cat > ${DEPLOYMENT_DIR}/backup-plan.json <<EOF
{
    "BackupPlanName": "${STACK_NAME}-backup-plan",
    "Rules": [
        {
            "RuleName": "DailyBackups",
            "TargetBackupVault": "Default",
            "ScheduleExpression": "cron(0 5 ? * * *)",
            "StartWindowMinutes": 60,
            "CompletionWindowMinutes": 180,
            "Lifecycle": {
                "MoveToColdStorageAfterDays": 7,
                "DeleteAfterDays": 35
            },
            "RecoveryPointTags": {
                "Environment": "${ENVIRONMENT}",
                "Type": "Daily"
            }
        },
        {
            "RuleName": "WeeklyBackups",
            "TargetBackupVault": "Default",
            "ScheduleExpression": "cron(0 5 ? * SUN *)",
            "StartWindowMinutes": 60,
            "CompletionWindowMinutes": 180,
            "Lifecycle": {
                "MoveToColdStorageAfterDays": 7,
                "DeleteAfterDays": 90
            },
            "RecoveryPointTags": {
                "Environment": "${ENVIRONMENT}",
                "Type": "Weekly"
            }
        }
    ],
    "BackupPlanTags": {
        "Environment": "${ENVIRONMENT}",
        "DeploymentId": "${DEPLOYMENT_ID}"
    }
}
EOF

BACKUP_PLAN_ID=$(aws backup create-backup-plan \
    --backup-plan file://${DEPLOYMENT_DIR}/backup-plan.json \
    --region ${AWS_REGION} \
    --query 'BackupPlanId' \
    --output text)

echo -e "${GREEN}✅ Created AWS Backup plan: ${BACKUP_PLAN_ID}${NC}"

# Create backup selections for EC2 instances and RDS database
aws backup create-backup-selection \
    --backup-plan-id ${BACKUP_PLAN_ID} \
    --backup-selection '{"SelectionName": "EC2Instances", "IamRoleArn": "arn:aws:iam::'$(aws sts get-caller-identity --query Account --output text)'/role/service-role/AWSBackupDefaultServiceRole", "Resources": ["arn:aws:ec2:'${AWS_REGION}':'$(aws sts get-caller-identity --query Account --output text)':instance/'${INSTANCE_IDS[0]}'", "arn:aws:ec2:'${AWS_REGION}':'$(aws sts get-caller-identity --query Account --output text)':instance/'${INSTANCE_IDS[1]}'"]}' \
    --region ${AWS_REGION}

aws backup create-backup-selection \
    --backup-plan-id ${BACKUP_PLAN_ID} \
    --backup-selection '{"SelectionName": "RDSInstance", "IamRoleArn": "arn:aws:iam::'$(aws sts get-caller-identity --query Account --output text)'/role/service-role/AWSBackupDefaultServiceRole", "Resources": ["arn:aws:rds:'${AWS_REGION}':'$(aws sts get-caller-identity --query Account --output text)':db:'${DB_INSTANCE_IDENTIFIER}'"]}' \
    --region ${AWS_REGION}

echo -e "${GREEN}✅ Configured backup selections for EC2 and RDS${NC}"

# Step 11: Generate final deployment report
echo -e "${BLUE}📝 Generating deployment report...${NC}"

cat > ${DEPLOYMENT_DIR}/deployment-report.txt <<EOF
TRADING SYSTEM DEPLOYMENT REPORT
=================================

Environment: ${ENVIRONMENT}
Region: ${AWS_REGION}
Deployment ID: ${DEPLOYMENT_ID}
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)

INFRASTRUCTURE SUMMARY
----------------------
VPC ID: ${VPC_ID}
Public Subnets: ${PUBLIC_SUBNET_1_ID}, ${PUBLIC_SUBNET_2_ID}
Private Subnets: ${PRIVATE_SUBNET_1_ID}, ${PRIVATE_SUBNET_2_ID}

Security Groups:
- Application SG: ${APP_SG_ID}
- Database SG: ${DB_SG_ID}
- Load Balancer SG: ${LB_SG_ID}
- Bastion Host SG: ${BASTION_SG_ID}

EC2 INSTANCES
-------------
Instance Type: ${INSTANCE_TYPE}
Instance Count: ${INSTANCE_COUNT}
Instance IDs: ${INSTANCE_IDS[@]}
IAM Role: ${ROLE_NAME}
S3 Bucket: ${S3_BUCKET_NAME}

DATABASE
--------
Database Type: SQL Server
Instance Identifier: ${DB_INSTANCE_IDENTIFIER}
Endpoint: ${DB_ENDPOINT}
Database Name: ${DATABASE_NAME}

LOAD BALANCER
-------------
Load Balancer DNS: ${LB_DNS_NAME}
Target Group ARN: ${TARGET_GROUP_ARN}

SECURITY
--------
Secrets Manager:
- API Keys Secret: ${SECRET_ARN}
- Database Credentials Secret: ${DB_SECRET_ARN}

BACKUPS & DISASTER RECOVERY
---------------------------
AWS Backup Plan ID: ${BACKUP_PLAN_ID}
Backup Schedule:
- Daily backups at 5:00 UTC
- Weekly backups on Sundays at 5:00 UTC
Backup Retention:
- Daily backups: 35 days
- Weekly backups: 90 days

ACCESS INFORMATION
------------------
Load Balancer URL: http://${LB_DNS_NAME}
Admin Email: ${ADMIN_EMAIL}

NEXT STEPS
----------
1. Configure DNS to point to the load balancer
2. Set up SSL certificate for HTTPS
3. Configure additional monitoring alerts
4. Test failover and disaster recovery procedures
5. Perform security audit and penetration testing

Deployment artifacts saved to: ${DEPLOYMENT_DIR}
EOF

echo -e "${GREEN}✅ Deployment report generated: ${DEPLOYMENT_DIR}/deployment-report.txt${NC}"

# Step 12: Final validation and testing
echo -e "${BLUE}🔍 Performing final validation and testing...${NC}"

# Test database connectivity
echo -e "${BLUE}Testing database connectivity...${NC}"
TEST_RESULT=$(aws rds describe-db-instances \
    --db-instance-identifier ${DB_INSTANCE_IDENTIFIER} \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text \
    --region ${AWS_REGION})

if [ "${TEST_RESULT}" = "available" ]; then
    echo -e "${GREEN}✅ Database is available and ready${NC}"
else
    echo -e "${RED}❌ Database is not available: ${TEST_RESULT}${NC}"
    exit 1
fi

# Test load balancer DNS resolution
echo -e "${BLUE}Testing load balancer DNS resolution...${NC}"
LB_IP=$(dig +short ${LB_DNS_NAME})
if [ -n "${LB_IP}" ]; then
    echo -e "${GREEN}✅ Load balancer DNS resolved: ${LB_IP}${NC}"
else
    echo -e "${RED}❌ Load balancer DNS resolution failed${NC}"
    exit 1
fi

echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}Load Balancer URL: http://${LB_DNS_NAME}${NC}"
echo -e "${GREEN}Admin Email: ${ADMIN_EMAIL}${NC}"
echo -e "${GREEN}Deployment artifacts: ${DEPLOYMENT_DIR}${NC}"
echo -e "${GREEN}=============================================${NC}"

exit 0
```