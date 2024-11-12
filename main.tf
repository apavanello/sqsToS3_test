# Terraform configuration for SQS-to-S3 Lambda function

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0" # Or your preferred version
    }
  }
}

provider "aws" {
  region = "your-aws-region"  # Replace with your desired region
}



# S3 Bucket
resource "aws_s3_bucket" "data_bucket" {
  bucket = "your-bucket-name" # Replace with a globally unique name
  acl    = "private" # Recommended for security

  force_destroy = true # Use with caution!  Allows Terraform to delete the bucket even if it's not empty during destroy.
}




# SQS Queue
resource "aws_sqs_queue" "data_queue" {
  name = "your-queue-name" # Replace with your queue name
}


# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_sqs_s3_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda (access to SQS and S3)
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_sqs_s3_policy"
  description = "Policy for SQS to S3 Lambda function"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject", # Optional, if your Lambda needs to read from S3 as well
          "s3:ListBucket", # Optional, if needed
        ],
        Resource = [
          aws_s3_bucket.data_bucket.arn,
          "${aws_s3_bucket.data_bucket.arn}/*",  # Important: Allows access to all objects in the bucket
        ]

      },

      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
        ],
        Resource = aws_sqs_queue.data_queue.arn
      },
      {
        Effect    = "Allow",
        Action   = "logs:CreateLogGroup",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect    = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/*"
      }
    ]
  })


}



# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda Function
resource "aws_lambda_function" "process_sqs_messages" {
  function_name = "process_sqs_messages"  # Or your preferred function name
  s3_bucket     = "your-s3-bucket-for-deployment" # Bucket where your zipped code is
  s3_key        = "lambda_function.zip"  # Zip file name
  runtime       = "python3.9"  # Or your preferred runtime
  handler       = "lambda_function.lambda_handler"  # Entry point
  role          = aws_iam_role.lambda_role.arn


  environment {
    variables = {
      SQS_QUEUE_URL    = aws_sqs_queue.data_queue.url
      S3_BUCKET_NAME = aws_s3_bucket.data_bucket.bucket
    }
  }


}

# Event trigger for Lambda from SQS
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.data_queue.arn
  function_name    = aws_lambda_function.process_sqs_messages.arn
  batch_size = 10 # Process up to 10 messages at a time (optional)

}