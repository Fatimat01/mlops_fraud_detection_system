"""
Custom metrics collection for fraud detection MLOps pipeline
Collects business, performance, and operational metrics
"""

import boto3
import time
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
import numpy as np
from collections import defaultdict, deque

logger = logging.getLogger(__name__)


@dataclass
class MetricData:
    """Structured metric data"""
    name: str
    value: float
    unit: str
    timestamp: datetime
    dimensions: Dict[str, str]


class MetricsCollector:
    """Centralized metrics collection and monitoring"""
    
    def __init__(self, region: str = 'us-east-1'):
        self.region = region
        self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        self.dynamodb = boto3.resource('dynamodb', region_name=region)
        
        # In-memory metric storage for aggregation
        self.metric_buffer = defaultdict(list)
        self.business_metrics = defaultdict(lambda: deque(maxlen=1000))
        
        # Drift detection baseline
        self.baseline_metrics = {}
        self.drift_window_size = 100
        
    def collect_prediction_metrics(self, prediction_data: Dict[str, Any], 
                                 processing_time: float, claim_data: Dict[str, Any]):
        """Collect metrics from a single prediction"""
        
        timestamp = datetime.now()
        
        # Performance metrics
        self._record_metric(
            name='prediction_processing_time',
            value=processing_time,
            unit='Milliseconds',
            dimensions={
                'RiskLevel': prediction_data.get('risk_level', 'UNKNOWN'),
                'ModelVersion': prediction_data.get('model_version', '1.0')
            },
            timestamp=timestamp
        )
        
        # Business metrics
        self._record_metric(
            name='fraud_probability',
            value=prediction_data.get('fraud_probability', 0),
            unit='None',
            dimensions={
                'RiskLevel': prediction_data.get('risk_level', 'UNKNOWN')
            },
            timestamp=timestamp
        )
        
        self._record_metric(
            name='model_confidence',
            value=prediction_data.get('confidence', 0),
            unit='None',
            dimensions={
                'ModelVersion': prediction_data.get('model_version', '1.0')
            },
            timestamp=timestamp
        )
        
        # Store for drift detection
        self.business_metrics['fraud_probabilities'].append(
            prediction_data.get('fraud_probability', 0)
        )
        self.business_metrics['confidences'].append(
            prediction_data.get('confidence', 0)
        )
        
        # Feature-level metrics for drift detection
        self._collect_feature_metrics(claim_data, timestamp)
        
    def collect_api_metrics(self, endpoint: str, method: str, status_code: int, 
                          response_time: float, request_size: int, response_size: int):
        """Collect API performance metrics"""
        
        timestamp = datetime.now()
        
        # Request metrics
        self._record_metric(
            name='api_request_duration',
            value=response_time,
            unit='Seconds',
            dimensions={
                'Endpoint': endpoint,
                'Method': method,
                'StatusCode': str(status_code)
            },
            timestamp=timestamp
        )
        
        self._record_metric(
            name='api_request_size',
            value=request_size,
            unit='Bytes',
            dimensions={
                'Endpoint': endpoint,
                'Method': method
            },
            timestamp=timestamp
        )
        
        self._record_metric(
            name='api_response_size',
            value=response_size,
            unit='Bytes',
            dimensions={
                'Endpoint': endpoint,
                'StatusCode': str(status_code)
            },
            timestamp=timestamp
        )
        
        # Error tracking
        if status_code >= 400:
            self._record_metric(
                name='api_errors_total',
                value=1,
                unit='Count',
                dimensions={
                    'Endpoint': endpoint,
                    'StatusCode': str(status_code),
                    'ErrorType': 'client' if status_code < 500 else 'server'
                },
                timestamp=timestamp
            )
    
    def collect_business_metrics(self, time_period_hours: int = 1):
        """Collect aggregated business metrics"""
        
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=time_period_hours)
        
        # Get recent predictions from DynamoDB
        predictions = self._get_recent_predictions(start_time, end_time)
        
        if not predictions:
            logger.warning("No recent predictions found for business metrics")
            return
        
        # Calculate business KPIs
        total_claims = len(predictions)
        fraud_claims = sum(1 for p in predictions if p.get('is_fraud', 0) == 1)
        high_risk_claims = sum(1 for p in predictions if p.get('risk_level') in ['HIGH', 'CRITICAL'])
        
        fraud_rate = fraud_claims / total_claims if total_claims > 0 else 0
        high_risk_rate = high_risk_claims / total_claims if total_claims > 0 else 0
        
        avg_fraud_prob = np.mean([p.get('fraud_probability', 0) for p in predictions])
        avg_confidence = np.mean([p.get('confidence', 0) for p in predictions])
        
        timestamp = datetime.now()
        
        # Record business metrics
        business_metrics = [
            ('claims_processed_total', total_claims, 'Count'),
            ('fraud_detection_rate', fraud_rate * 100, 'Percent'),
            ('high_risk_claims_rate', high_risk_rate * 100, 'Percent'),
            ('average_fraud_probability', avg_fraud_prob, 'None'),
            ('average_model_confidence', avg_confidence, 'None')
        ]
        
        for metric_name, value, unit in business_metrics:
            self._record_metric(
                name=metric_name,
                value=value,
                unit=unit,
                dimensions={'TimePeriod': f'{time_period_hours}h'},
                timestamp=timestamp
            )
        
        # Check for anomalies
        self._check_business_anomalies(fraud_rate, avg_fraud_prob, avg_confidence)
    
    def collect_model_drift_metrics(self):
        """Detect and report model drift"""
        
        if len(self.business_metrics['fraud_probabilities']) < self.drift_window_size:
            logger.info("Insufficient data for drift detection")
            return
        
        current_probs = list(self.business_metrics['fraud_probabilities'])[-self.drift_window_size:]
        current_confidences = list(self.business_metrics['confidences'])[-self.drift_window_size:]
        
        # Calculate drift scores
        prob_drift = self._calculate_distribution_drift(
            current_probs, 
            self.baseline_metrics.get('fraud_probabilities', current_probs[:50])
        )
        
        confidence_drift = self._calculate_distribution_drift(
            current_confidences,
            self.baseline_metrics.get('confidences', current_confidences[:50])
        )
        
        timestamp = datetime.now()
        
        # Record drift metrics
        self._record_metric(
            name='prediction_drift_score',
            value=prob_drift,
            unit='None',
            dimensions={'DriftType': 'FraudProbability'},
            timestamp=timestamp
        )
        
        self._record_metric(
            name='confidence_drift_score',
            value=confidence_drift,
            unit='None',
            dimensions={'DriftType': 'ModelConfidence'},
            timestamp=timestamp
        )
        
        # Alert on significant drift
        if prob_drift > 0.15:
            self._send_drift_alert('Fraud Probability', prob_drift)
        
        if confidence_drift > 0.15:
            self._send_drift_alert('Model Confidence', confidence_drift)
    
    def collect_cost_metrics(self):
        """Collect cost and efficiency metrics"""
        
        # Get SageMaker endpoint details
        sagemaker = boto3.client('sagemaker', region_name=self.region)
        
        try:
            endpoint_info = sagemaker.describe_endpoint(
                EndpointName=os.environ.get('ENDPOINT_NAME', 'fraud-detection-endpoint')
            )
            
            instance_type = endpoint_info['ProductionVariants'][0]['InstanceType']
            instance_count = endpoint_info['ProductionVariants'][0]['CurrentInstanceCount']
            
            # Estimate hourly cost (simplified - real implementation would use Cost Explorer API)
            instance_costs = {
                'ml.t2.medium': 0.065,
                'ml.m5.large': 0.134,
                'ml.m5.xlarge': 0.269,
                'ml.m5.2xlarge': 0.538
            }
            
            hourly_cost = instance_costs.get(instance_type, 0.134) * instance_count
            
            # Get hourly prediction count
            hourly_predictions = self._get_hourly_prediction_count()
            
            cost_per_prediction = hourly_cost / hourly_predictions if hourly_predictions > 0 else 0
            predictions_per_dollar = hourly_predictions / hourly_cost if hourly_cost > 0 else 0
            
            timestamp = datetime.now()
            
            # Record cost metrics
            cost_metrics = [
                ('sagemaker_hourly_cost', hourly_cost, 'None'),
                ('cost_per_prediction', cost_per_prediction, 'None'),
                ('predictions_per_dollar', predictions_per_dollar, 'Count'),
                ('active_instances', instance_count, 'Count')
            ]
            
            for metric_name, value, unit in cost_metrics:
                self._record_metric(
                    name=metric_name,
                    value=value,
                    unit=unit,
                    dimensions={'InstanceType': instance_type},
                    timestamp=timestamp
                )
                
        except Exception as e:
            logger.error(f"Failed to collect cost metrics: {e}")
    
    def collect_security_metrics(self, event_type: str, source_ip: str, 
                               user_agent: str, status: str):
        """Collect security-related metrics"""
        
        timestamp = datetime.now()
        
        # Basic security metrics
        self._record_metric(
            name='security_events_total',
            value=1,
            unit='Count',
            dimensions={
                'EventType': event_type,
                'Status': status,
                'SourceRegion': self._get_ip_region(source_ip)
            },
            timestamp=timestamp
        )
        
        # Track failed authentication attempts
        if event_type == 'authentication' and status == 'failed':
            self._record_metric(
                name='failed_authentication_attempts',
                value=1,
                unit='Count',
                dimensions={'SourceIP': source_ip[:8] + 'xxx'},  # Partial IP for privacy
                timestamp=timestamp
            )
    
    def flush_metrics(self):
        """Send buffered metrics to CloudWatch"""
        
        if not self.metric_buffer:
            return
        
        try:
            # Group metrics by namespace
            namespaced_metrics = defaultdict(list)
            
            for metrics_list in self.metric_buffer.values():
                for metric in metrics_list:
                    namespace = self._get_metric_namespace(metric.name)
                    
                    metric_data = {
                        'MetricName': metric.name,
                        'Value': metric.value,
                        'Unit': metric.unit,
                        'Timestamp': metric.timestamp
                    }
                    
                    if metric.dimensions:
                        metric_data['Dimensions'] = [
                            {'Name': k, 'Value': v} 
                            for k, v in metric.dimensions.items()
                        ]
                    
                    namespaced_metrics[namespace].append(metric_data)
            
            # Send to CloudWatch in batches
            for namespace, metrics in namespaced_metrics.items():
                for i in range(0, len(metrics), 20):  # CloudWatch limit: 20 metrics per call
                    batch = metrics[i:i+20]
                    
                    self.cloudwatch.put_metric_data(
                        Namespace=namespace,
                        MetricData=batch
                    )
            
            # Clear buffer
            self.metric_buffer.clear()
            logger.info(f"Flushed {sum(len(m) for m in namespaced_metrics.values())} metrics to CloudWatch")
            
        except Exception as e:
            logger.error(f"Failed to flush metrics to CloudWatch: {e}")
    
    def _record_metric(self, name: str, value: float, unit: str, 
                      dimensions: Dict[str, str], timestamp: datetime):
        """Record a metric in the buffer"""
        
        metric = MetricData(
            name=name,
            value=value,
            unit=unit,
            timestamp=timestamp,
            dimensions=dimensions
        )
        
        self.metric_buffer[name].append(metric)
    
    def _collect_feature_metrics(self, claim_data: Dict[str, Any], timestamp: datetime):
        """Collect feature-level metrics for drift detection"""
        
        # Key features to monitor for drift
        key_features = [
            'months_as_customer', 'age', 'total_claim_amount', 
            'claim_ratio', 'incident_severity'
        ]
        
        for feature in key_features:
            if feature in claim_data:
                self._record_metric(
                    name=f'feature_{feature}',
                    value=float(claim_data[feature]),
                    unit='None',
                    dimensions={'FeatureType': 'input'},
                    timestamp=timestamp
                )
    
    def _get_recent_predictions(self, start_time: datetime, end_time: datetime) -> List[Dict]:
        """Get recent predictions from DynamoDB"""
        
        # This is a simplified implementation
        # Real implementation would query DynamoDB with time range
        return []
    
    def _calculate_distribution_drift(self, current_data: List[float], 
                                    baseline_data: List[float]) -> float:
        """Calculate distribution drift using KL divergence"""
        
        try:
            # Create histograms
            bins = np.linspace(0, 1, 11)  # 10 bins from 0 to 1
            current_hist, _ = np.histogram(current_data, bins=bins, density=True)
            baseline_hist, _ = np.histogram(baseline_data, bins=bins, density=True)
            
            # Add small epsilon to avoid log(0)
            epsilon = 1e-10
            current_hist += epsilon
            baseline_hist += epsilon
            
            # Normalize
            current_hist /= current_hist.sum()
            baseline_hist /= baseline_hist.sum()
            
            # Calculate KL divergence
            kl_div = np.sum(current_hist * np.log(current_hist / baseline_hist))
            
            return float(kl_div)
            
        except Exception as e:
            logger.error(f"Error calculating drift: {e}")
            return 0.0
    
    def _check_business_anomalies(self, fraud_rate: float, avg_fraud_prob: float, 
                                avg_confidence: float):
        """Check for business metric anomalies"""
        
        # Define normal ranges
        normal_fraud_rate_range = (0.05, 0.25)  # 5-25%
        normal_confidence_range = (0.6, 1.0)    # 60-100%
        
        timestamp = datetime.now()
        
        # Check fraud rate anomaly
        if not (normal_fraud_rate_range[0] <= fraud_rate <= normal_fraud_rate_range[1]):
            self._record_metric(
                name='business_anomaly_detected',
                value=1,
                unit='Count',
                dimensions={
                    'AnomalyType': 'FraudRate',
                    'Severity': 'HIGH' if fraud_rate > 0.4 else 'MEDIUM'
                },
                timestamp=timestamp
            )
        
        # Check confidence anomaly
        if avg_confidence < normal_confidence_range[0]:
            self._record_metric(
                name='business_anomaly_detected',
                value=1,
                unit='Count',
                dimensions={
                    'AnomalyType': 'LowConfidence',
                    'Severity': 'MEDIUM'
                },
                timestamp=timestamp
            )
    
    def _get_hourly_prediction_count(self) -> int:
        """Get prediction count for the last hour"""
        # Simplified implementation
        return len(self.business_metrics['fraud_probabilities'])
    
    def _get_ip_region(self, ip_address: str) -> str:
        """Get geographic region from IP address"""
        # Simplified implementation - real version would use IP geolocation
        return 'unknown'
    
    def _get_metric_namespace(self, metric_name: str) -> str:
        """Determine CloudWatch namespace for metric"""
        
        if metric_name.startswith('api_'):
            return 'FraudDetection/API'
        elif metric_name.startswith('prediction_') or metric_name.startswith('fraud_'):
            return 'FraudDetection/ML'
        elif metric_name.startswith('business_') or metric_name.startswith('claims_'):
            return 'FraudDetection/Business'
        elif metric_name.startswith('cost_') or 'cost' in metric_name:
            return 'FraudDetection/Cost'
        elif metric_name.startswith('security_'):
            return 'FraudDetection/Security'
        else:
            return 'FraudDetection/Custom'
    
    def _send_drift_alert(self, drift_type: str, drift_score: float):
        """Send alert for model drift"""
        
        try:
            sns = boto3.client('sns', region_name=self.region)
            
            message = f"""
            Model Drift Alert - {drift_type}
            
            Drift Score: {drift_score:.4f}
            Threshold: 0.15
            Time: {datetime.now().isoformat()}
            
            This indicates the model's {drift_type.lower()} distribution has 
            significantly changed from the baseline. Investigation recommended.
            """
            
            # This would need the SNS topic ARN from infrastructure
            topic_arn = os.environ.get('SNS_TOPIC_ARN')
            if topic_arn:
                sns.publish(
                    TopicArn=topic_arn,
                    Subject=f'Model Drift Alert: {drift_type}',
                    Message=message
                )
                
        except Exception as e:
            logger.error(f"Failed to send drift alert: {e}")


# Global metrics collector instance
metrics_collector = MetricsCollector()


def collect_prediction_metrics(prediction_data: Dict[str, Any], 
                             processing_time: float, 
                             claim_data: Dict[str, Any]):
    """Convenience function to collect prediction metrics"""
    metrics_collector.collect_prediction_metrics(prediction_data, processing_time, claim_data)


def collect_api_metrics(endpoint: str, method: str, status_code: int, 
                       response_time: float, request_size: int, response_size: int):
    """Convenience function to collect API metrics"""
    metrics_collector.collect_api_metrics(
        endpoint, method, status_code, response_time, request_size, response_size
    )


def flush_all_metrics():
    """Flush all buffered metrics to CloudWatch"""
    metrics_collector.flush_metrics()