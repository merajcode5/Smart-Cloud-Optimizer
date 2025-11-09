import boto3
import os

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    instance_id = os.environ['INSTANCE_ID']
    try:
        ec2.stop_instances(InstanceIds=[instance_id])
        print(f"🛑 Stopped instance: {instance_id}")
        return {"status": "stopped", "instance_id": instance_id}
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return {"error": str(e)}
