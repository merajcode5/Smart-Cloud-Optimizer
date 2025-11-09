#!/bin/bash

# ------------------------------
# Intelligent Cloud Cost Optimization System
# Phase 2 - Networking Setup Script
# ------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# Create a JSON file to store AWS resource IDs
RESOURCES_FILE="../resources.json"
echo "{}" > $RESOURCES_FILE

echo "🚀 Starting Networking Setup ..."

# 1️⃣ Create VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=IntelligentCloudVPC
echo "✅ VPC Created: $VPC_ID"

# Save VPC ID
jq --arg vpc "$VPC_ID" '. + {VPC_ID: $vpc}' $RESOURCES_FILE > tmp.json && mv tmp.json $RESOURCES_FILE

# 2️⃣ Create Subnet
SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone ap-south-1a --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=IntelligentCloudSubnet
echo "✅ Subnet Created: $SUBNET_ID"

jq --arg subnet "$SUBNET_ID" '. + {SUBNET_ID: $subnet}' $RESOURCES_FILE > tmp.json && mv tmp.json $RESOURCES_FILE

# 3️⃣ Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=IntelligentCloudIGW
echo "✅ Internet Gateway Created and Attached: $IGW_ID"

jq --arg igw "$IGW_ID" '. + {IGW_ID: $igw}' $RESOURCES_FILE > tmp.json && mv tmp.json $RESOURCES_FILE

# 4️⃣ Create Route Table and Route
RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $RTB_ID
aws ec2 create-tags --resources $RTB_ID --tags Key=Name,Value=IntelligentCloudRouteTable
echo "✅ Route Table Created and Associated: $RTB_ID"

jq --arg rtb "$RTB_ID" '. + {ROUTE_TABLE_ID: $rtb}' $RESOURCES_FILE > tmp.json && mv tmp.json $RESOURCES_FILE

# 5️⃣ Create Security Group
SG_ID=$(aws ec2 create-security-group --group-name IntelligentCloudSG --description "Allow SSH and HTTP" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 create-tags --resources $SG_ID --tags Key=Name,Value=IntelligentCloudSG
echo "✅ Security Group Created: $SG_ID"

jq --arg sg "$SG_ID" '. + {SECURITY_GROUP_ID: $sg}' $RESOURCES_FILE > tmp.json && mv tmp.json $RESOURCES_FILE

echo "🎉 Networking setup complete!"
echo "Resources stored in: $RESOURCES_FILE"
