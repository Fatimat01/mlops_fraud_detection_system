"""
Simple cost monitoring for SageMaker endpoint
"""

import boto3
from datetime import datetime, timedelta
import click


def calculate_endpoint_cost(endpoint_name, hours=24, region='us-east-1'):
    """Calculate estimated endpoint costs"""
    
    # Instance pricing (us-east-1)
    instance_costs = {
        'ml.t2.medium': 0.065,
        'ml.t2.large': 0.13,
        'ml.m5.large': 0.134,
        'ml.m5.xlarge': 0.269,
        'ml.m5.2xlarge': 0.538
    }
    
    # Get endpoint configuration
    sm = boto3.client('sagemaker', region_name=region)
    cw = boto3.client('cloudwatch', region_name=region)
    
    try:
        # Get endpoint details
        endpoint = sm.describe_endpoint(EndpointName=endpoint_name)
        config_name = endpoint['EndpointConfigName']
        config = sm.describe_endpoint_config(EndpointConfigName=config_name)
        
        # Get instance details
        variant = config['ProductionVariants'][0]
        instance_type = variant['InstanceType']
        instance_count = variant['InitialInstanceCount']
        
        # Calculate base cost
        hourly_cost = instance_costs.get(instance_type, 0.134) * instance_count
        daily_cost = hourly_cost * 24
        monthly_cost = daily_cost * 30
        
        # Get invocation metrics
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=hours)
        
        response = cw.get_metric_statistics(
            Namespace='AWS/SageMaker',
            MetricName='Invocations',
            Dimensions=[
                {'Name': 'EndpointName', 'Value': endpoint_name},
                {'Name': 'VariantName', 'Value': 'AllTraffic'}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600 * hours,  # Total for period
            Statistics=['Sum']
        )
        
        total_invocations = 0
        if response['Datapoints']:
            total_invocations = int(response['Datapoints'][0]['Sum'])
        
        # Calculate request costs ($0.0004 per 1000 requests)
        request_cost = (total_invocations / 1000) * 0.0004
        
        # Print cost summary
        print(f"\nCost Analysis for: {endpoint_name}")
        print("=" * 50)
        print(f"Instance Type: {instance_type}")
        print(f"Instance Count: {instance_count}")
        print(f"Period: Last {hours} hours")
        print(f"\nInstance Costs:")
        print(f"  Hourly: ${hourly_cost:.2f}")
        print(f"  Daily: ${daily_cost:.2f}")
        print(f"  Monthly (30d): ${monthly_cost:.2f}")
        print(f"\nUsage:")
        print(f"  Total Invocations: {total_invocations:,}")
        print(f"  Request Cost: ${request_cost:.4f}")
        print(f"\nTotal Estimated Cost:")
        print(f"  Last {hours}h: ${(hourly_cost * hours + request_cost):.2f}")
        print(f"  Monthly: ${(monthly_cost + request_cost * 30):.2f}")
        
        # Cost optimization suggestions
        print(f"\nCost Optimization Tips:")
        if instance_type.startswith('ml.m5') and total_invocations < 1000:
            print("  - Low usage detected. Consider ml.t2.medium for development")
        if instance_count > 1 and total_invocations < 5000:
            print("  - Consider reducing minimum instances to 1")
        if total_invocations > 50000:
            print("  - High usage. Ensure auto-scaling is properly configured")
            
    except Exception as e:
        print(f"Error: {str(e)}")


@click.command()
@click.option('--endpoint', required=True, help='Endpoint name')
@click.option('--hours', default=24, help='Hours to analyze')
@click.option('--region', default='us-east-1', help='AWS region')
def main(endpoint, hours, region):
    """Check SageMaker endpoint costs"""
    calculate_endpoint_cost(endpoint, hours, region)


if __name__ == '__main__':
    main()