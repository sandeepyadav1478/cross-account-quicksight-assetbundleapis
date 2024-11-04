resource "aws_iam_role" "quicksight_cross_account_role" {
  provider = aws.source
  name     = "quicksight_cross_account_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.target_account_id}:user/${var.target_account_aws_user_name}"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "quicksight_cross_account_policy" {
  provider = aws.source
  name     = "quicksight_cross_account_policy"
  role     = aws_iam_role.quicksight_cross_account_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "quicksight:DescribeTemplate",
          "quicksight:CreateTemplate",
          "quicksight:UpdateTemplate",
          "quicksight:DeleteTemplate",
          "quicksight:StartAssetBundleExportJob",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
            "arn:aws:quicksight:${var.source_aws_region}:${var.source_account_id}:template/*",
          "arn:aws:s3:::quicksight-asset-bundle-export-job-us-east-1/*"
        ]
      }
    ]
  })
}


resource "aws_iam_role" "lambda_role" {
  provider = aws.target
  name     = "quicksight_copy_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.source_account_id}:role/quicksight_cross_account_role"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  provider = aws.target
  name     = "quicksight_copy_policy"
  role     = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "quicksight:DescribeDashboard",
          "quicksight:CreateDashboard",
          "quicksight:ListDataSets",
          "quicksight:DescribeDataSet",
          "quicksight:DescribeTemplate",
          "quicksight:CreateTemplate",
          "quicksight:UpdateTemplate",
          "quicksight:DeleteTemplate",
          "quicksight:StartAssetBundleImportJob",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = "*"
      }
    ]
  })
}


resource "aws_s3_bucket" "quicksight_assets_bucket" {
  provider = aws.target
  bucket   = "quicksight-assets-${var.target_account_id}"
}

resource "aws_s3_bucket_policy" "quicksight_assets_bucket_policy" {
  provider = aws.target
  bucket   = aws_s3_bucket.quicksight_assets_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.source_account_id}:role/quicksight_cross_account_role"
        },
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "${aws_s3_bucket.quicksight_assets_bucket.arn}",
          "${aws_s3_bucket.quicksight_assets_bucket.arn}/*"
        ]
      }
    ]
  })
}


resource "aws_lambda_function" "copy_quicksight_dashboard" {
  provider         = aws.target
  filename         = "lambda_function_payload.zip"
  function_name    = "copy_quicksight_dashboard"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.8"
  source_code_hash = filebase64sha256("lambda_function_payload.zip")
  timeout          = 300  # Increase the timeout to 300 seconds
  memory_size      = 1024  # Increase memory allocation to 1024 MB

  environment {
    variables = {
      TARGET_ACCOUNT_ID     = var.target_account_id
      SOURCE_DASHBOARD_ID   = var.source_dashboard_id
      SOURCE_ACCOUNT_ID     = var.source_account_id
      SOURCE_AWS_ACCESS_KEY = var.source_aws_access_key
      SOURCE_AWS_SECRET_KEY = var.source_aws_secret_key
      TARGET_AWS_ACCESS_KEY = var.target_aws_access_key
      TARGET_AWS_SECRET_KEY = var.target_aws_secret_key
      S3_BUCKET             = aws_s3_bucket.quicksight_assets_bucket.bucket
    }
  }

  depends_on = [aws_iam_role.lambda_role, aws_iam_role_policy.lambda_policy, aws_s3_bucket.quicksight_assets_bucket]
}

resource "aws_lambda_invocation" "invoke_lambda" {
  provider      = aws.target
  function_name = aws_lambda_function.copy_quicksight_dashboard.function_name
  input         = jsonencode({})

  depends_on = [aws_lambda_function.copy_quicksight_dashboard]
}

output "lambda_response" {
  value = aws_lambda_invocation.invoke_lambda.result
}