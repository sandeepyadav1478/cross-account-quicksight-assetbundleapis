import boto3
import os
import logging
import time
import urllib.request
import random

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    logger.info("Handler started")
    
    required_env_vars = [
        'SOURCE_ACCOUNT_ID',
        'TARGET_ACCOUNT_ID',
        'SOURCE_DASHBOARD_ID',
        'S3_BUCKET',
        'AWS_REGION',
        'SOURCE_AWS_ACCESS_KEY',
        'SOURCE_AWS_SECRET_KEY',
        'TARGET_AWS_ACCESS_KEY',
        'TARGET_AWS_SECRET_KEY'
    ]

    missing_env_vars = [var for var in required_env_vars if var not in os.environ]
    if missing_env_vars:
        logger.error(f"Missing required environment variables: {missing_env_vars}")
        return {
            'statusCode': 400,
            'body': f"Missing required environment variables: {missing_env_vars}"
        }

    source_account_id = os.environ['SOURCE_ACCOUNT_ID']
    target_account_id = os.environ['TARGET_ACCOUNT_ID']
    source_dashboard_id = os.environ['SOURCE_DASHBOARD_ID']
    s3_bucket = os.environ['S3_BUCKET']
    region = os.environ['AWS_REGION']

    logger.info(f"Source Account ID: {source_account_id}")
    logger.info(f"Target Account ID: {target_account_id}")
    logger.info(f"Source Dashboard ID: {source_dashboard_id}")
    logger.info(f"S3 Bucket: {s3_bucket}")

    # Generate a common random 4-digit number for both job IDs and unique identifiers
    job_id_suffix = random.randint(1000, 9999)
    export_job_id = f"export-job-{job_id_suffix}"
    import_job_id = f"import-job-{job_id_suffix}"
    new_dashboard_name = f"Dashboard-{job_id_suffix}"
    s3_key = f"exports/asset-bundle-{job_id_suffix}.qs"

    logger.info(f"Export Job ID: {export_job_id}")
    logger.info(f"Import Job ID: {import_job_id}")
    logger.info(f"New Dashboard Name: {new_dashboard_name}")
    logger.info(f"S3 Key: {s3_key}")

    # Initialize QuickSight clients for both source and target accounts
    source_quicksight = boto3.client('quicksight', region_name=region, aws_access_key_id=os.environ['SOURCE_AWS_ACCESS_KEY'], aws_secret_access_key=os.environ['SOURCE_AWS_SECRET_KEY'])
    target_quicksight = boto3.client('quicksight', region_name=region, aws_access_key_id=os.environ['TARGET_AWS_ACCESS_KEY'], aws_secret_access_key=os.environ['TARGET_AWS_SECRET_KEY'])
    s3_client = boto3.client('s3', region_name=region, aws_access_key_id=os.environ['TARGET_AWS_ACCESS_KEY'], aws_secret_access_key=os.environ['TARGET_AWS_SECRET_KEY'])

    try:
        # Start asset bundle export job
        logger.info("Starting asset bundle export job")
        export_response = source_quicksight.start_asset_bundle_export_job(
            AwsAccountId=source_account_id,
            AssetBundleExportJobId=export_job_id,
            ResourceArns=[f"arn:aws:quicksight:{region}:{source_account_id}:dashboard/{source_dashboard_id}"],
            IncludeAllDependencies=True,
            ExportFormat='QUICKSIGHT_JSON'
        )
        logger.info(f"Asset bundle export job started successfully: {export_response}")
    except Exception as e:
        logger.error(f"Error starting asset bundle export job: {e}")
        raise e

    # Wait for the export job to complete and get the presigned URL
    export_job_status = None
    presigned_url = None
    logger.info("Waiting for export job to complete")
    for _ in range(12):  # Poll for up to 2 minutes (12 * 10 seconds)
        try:
            response = source_quicksight.describe_asset_bundle_export_job(
                AwsAccountId=source_account_id,
                AssetBundleExportJobId=export_job_id
            )
            logger.info(f"Describe export job response: {response}")
            export_job_status = response['JobStatus']
            logger.info(f"Export job status: {export_job_status}")
            if export_job_status == 'SUCCESSFUL':
                presigned_url = response['DownloadUrl']
                break
        except Exception as e:
            logger.error(f"Error describing export job: {e}")
        time.sleep(10)

    if export_job_status != 'SUCCESSFUL':
        raise Exception(f"Export job failed or timed out. Status: {export_job_status}")

    logger.info(f"Presigned URL: {presigned_url}")

    # Download the file from the presigned URL and upload it to the target S3 bucket
    try:
        logger.info("Downloading file from presigned URL")
        with urllib.request.urlopen(presigned_url) as response:
            file_content = response.read()
        logger.info("File downloaded successfully")

        logger.info("Uploading file to target S3 bucket")
        s3_client.put_object(
            Bucket=s3_bucket,
            Key=s3_key,
            Body=file_content
        )
        logger.info("File uploaded successfully to target S3 bucket")
    except Exception as e:
        logger.error(f"Error downloading or uploading file: {e}")
        raise e

    try:
        # Start asset bundle import job
        logger.info("Starting asset bundle import job")
        import_response = target_quicksight.start_asset_bundle_import_job(
            AwsAccountId=target_account_id,
            AssetBundleImportJobId=import_job_id,
            AssetBundleImportSource={
                'S3Uri': f"s3://{s3_bucket}/{s3_key}"
            },
            OverrideParameters={
                'Dashboards': [
                    {
                        'DashboardId': source_dashboard_id,
                        'Name': new_dashboard_name
                    }
                ]
            }
        )
        logger.info(f"Asset bundle import job started successfully: {import_response}")
    except Exception as e:
        logger.error(f"Error starting asset bundle import job: {e}")
        raise e

    # Wait for the import job to complete
    import_job_status = None
    logger.info("Waiting for import job to complete")
    for _ in range(12):  # Poll for up to 2 minutes (12 * 10 seconds)
        try:
            response = target_quicksight.describe_asset_bundle_import_job(
                AwsAccountId=target_account_id,
                AssetBundleImportJobId=import_job_id
            )
            logger.info(f"Describe import job response: {response}")
            import_job_status = response['JobStatus']
            logger.info(f"Import job status: {import_job_status}")
            if import_job_status == 'SUCCESSFUL':
                break
        except Exception as e:
            logger.error(f"Error describing import job: {e}")
        time.sleep(10)

    if import_job_status != 'SUCCESSFUL':
        raise Exception(f"Import job failed or timed out. Status: {import_job_status}")

    logger.info("Handler completed successfully")
    return {
        'statusCode': 200,
        'body': 'Assets transferred successfully'
    }