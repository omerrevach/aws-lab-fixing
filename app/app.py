from flask import Flask, render_template
import boto3
from botocore.config import Config
import os
import random
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

bucket_name = os.getenv("S3_BUCKET", "stockpnl-data")
region_name = os.getenv("AWS_REGION", "eu-north-1")

s3 = boto3.client(
    's3',
    region_name=region_name,
    config=Config(signature_version='s3v4')
)

@app.route("/")
def home():
    try:
        # Log identity for debugging
        try:
            sts = boto3.client('sts')
            identity = sts.get_caller_identity()
            logger.info(f"Current AWS identity: {identity['Arn']}")
        except Exception as e:
            logger.warning(f"Could not get caller identity: {str(e)}")
        
        # List objects in the bucket
        response = s3.list_objects_v2(Bucket=bucket_name)
        
        # Filter for image files
        image_files = [
            obj["Key"] for obj in response.get("Contents", []) 
            if obj["Key"].lower().endswith((".png", ".jpg", ".jpeg"))
        ]
        
        if not image_files:
            logger.warning(f"No images found in bucket {bucket_name}")
            return "No images found in the S3 bucket."
        
        # Select a random image
        selected_image = random.choice(image_files)
        logger.info(f"Selected image: {selected_image}")
        
        # Generate presigned URL
        image_url = s3.generate_presigned_url(
            ClientMethod="get_object",
            Params={"Bucket": bucket_name, "Key": selected_image},
            ExpiresIn=300  # 5 minutes
        )
        
        # Log URL for debugging
        logger.info(f"Generated presigned URL (truncated): {image_url[:50]}...")
        
        return render_template("index.html", image_url=image_url)
    
    except Exception as e:
        logger.error(f"Error accessing S3: {str(e)}")
        return f"Error accessing images: {str(e)}"

@app.route("/health")
def health():
    return "OK"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)