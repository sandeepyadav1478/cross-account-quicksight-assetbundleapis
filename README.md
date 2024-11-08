# CROSS-ACCOUNT-DASHBOARD-IMPORT-AssetbundleAPIs

### Requirements
- Source and Destination aws accounts must have role alterations permissions.
- Also, full `quicksight` access.
- make a `terraform.tfvars` file using syntax of `terraform.tfvars.example`
- Copy dashboard id from dashboard url, add it inside `terraform.tfvars` file



### Tools Requirements
- Terraform: latest verions
- 2 AWS accounts ( Source, Destination)



### Deployment using commands ( Inside this directory only)
1. ```Terraform init``` - Will download required modules
2. Add all creds inside `terraform.tfvars`
3. ```Terraform plan``` - This will list all resource changes on cloud
4. ```Terraform apply -auto-approve``` - ***Important***: This is final step
    - The output for successful job, should looks like
        ```
        lambda_response = "{\"statusCode\": 200, \"body\": \"Assets transferred successfully\"}"
        ```
5. ```Terraform destroy``` - Cleanup stage after all task done ( have to manually remove s3 bucket for now)



### Other general commands
1. To list all dashboards in an account ( need aws cli locally configured )
    ```
    aws quicksight list-dashboards --aws-account-id 123456789012 --region 'us-east-1'
    ```
2. If lambda code in `index.py` file got changes, then run 
    ```
    zip lambda_function_payload.zip index.py 
    ```
    to modify zip file, which is used by lambda function updates.

### Sources
- https://aws.amazon.com/blogs/business-intelligence/automate-and-accelerate-your-amazon-quicksight-asset-deployments-using-the-new-apis/
- https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/quicksight/client/start_asset_bundle_import_job.html


### Alternate Approach
- https://aws.amazon.com/blogs/big-data/migrate-amazon-quicksight-across-aws-accounts/
