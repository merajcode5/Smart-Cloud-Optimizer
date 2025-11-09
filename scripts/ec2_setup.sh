#!/bin/bash

# -------------------------------------
# Intelligent Cloud Cost Optimization System
# Phase 3 - EC2 Setup Script
# -------------------------------------

set -e

RESOURCES_FILE="../resources.json"

# 1️⃣ Load VPC, Subnet, and SG IDs from resources.json
VPC_ID=$(jq -r '.VPC_ID' $RESOURCES_FILE)
SUBNET_ID=$(jq -r '.SUBNET_ID' $RESOURCES_FILE)
SG_ID=$(jq -r '.SECURITY_GROUP_ID' $RESOURCES_FILE)

if [[ -z "$VPC_ID" || -z "$SUBNET_ID" || -z "$SG_ID" ]]; then
  echo "❌ Required network resources not found in resources.json!"
  exit 1
fi

echo "🚀 Starting EC2 Setup ..."
echo "Using: VPC=$VPC_ID | Subnet=$SUBNET_ID | SG=$SG_ID"

# 2️⃣ Create or reuse Key Pair
KEY_NAME="IntelligentCloudKey"
KEY_FILE="$KEY_NAME.pem"

if aws ec2 describe-key-pairs --key-names $KEY_NAME >/dev/null 2>&1; then
  echo "ℹ️ Key Pair '$KEY_NAME' already exists. Reusing it."
else
  aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > $KEY_FILE
  chmod 400 $KEY_FILE
  echo "✅ Key Pair Created: $KEY_NAME"
fi

jq --arg key "$KEY_NAME" '. + {KEY_NAME: $key}' $RESOURCES_FILE > tmp.json && mv tmp.json $RESOURCES_FILE

# 3️⃣ Get Latest Amazon Linux 2 AMI ID (from SSM Parameter Store for ap-south-1)
echo "🔍 Fetching latest Amazon Linux 2 AMI ID from SSM Parameter Store..."
AMI_ID=$(aws ssm get-parameters \
  --names /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 \
  --region ap-south-1 \
  --query 'Parameters[0].Value' \
  --output text 2>/dev/null)

if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
  echo "❌ Failed to fetch AMI from SSM. Using fallback static AMI."
  AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
    --query 'Images | sort_by(@, &CreationDate)[-1].ImageId' \
    --output text)
fi

echo "✅ AMI Selected: $AMI_ID"

# 4️⃣ Launch EC2 Instance
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --user-data file://../templates/user_data.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=IntelligentCloudEC2}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "✅ EC2 Instance Launched: $INSTANCE_ID"

jq --arg inst "$INSTANCE_ID" '. + {INSTANCE_ID: $inst}' $RESOURCES_FILE > tmp.json && mv tmp.json $RESOURCES_FILE

# 5️⃣ Wait for EC2 to be running
echo "⏳ Waiting for EC2 to enter running state..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# 6️⃣ Get Public IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "✅ EC2 Public IP: $PUBLIC_IP"

jq --arg ip "$PUBLIC_IP" '. + {EC2_PUBLIC_IP: $ip}' $RESOURCES_FILE > tmp.json && mv tmp.json $RESOURCES_FILE

echo "🎉 EC2 setup complete! Your Nginx server will be live at: http://$PUBLIC_IP"
