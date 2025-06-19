"""
Streamlit Demo Interface for Insurance Fraud Detection System
"""

import streamlit as st
import requests
import json
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
import boto3
import os
from typing import Dict, Any
import time

# Page configuration
st.set_page_config(
    page_title="Insurance Fraud Detection System",
    page_icon="🛡️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
.metric-card {
    background-color: #f0f2f6;
    padding: 1rem;
    border-radius: 0.5rem;
    margin: 0.5rem 0;
}

.fraud-high {
    background-color: #ffebee;
    border-left: 5px solid #f44336;
}

.fraud-medium {
    background-color: #fff3e0;
    border-left: 5px solid #ff9800;
}

.fraud-low {
    background-color: #e8f5e8;
    border-left: 5px solid #4caf50;
}

.fraud-critical {
    background-color: #fce4ec;
    border-left: 5px solid #e91e63;
}
</style>
""", unsafe_allow_html=True)

# Configuration
API_BASE_URL = os.getenv('API_BASE_URL', 'http://localhost:8000')
ENDPOINT_NAME = os.getenv('ENDPOINT_NAME', 'fraud-detection-endpoint')

# Initialize session state
if 'predictions_history' not in st.session_state:
    st.session_state.predictions_history = []

if 'batch_results' not in st.session_state:
    st.session_state.batch_results = None


def get_api_health():
    """Check API health status"""
    try:
        response = requests.get(f"{API_BASE_URL}/health", timeout=5)
        return response.status_code == 200, response.json() if response.status_code == 200 else None
    except:
        return False, None


def make_prediction(claim_data: Dict[str, Any]) -> Dict[str, Any]:
    """Make single prediction via API"""
    try:
        response = requests.post(
            f"{API_BASE_URL}/predict",
            json=claim_data,
            timeout=30
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        st.error(f"API request failed: {str(e)}")
        return None


def make_batch_prediction(claims_data: list) -> Dict[str, Any]:
    """Make batch prediction via API"""
    try:
        response = requests.post(
            f"{API_BASE_URL}/batch-predict",
            json={"claims": claims_data},
            timeout=60
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        st.error(f"Batch prediction failed: {str(e)}")
        return None


def get_demo_data():
    """Get demo data from API"""
    try:
        response = requests.get(f"{API_BASE_URL}/demo", timeout=5)
        if response.status_code == 200:
            return response.json()
    except:
        pass
    
    # Fallback demo data
    return {
        "normal_claim": {
            "claim_id": "DEMO-NORMAL-001",
            "months_as_customer": 24,
            "age": 45,
            "policy_deductable": 500,
            "umbrella_limit": 0,
            "insured_sex": 1,
            "insured_education_level": 3,
            "insured_occupation": 2,
            "insured_hobbies": 0,
            "insured_relationship": 1,
            "incident_type": 1,
            "collision_type": 1,
            "incident_severity": 1,
            "authorities_contacted": 1,
            "number_of_vehicles_involved": 2,
            "property_damage": 0,
            "bodily_injuries": 0,
            "witnesses": 2,
            "police_report_available": 1,
            "total_claim_amount": 8000,
            "injury_claim": 0,
            "property_claim": 2000,
            "vehicle_claim": 6000,
            "auto_make": 2,
            "auto_year": 2018,
            "incident_hour_bin": 2,
            "claim_ratio": 1.0
        },
        "suspicious_claim": {
            "claim_id": "DEMO-SUSPICIOUS-001",
            "months_as_customer": 1,
            "age": 22,
            "policy_deductable": 1000,
            "umbrella_limit": 1000000,
            "insured_sex": 0,
            "insured_education_level": 0,
            "insured_occupation": 5,
            "insured_hobbies": 2,
            "insured_relationship": 0,
            "incident_type": 3,
            "collision_type": 2,
            "incident_severity": 3,
            "authorities_contacted": 0,
            "number_of_vehicles_involved": 4,
            "property_damage": 1,
            "bodily_injuries": 3,
            "witnesses": 0,
            "police_report_available": 0,
            "total_claim_amount": 95000,
            "injury_claim": 40000,
            "property_claim": 30000,
            "vehicle_claim": 25000,
            "auto_make": 3,
            "auto_year": 2003,
            "incident_hour_bin": 4,
            "claim_ratio": 1.0
        }
    }


def render_prediction_result(result: Dict[str, Any]):
    """Render prediction result with styling"""
    if not result:
        return
    
    risk_level = result.get('risk_level', 'UNKNOWN')
    fraud_prob = result.get('fraud_probability', 0)
    confidence = result.get('confidence', 0)
    claim_id = result.get('claim_id', 'N/A')
    
    # Determine styling based on risk level
    risk_colors = {
        'LOW': ('success', '#4caf50'),
        'MEDIUM': ('warning', '#ff9800'),
        'HIGH': ('error', '#f44336'),
        'CRITICAL': ('error', '#e91e63')
    }
    
    color_type, color_code = risk_colors.get(risk_level, ('info', '#2196f3'))
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric(
            label="Risk Level",
            value=risk_level,
            delta=f"Claim ID: {claim_id}"
        )
    
    with col2:
        st.metric(
            label="Fraud Probability",
            value=f"{fraud_prob:.1%}",
            delta=f"Confidence: {confidence:.1%}"
        )
    
    with col3:
        st.metric(
            label="Is Fraud",
            value="YES" if result.get('is_fraud', 0) else "NO",
            delta=f"Processing: {result.get('processing_time_ms', 0):.1f}ms"
        )
    
    with col4:
        # Risk level indicator
        fig = go.Figure(go.Indicator(
            mode = "gauge+number",
            value = fraud_prob * 100,
            domain = {'x': [0, 1], 'y': [0, 1]},
            title = {'text': "Risk Score"},
            gauge = {
                'axis': {'range': [None, 100]},
                'bar': {'color': color_code},
                'steps': [
                    {'range': [0, 30], 'color': "lightgray"},
                    {'range': [30, 60], 'color': "gray"},
                    {'range': [60, 100], 'color': "lightcoral"}
                ],
                'threshold': {
                    'line': {'color': "red", 'width': 4},
                    'thickness': 0.75,
                    'value': 80
                }
            }
        ))
        fig.update_layout(height=200, margin=dict(l=20, r=20, t=40, b=20))
        st.plotly_chart(fig, use_container_width=True)


def main():
    st.title("🛡️ Insurance Fraud Detection System")
    st.markdown("**Real-time fraud detection powered by Machine Learning**")
    
    # Check API health
    health_status, health_data = get_api_health()
    
    if health_status:
        st.success("✅ System is online and ready")
        if health_data:
            endpoint_status = health_data.get('endpoint_status', 'Unknown')
            st.info(f"SageMaker Endpoint: {endpoint_status}")
    else:
        st.error("❌ System is offline. Please check the API service.")
        st.stop()
    
    # Sidebar for navigation
    st.sidebar.title("Navigation")
    page = st.sidebar.selectbox(
        "Choose a page:",
        ["Single Claim Analysis", "Batch Processing", "System Monitoring", "Demo Data"]
    )
    
    if page == "Single Claim Analysis":
        render_single_claim_page()
    elif page == "Batch Processing":
        render_batch_processing_page()
    elif page == "System Monitoring":
        render_monitoring_page()
    elif page == "Demo Data":
        render_demo_page()


def render_single_claim_page():
    """Render single claim analysis page"""
    st.header("Single Claim Fraud Analysis")
    
    # Demo data buttons
    demo_data = get_demo_data()
    col1, col2, col3 = st.columns([1, 1, 2])
    
    with col1:
        if st.button("Load Normal Claim"):
            st.session_state.demo_claim = demo_data['normal_claim']
    
    with col2:
        if st.button("Load Suspicious Claim"):
            st.session_state.demo_claim = demo_data['suspicious_claim']
    
    # Form for claim input
    with st.form("claim_form"):
        st.subheader("Claim Information")
        
        # Get default values from session state or use empty defaults
        default_claim = st.session_state.get('demo_claim', {})
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("**Customer Information**")
            claim_id = st.text_input("Claim ID", value=default_claim.get('claim_id', ''))
            months_as_customer = st.number_input("Months as Customer", min_value=0, max_value=600, value=default_claim.get('months_as_customer', 12))
            age = st.number_input("Age", min_value=18, max_value=100, value=default_claim.get('age', 35))
            policy_deductable = st.number_input("Policy Deductible ($)", min_value=0, value=default_claim.get('policy_deductable', 500))
            umbrella_limit = st.number_input("Umbrella Limit ($)", min_value=0, value=default_claim.get('umbrella_limit', 0))
            
            st.markdown("**Demographics**")
            insured_sex = st.selectbox("Sex", [0, 1], index=default_claim.get('insured_sex', 0), format_func=lambda x: "Female" if x == 0 else "Male")
            insured_education_level = st.selectbox("Education Level", list(range(6)), index=default_claim.get('insured_education_level', 3))
            insured_occupation = st.selectbox("Occupation", list(range(11)), index=default_claim.get('insured_occupation', 2))
            insured_hobbies = st.selectbox("Hobbies Risk Level", list(range(6)), index=default_claim.get('insured_hobbies', 0))
            insured_relationship = st.selectbox("Relationship Status", list(range(6)), index=default_claim.get('insured_relationship', 1))
        
        with col2:
            st.markdown("**Incident Details**")
            incident_type = st.selectbox("Incident Type", list(range(6)), index=default_claim.get('incident_type', 1))
            collision_type = st.selectbox("Collision Type", list(range(6)), index=default_claim.get('collision_type', 1))
            incident_severity = st.selectbox("Incident Severity", [1, 2, 3, 4], index=default_claim.get('incident_severity', 2) - 1)
            authorities_contacted = st.selectbox("Authorities Contacted", [0, 1], index=default_claim.get('authorities_contacted', 1), format_func=lambda x: "No" if x == 0 else "Yes")
            number_of_vehicles_involved = st.number_input("Vehicles Involved", min_value=1, max_value=10, value=default_claim.get('number_of_vehicles_involved', 2))
            property_damage = st.selectbox("Property Damage", [0, 1], index=default_claim.get('property_damage', 0), format_func=lambda x: "No" if x == 0 else "Yes")
            bodily_injuries = st.number_input("Bodily Injuries", min_value=0, max_value=10, value=default_claim.get('bodily_injuries', 0))
            witnesses = st.number_input("Witnesses", min_value=0, max_value=10, value=default_claim.get('witnesses', 1))
            police_report_available = st.selectbox("Police Report", [0, 1], index=default_claim.get('police_report_available', 1), format_func=lambda x: "No" if x == 0 else "Yes")
            
            st.markdown("**Financial Information**")
            total_claim_amount = st.number_input("Total Claim Amount ($)", min_value=0, value=default_claim.get('total_claim_amount', 15000))
            injury_claim = st.number_input("Injury Claim ($)", min_value=0, value=default_claim.get('injury_claim', 1000))
            property_claim = st.number_input("Property Claim ($)", min_value=0, value=default_claim.get('property_claim', 2000))
            vehicle_claim = st.number_input("Vehicle Claim ($)", min_value=0, value=default_claim.get('vehicle_claim', 12000))
            
            st.markdown("**Vehicle Information**")
            auto_make = st.selectbox("Auto Make", list(range(20)), index=default_claim.get('auto_make', 2))
            auto_year = st.number_input("Auto Year", min_value=1980, max_value=2025, value=default_claim.get('auto_year', 2018))
            incident_hour_bin = st.selectbox("Incident Hour Bin", list(range(6)), index=default_claim.get('incident_hour_bin', 2))
            
            # Calculate claim ratio
            total_sub_claims = injury_claim + property_claim + vehicle_claim
            claim_ratio = total_sub_claims / total_claim_amount if total_claim_amount > 0 else 0
            st.metric("Calculated Claim Ratio", f"{claim_ratio:.2f}")
        
        submitted = st.form_submit_button("Analyze Claim")
        
        if submitted:
            # Prepare claim data
            claim_data = {
                "claim_id": claim_id or f"CLAIM-{int(time.time())}",
                "months_as_customer": months_as_customer,
                "age": age,
                "policy_deductable": policy_deductable,
                "umbrella_limit": umbrella_limit,
                "insured_sex": insured_sex,
                "insured_education_level": insured_education_level,
                "insured_occupation": insured_occupation,
                "insured_hobbies": insured_hobbies,
                "insured_relationship": insured_relationship,
                "incident_type": incident_type,
                "collision_type": collision_type,
                "incident_severity": incident_severity,
                "authorities_contacted": authorities_contacted,
                "number_of_vehicles_involved": number_of_vehicles_involved,
                "property_damage": property_damage,
                "bodily_injuries": bodily_injuries,
                "witnesses": witnesses,
                "police_report_available": police_report_available,
                "total_claim_amount": total_claim_amount,
                "injury_claim": injury_claim,
                "property_claim": property_claim,
                "vehicle_claim": vehicle_claim,
                "auto_make": auto_make,
                "auto_year": auto_year,
                "incident_hour_bin": incident_hour_bin,
                "claim_ratio": claim_ratio
            }
            
            # Make prediction
            with st.spinner("Analyzing claim..."):
                result = make_prediction(claim_data)
            
            if result:
                st.success("Analysis complete!")
                render_prediction_result(result)
                
                # Add to history
                result['timestamp'] = datetime.now().isoformat()
                result['input_data'] = claim_data
                st.session_state.predictions_history.append(result)
            else:
                st.error("Analysis failed. Please try again.")


def render_batch_processing_page():
    """Render batch processing page"""
    st.header("Batch Claim Processing")
    
    # File upload
    uploaded_file = st.file_uploader("Upload CSV file with claims", type=['csv'])
    
    if uploaded_file is not None:
        try:
            df = pd.read_csv(uploaded_file)
            st.success(f"Loaded {len(df)} claims from file")
            
            # Show preview
            st.subheader("Data Preview")
            st.dataframe(df.head())
            
            # Process batch
            if st.button("Process Batch"):
                with st.spinner(f"Processing {len(df)} claims..."):
                    # Convert dataframe to list of dictionaries
                    claims_data = df.to_dict('records')
                    
                    # Make batch prediction
                    batch_result = make_batch_prediction(claims_data)
                
                if batch_result:
                    st.session_state.batch_results = batch_result
                    st.success("Batch processing complete!")
                    
                    # Show summary
                    st.subheader("Batch Summary")
                    col1, col2, col3, col4 = st.columns(4)
                    
                    with col1:
                        st.metric("Total Claims", batch_result['total_claims'])
                    with col2:
                        st.metric("Fraudulent Claims", batch_result['fraud_count'])
                    with col3:
                        st.metric("Fraud Rate", f"{batch_result['fraud_rate']:.1%}")
                    with col4:
                        st.metric("Avg Fraud Probability", f"{batch_result['avg_fraud_probability']:.1%}")
                    
                    # Show results
                    predictions_df = pd.DataFrame(batch_result['predictions'])
                    st.subheader("Detailed Results")
                    st.dataframe(predictions_df)
                    
                    # Download results
                    csv = predictions_df.to_csv(index=False)
                    st.download_button(
                        label="Download Results as CSV",
                        data=csv,
                        file_name=f"fraud_predictions_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
                        mime='text/csv'
                    )
                else:
                    st.error("Batch processing failed. Please try again.")
                    
        except Exception as e:
            st.error(f"Error processing file: {str(e)}")
    
    # Show previous batch results if available
    if st.session_state.batch_results:
        st.subheader("Previous Batch Results")
        
        # Risk distribution chart
        predictions_df = pd.DataFrame(st.session_state.batch_results['predictions'])
        
        col1, col2 = st.columns(2)
        
        with col1:
            # Risk level distribution
            risk_counts = predictions_df['risk_level'].value_counts()
            fig = px.pie(
                values=risk_counts.values,
                names=risk_counts.index,
                title="Risk Level Distribution",
                color_discrete_map={
                    'LOW': '#4caf50',
                    'MEDIUM': '#ff9800',
                    'HIGH': '#f44336',
                    'CRITICAL': '#e91e63'
                }
            )
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            # Fraud probability distribution
            fig = px.histogram(
                predictions_df,
                x='fraud_probability',
                title="Fraud Probability Distribution",
                nbins=20
            )
            st.plotly_chart(fig, use_container_width=True)


def render_monitoring_page():
    """Render system monitoring page"""
    st.header("System Monitoring")
    
    # Get metrics
    try:
        response = requests.get(f"{API_BASE_URL}/metrics?period_hours=1", timeout=10)
        if response.status_code == 200:
            metrics = response.json()
            
            # Display metrics
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                st.metric("Total Invocations", metrics['total_invocations'])
            with col2:
                st.metric("Average Latency", f"{metrics['avg_latency_ms']:.1f}ms")
            with col3:
                st.metric("Max Latency", f"{metrics['max_latency_ms']:.1f}ms")
            with col4:
                st.metric("Error Rate", f"{metrics['error_rate']:.2%}")
            
            # System status
            if metrics['error_rate'] < 0.01 and metrics['avg_latency_ms'] < 1000:
                st.success("🟢 System is performing well")
            elif metrics['error_rate'] < 0.05 and metrics['avg_latency_ms'] < 2000:
                st.warning("🟡 System performance is acceptable")
            else:
                st.error("🔴 System performance issues detected")
                
        else:
            st.error("Failed to retrieve metrics")
            
    except Exception as e:
        st.error(f"Monitoring data unavailable: {str(e)}")
    
    # Prediction history
    if st.session_state.predictions_history:
        st.subheader("Recent Predictions History")
        
        history_df = pd.DataFrame([
            {
                'timestamp': pred['timestamp'],
                'claim_id': pred.get('claim_id', 'N/A'),
                'fraud_probability': pred['fraud_probability'],
                'risk_level': pred['risk_level'],
                'processing_time_ms': pred.get('processing_time_ms', 0)
            }
            for pred in st.session_state.predictions_history[-20:]  # Last 20 predictions
        ])
        
        st.dataframe(history_df)
        
        # Charts
        col1, col2 = st.columns(2)
        
        with col1:
            # Risk level over time
            fig = px.scatter(
                history_df,
                x='timestamp',
                y='fraud_probability',
                color='risk_level',
                title="Fraud Probability Over Time",
                color_discrete_map={
                    'LOW': '#4caf50',
                    'MEDIUM': '#ff9800',
                    'HIGH': '#f44336',
                    'CRITICAL': '#e91e63'
                }
            )
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            # Processing time
            fig = px.line(
                history_df,
                x='timestamp',
                y='processing_time_ms',
                title="Processing Time Trend"
            )
            st.plotly_chart(fig, use_container_width=True)


def render_demo_page():
    """Render demo data page"""
    st.header("Demo Data & API Testing")
    
    demo_data = get_demo_data()
    
    st.subheader("Sample Claims")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("**Normal Claim Example**")
        st.json(demo_data['normal_claim'])
        
        if st.button("Test Normal Claim"):
            with st.spinner("Testing..."):
                result = make_prediction(demo_data['normal_claim'])
            if result:
                st.success("Test successful!")
                render_prediction_result(result)
    
    with col2:
        st.markdown("**Suspicious Claim Example**")
        st.json(demo_data['suspicious_claim'])
        
        if st.button("Test Suspicious Claim"):
            with st.spinner("Testing..."):
                result = make_prediction(demo_data['suspicious_claim'])
            if result:
                st.success("Test successful!")
                render_prediction_result(result)
    
    # API documentation
    st.subheader("API Endpoints")
    
    endpoints = [
        {"Method": "GET", "Endpoint": "/", "Description": "API information"},
        {"Method": "GET", "Endpoint": "/health", "Description": "Health check"},
        {"Method": "POST", "Endpoint": "/predict", "Description": "Single prediction"},
        {"Method": "POST", "Endpoint": "/batch-predict", "Description": "Batch prediction"},
        {"Method": "GET", "Endpoint": "/metrics", "Description": "System metrics"},
        {"Method": "GET", "Endpoint": "/demo", "Description": "Demo data"}
    ]
    
    st.table(pd.DataFrame(endpoints))
    
    # API testing
    st.subheader("API Status")
    
    if st.button("Test All Endpoints"):
        endpoints_to_test = ["/", "/health", "/demo", "/metrics"]
        
        for endpoint in endpoints_to_test:
            try:
                response = requests.get(f"{API_BASE_URL}{endpoint}", timeout=5)
                if response.status_code == 200:
                    st.success(f"✅ {endpoint} - Status: {response.status_code}")
                else:
                    st.error(f"❌ {endpoint} - Status: {response.status_code}")
            except Exception as e:
                st.error(f"❌ {endpoint} - Error: {str(e)}")


if __name__ == "__main__":
    main()