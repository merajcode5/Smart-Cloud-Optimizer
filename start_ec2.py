import boto3
import os

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    instance_id = os.environ['INSTANCE_ID']
    try:
        ec2.start_instances(InstanceIds=[instance_id])
        print(f"✅ Started instance: {instance_id}")
        return {"status": "started", "instance_id": instance_id}
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return {"error": str(e)}
