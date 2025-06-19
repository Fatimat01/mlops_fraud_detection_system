# app/main.py - FastAPI as SageMaker Endpoint
"""
FastAPI application for SageMaker custom container
This runs INSIDE the SageMaker endpoint, not as a proxy to it
"""

import os
import json
import joblib
import pandas as pd
import numpy as np
from typing import List, Dict, Any, Union
from datetime import datetime
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, PlainTextResponse
from pydantic import BaseModel, Field

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global model variable
model = None

# Feature names
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

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load model on startup"""
    global model
    
    # Model path in SageMaker
    model_path = os.path.join(os.environ.get('MODEL_PATH', '/opt/ml/model'), 'model.pkl')
    
    try:
        logger.info(f"Loading model from {model_path}")
        model = joblib.load(model_path)
        logger.info(f"Model loaded successfully. Type: {type(model)}")
    except Exception as e:
        logger.error(f"Failed to load model: {str(e)}")
        raise
    
    yield
    
    # Cleanup if needed
    logger.info("Shutting down")

# Initialize FastAPI app
app = FastAPI(
    title="Fraud Detection SageMaker Endpoint",
    description="Custom SageMaker container for fraud detection",
    version="1.0.0",
    lifespan=lifespan
)

# Pydantic models
class PredictionItem(BaseModel):
    """Single prediction item"""
    fraud_probability: float
    is_fraud: bool
    risk_level: str
    confidence: float

class PredictionResponse(BaseModel):
    """Response for predictions"""
    predictions: List[float]
    fraud_probability: List[float]
    detailed_predictions: List[PredictionItem]
    metadata: Dict[str, Any] = {}

def get_risk_level(prob: float) -> str:
    """Determine risk level based on probability"""
    if prob >= 0.8:
        return 'CRITICAL'
    elif prob >= 0.6:
        return 'HIGH'
    elif prob >= 0.3:
        return 'MEDIUM'
    else:
        return 'LOW'

def prepare_features(data: Union[Dict, List[Dict]]) -> pd.DataFrame:
    """Prepare features for prediction"""
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
    return df[FEATURE_NAMES]

@app.get("/ping", response_class=PlainTextResponse)
async def ping():
    """
    SageMaker health check endpoint
    Must return 200 with no body or simple text
    """
    if model is not None:
        return PlainTextResponse("", status_code=200)
    else:
        return PlainTextResponse("Model not loaded", status_code=503)

@app.post("/invocations")
async def invocations(request: Request):
    """
    SageMaker inference endpoint
    This is the main prediction endpoint
    """
    try:
        # Get content type
        content_type = request.headers.get("content-type", "application/json")
        
        if content_type != "application/json":
            raise HTTPException(
                status_code=415,
                detail=f"Unsupported content type: {content_type}"
            )
        
        # Parse request body
        body = await request.json()
        
        # SageMaker can send data in different formats
        # Check for 'instances' key (SageMaker batch transform)
        if isinstance(body, dict) and 'instances' in body:
            data = body['instances']
        else:
            data = body
        
        # Prepare features
        df = prepare_features(data)
        
        # Make predictions
        if model is None:
            raise HTTPException(
                status_code=503,
                detail="Model not loaded"
            )
        
        # Get probabilities
        probabilities = model.predict_proba(df)[:, 1]
        
        # Build detailed predictions
        detailed_predictions = []
        for prob in probabilities:
            detailed = PredictionItem(
                fraud_probability=float(prob),
                is_fraud=bool(prob > 0.5),
                risk_level=get_risk_level(prob),
                confidence=float(abs(prob - 0.5) * 2)
            )
            detailed_predictions.append(detailed)
        
        # Build response
        response = {
            "predictions": probabilities.tolist(),
            "fraud_probability": probabilities.tolist(),
            "detailed_predictions": [item.dict() for item in detailed_predictions],
            "metadata": {
                "model_version": "1.0",
                "prediction_count": len(probabilities),
                "timestamp": datetime.now().isoformat()
            }
        }
        
        return JSONResponse(content=response)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Prediction error: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Prediction failed: {str(e)}"
        )

# Optional: Additional endpoints for debugging (not required by SageMaker)
@app.get("/")
async def root():
    """Root endpoint - not used by SageMaker"""
    return {
        "message": "Fraud Detection SageMaker Endpoint",
        "health": "/ping",
        "predict": "/invocations"
    }

@app.get("/model-info")
async def model_info():
    """Get model information - for debugging"""
    return {
        "model_loaded": model is not None,
        "model_type": str(type(model)) if model else None,
        "features": FEATURE_NAMES,
        "feature_count": len(FEATURE_NAMES)
    }

# Error handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "timestamp": datetime.now().isoformat()
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "timestamp": datetime.now().isoformat()
        }
    )

if __name__ == "__main__":
    import uvicorn
    
    # SageMaker expects port 8080
    port = int(os.getenv('PORT', 8080))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        log_level="info"
    )