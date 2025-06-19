import json
import boto3
import os
import uuid
from datetime import datetime
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sagemaker_runtime = boto3.client('sagemaker-runtime')
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    try:
        # Parse request
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
        prediction_id = str(uuid.uuid4())
        start_time = datetime.now()
        
        logger.info(f"Processing prediction {prediction_id}")
        
        # Invoke SageMaker endpoint
        response = sagemaker_runtime.invoke_endpoint(
            EndpointName=os.environ['ENDPOINT_NAME'],
            ContentType='application/json',
            Body=json.dumps(body)
        )
        
        # Parse response
        result = json.loads(response['Body'].read().decode())
        
        # Log to DynamoDB
        table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])
        processing_time = (datetime.now() - start_time).total_seconds() * 1000
        
        table.put_item(
            Item={
                'prediction_id': prediction_id,
                'timestamp': datetime.now().isoformat(),
                'request_id': context.aws_request_id,
                'type': 'lambda_prediction',
                'input_data': body,
                'prediction': result,
                'processing_time_ms': processing_time,
                'ttl': int(datetime.now().timestamp()) + 7776000
            }
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'X-Prediction-ID': prediction_id,
                'X-Processing-Time': str(processing_time)
            },
            'body': json.dumps({
                'prediction_id': prediction_id,
                'result': result,
                'processing_time_ms': processing_time
            })
        }
        
    except Exception as e:
        logger.error(f"Prediction failed: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': str(e),
                'prediction_id': prediction_id if 'prediction_id' in locals() else None
            })
        }