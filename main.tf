provider "aws"{
    profile = "default"
    region = "us-east-1"
}

resource "aws_s3_bucket" "source-bucket" {
    bucket = "dmytrolab8"
    acl = "public-read"

    tags = {
      Name = "dmytrolab8"
    }
}

resource "aws_s3_bucket" "target-bucket" {
    bucket = "dmytrolab8-resized"
    acl = "public-read"
    tags = {
      Name = "dmytrolab8-resized"
    }
}

resource "aws_iam_policy" "policy" {
  name = "policy"
  path = "/"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:PutLogEvents",
                "logs:CreateLogGroup",
                "logs:CreateLogStream"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::dmytrolab8/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::dmytrolab8-resized/*"
        }
    ]
}
  EOF
}

resource "aws_iam_role" "role" {
  name = "role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    },
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
  EOF
}

resource "aws_iam_role_policy_attachment" "name" {
  role = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_lambda_function" "lambda" {
  function_name = "lambda"
  role = aws_iam_role.role.arn
  handler = "index.handler"
  timeout = 10
  memory_size = 1024

  filename = "function.zip"
  source_code_hash = filebase64sha256("function.zip")

  runtime = "nodejs12.x"
}

# assign lambda to s3 bucket action of creation
resource "aws_lambda_permission" "bucket_permission" {
  statement_id = "AllowExecutionFromS3Bucket"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.source-bucket.arn
}

resource "aws_s3_bucket_notification" "name" {
  bucket = aws_s3_bucket.source-bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda.arn
    events = ["s3:ObjectCreated:*"]
  }

  depends_on = [ aws_lambda_permission.bucket_permission ]
}
