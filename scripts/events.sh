#!/bin/bash
# ---------------------------------------
# Intelligent Cloud Cost Optimization System
# Phase 4 - Step 5: EventBridge Scheduling
# ---------------------------------------

set -e

START_LAMBDA="StartEC2Lambda"
STOP_LAMBDA="StopEC2Lambda"
REGION="ap-south-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

echo "🚀 Creating EventBridge rules for auto start/stop in $REGION..."

# Start EC2 daily at 9 AM IST (03:30 UTC)
aws events put-rule \
  --name StartEC2Rule \
  --schedule-expression "cron(30 3 * * ? *)" \
  --state ENABLED

# Stop EC2 daily at 6 PM IST (12:30 UTC)
aws events put-rule \
  --name StopEC2Rule \
  --schedule-expression "cron(30 12 * * ? *)" \
  --state ENABLED

# Allow EventBridge to trigger Lambdas
aws lambda add-permission \
  --function-name $START_LAMBDA \
  --statement-id start-ec2-perm \
  --action "lambda:InvokeFunction" \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:$REGION:$ACCOUNT_ID:rule/StartEC2Rule

aws lambda add-permission \
  --function-name $STOP_LAMBDA \
  --statement-id stop-ec2-perm \
  --action "lambda:InvokeFunction" \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:$REGION:$ACCOUNT_ID:rule/StopEC2Rule

# Link rules with target Lambdas
aws events put-targets \
  --rule StartEC2Rule \
  --targets "Id"="1","Arn"=$(aws lambda get-function --function-name $START_LAMBDA --query "Configuration.FunctionArn" --output text)

aws events put-targets \
  --rule StopEC2Rule \
  --targets "Id"="1","Arn"=$(aws lambda get-function --function-name $STOP_LAMBDA --query "Configuration.FunctionArn" --output text)

echo "✅ EventBridge rules created successfully!"
echo "🌅 EC2 will start automatically at 9 AM IST and stop at 6 PM IST daily."
