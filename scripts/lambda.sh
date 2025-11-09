#!/bin/bash
# ---------------------------------------
# Intelligent Cloud Cost Optimization System
# Phase 4 - Lambda Setup Script
# ---------------------------------------

set -e
RESOURCES_FILE="../resources.json"

# Load instance ID
INSTANCE_ID=$(jq -r '.INSTANCE_ID' $RESOURCES_FILE)
if [[ -z "$INSTANCE_ID" ]]; then
  echo "❌ INSTANCE_ID not found in resources.json"
  exit 1
fi

echo "🚀 Creating IAM role for Lambda..."

# 1️⃣ Create IAM Role for Lambda
ROLE_NAME="IntelligentCloudLambdaRole"
TRUST_POLICY="../templates/role_assume_policy.json"

# Create role only if it doesn't already exist
if aws iam get-role --role-name $ROLE_NAME >/dev/null 2>&1; then
  echo "ℹ️ IAM role '$ROLE_NAME' already exists. Reusing it."
else
  aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://$TRUST_POLICY >/dev/null
  echo "✅ Role Created: $ROLE_NAME"
  echo "⏳ Waiting 20 seconds for IAM role propagation..."
  sleep 20
fi

# Attach policy to allow EC2 start/stop
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

echo "✅ Role Created: $ROLE_NAME"
echo "⏳ Waiting 20 seconds for IAM role propagation..."
sleep 20

ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

# 2️⃣ Create Lambda zip packages
echo "📦 Packaging Lambda functions..."
cd ..
zip -j start_ec2.zip start_ec2.py
zip -j stop_ec2.zip stop_ec2.py
cd scripts

# 3️⃣ Create Lambdas
echo "🚀 Creating Lambda functions..."

START_LAMBDA="StartEC2Lambda"
STOP_LAMBDA="StopEC2Lambda"

aws lambda create-function \
  --function-name $START_LAMBDA \
  --runtime python3.9 \
  --role $ROLE_ARN \
  --handler start_ec2.lambda_handler \
  --zip-file fileb://../start_ec2.zip \
  --timeout 10 \
  --environment Variables="{INSTANCE_ID=$INSTANCE_ID}"

aws lambda create-function \
  --function-name $STOP_LAMBDA \
  --runtime python3.9 \
  --role $ROLE_ARN \
  --handler stop_ec2.lambda_handler \
  --zip-file fileb://../stop_ec2.zip \
  --timeout 10 \
  --environment Variables="{INSTANCE_ID=$INSTANCE_ID}"

echo "✅ Lambda Functions Created:"
echo " - $START_LAMBDA"
echo " - $STOP_LAMBDA"

jq --arg start "$START_LAMBDA" --arg stop "$STOP_LAMBDA" '. + {START_LAMBDA: $start, STOP_LAMBDA: $stop}' $RESOURCES_FILE > tmp.json && mv tmp.json $RESOURCES_FILE
