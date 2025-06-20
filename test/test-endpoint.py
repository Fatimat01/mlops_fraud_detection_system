import boto3
import json

runtime = boto3.client('sagemaker-runtime', region_name='us-east-1')

endpoint_name = 'fraud-detection-endpoint'

payload = { 
  "months_as_customer":5,"age":35,"policy_deductable":500,"umbrella_limit":0,
  "insured_sex":1,"insured_education_level":2,"insured_occupation":3,"insured_hobbies":0,
  "insured_relationship":0,"incident_type":1,"collision_type":1,"incident_severity":2,
  "authorities_contacted":0,"number_of_vehicles_involved":1,"property_damage":0,
  "bodily_injuries":0,"witnesses":1,"police_report_available":1,"total_claim_amount":10000,
  "injury_claim":1000,"property_claim":2000,"vehicle_claim":3000,"auto_make":1,"auto_year":2018,
  "incident_hour_bin":3,"claim_ratio":0.33
}

response = runtime.invoke_endpoint(
    EndpointName=endpoint_name,
    ContentType='application/json',
    Body=json.dumps(payload)
)

result = response['Body'].read().decode('utf-8')
print(result)