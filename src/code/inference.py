# code/inference.py - XGBoost specific inference script
"""
SageMaker inference script for XGBoost fraud detection model
"""

import json
import logging
import pickle
import joblib
import numpy as np
import pandas as pd
import os
import xgboost as xgb

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Define feature names in the correct order
FEATURE_NAMES = [
    'months_as_customer', 'age', 'policy_deductable', 'umbrella_limit',
    'insured_sex', 'insured_education_level', 'insured_occupation',
    'insured_hobbies', 'insured_relationship', 'incident_type',
    'collision_type', 'incident_severity', 'authorities_contacted',
    'number_of_vehicles_involved', 'property_damage', 'bodily_injuries',
    'witnesses', 'police_report_available', 'total_claim_amount',
    'injury_claim', 'property_claim', 'vehicle_claim', 'auto_make',
    'auto_year', 'incident_hour_bin', 'claim_ratio'
]

def model_fn(model_dir):
    """Load the XGBoost model"""
    logger.info(f"Loading model from {model_dir}")
    
    model_path = os.path.join(model_dir, 'xgboost-model')
    
    # Try different loading methods for XGBoost
    try:
        # First try joblib (if saved with sklearn API)
        model = joblib.load(model_path)
        logger.info("Model loaded with joblib")
    except:
        try:
            # Try pickle
            with open(model_path, 'rb') as f:
                model = pickle.load(f)
            logger.info("Model loaded with pickle")
        except:
            # Try native XGBoost format
            model = xgb.Booster()
            model.load_model(model_path)
            logger.info("Model loaded as XGBoost Booster")
    
    logger.info(f"Model type: {type(model)}")
    return model

def input_fn(request_body, request_content_type):
    """Parse and prepare input data"""
    if request_content_type == "application/json":
        # Parse JSON
        data = json.loads(request_body)
        
        # Convert to DataFrame
        if isinstance(data, dict):
            df = pd.DataFrame([data])
        else:
            df = pd.DataFrame(data)
        
        # Ensure all features are present
        for feature in FEATURE_NAMES:
            if feature not in df.columns:
                df[feature] = 0
                logger.warning(f"Missing feature {feature}, using default value 0")
        
        # Select and order features
        df = df[FEATURE_NAMES]
        
        logger.info(f"Input shape: {df.shape}")
        return df
    else:
        raise ValueError(f"Unsupported content type: {request_content_type}")

def predict_fn(input_data, model):
    """Make predictions with XGBoost model"""
    logger.info(f"Making predictions for {len(input_data)} samples")
    
    # Handle different XGBoost model types
    if hasattr(model, 'predict_proba'):
        # XGBClassifier from sklearn API
        predictions = model.predict_proba(input_data)[:, 1]
    elif hasattr(model, 'predict'):
        # Could be XGBClassifier or Booster
        if isinstance(model, xgb.Booster):
            # Native XGBoost Booster
            dmatrix = xgb.DMatrix(input_data)
            predictions = model.predict(dmatrix)
        else:
            # XGBClassifier predict method
            predictions = model.predict(input_data)
    else:
        raise ValueError(f"Model type {type(model)} not supported")
    
    logger.info(f"Predictions shape: {predictions.shape}")
    return predictions

def output_fn(prediction, content_type):
    """Format predictions for output"""
    if content_type == "application/json":
        # Ensure predictions are in list format
        predictions_list = prediction.tolist() if hasattr(prediction, 'tolist') else prediction
        
        # Create detailed response
        response = {
            "predictions": predictions_list,
            "fraud_probability": predictions_list
        }
        
        # Add detailed predictions
        detailed = []
        for prob in predictions_list:
            detailed.append({
                "fraud_probability": float(prob),
                "is_fraud": prob > 0.5,
                "risk_level": get_risk_level(prob)
            })
        response["detailed_predictions"] = detailed
        
        return json.dumps(response)
    else:
        raise ValueError(f"Unsupported content type: {content_type}")

def get_risk_level(prob):
    """Determine risk level based on probability"""
    if prob >= 0.8:
        return 'CRITICAL'
    elif prob >= 0.6:
        return 'HIGH'
    elif prob >= 0.3:
        return 'MEDIUM'
    else:
        return 'LOW'