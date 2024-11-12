import json
import boto3
import os
from datetime import datetime

s3 = boto3.client('s3')
sqs = boto3.client('sqs')

def lambda_handler(event, context):
    queue_url = os.environ['SQS_QUEUE_URL']  # Get SQS queue URL from environment variable
    bucket_name = os.environ['S3_BUCKET_NAME'] # Get S3 bucket name from environment variable

    try:
        response = sqs.receive_message(
            QueueUrl=queue_url,
            MaxNumberOfMessages=10,  # Process up to 10 messages at a time
            WaitTimeSeconds=20  # Long polling for 20 seconds
        )

        if 'Messages' in response:
            for message in response['Messages']:
                try:
                   
                    body = json.loads(message['Body']) # Assuming JSON message body

                    # Extract date from the message (adapt as needed for your data structure)
                    message_date_str = body.get('date')  # Replace 'date' with the actual key

                    if not message_date_str:
                        raise ValueError("Message does not contain a 'date' field.")


                    message_date = datetime.fromisoformat(message_date_str.replace('Z', '+00:00')) # Handle ISO format with Z

                    year = message_date.strftime('%Y')
                    month = message_date.strftime('%m')
                    day = message_date.strftime('%d')
                    
                    # Create the S3 key (path)
                    s3_key = f"{year}/{month}/{day}/{message['MessageId']}.json" # Include MessageId for uniqueness


                    s3.put_object(
                        Bucket=bucket_name,
                        Key=s3_key,
                        Body=json.dumps(body) # Put the entire message body into S3
                    )



                    sqs.delete_message(
                        QueueUrl=queue_url,
                        ReceiptHandle=message['ReceiptHandle']
                    )

                except (ValueError, KeyError) as e:
                    print(f"Error processing message: {e}. Skipping message.")
                    # Consider moving the message to a dead-letter queue for further investigation.


    except Exception as e:
        print(f"Error: {e}")
        raise  # Re-raise the exception to trigger a Lambda retry