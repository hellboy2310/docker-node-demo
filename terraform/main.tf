terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "demo_server" {
  ami           = "ami-0f58b397bc5c1f2e8"
  instance_type = "t2.micro"

  tags = {
    Name = "terraform-demo"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "docker-node-demo-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "demo" {
  filename         = "../lambda/function.zip"
  function_name    = "docker-node-demo"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.handler"
  runtime          = "nodejs20.x"
  source_code_hash = filebase64sha256("../lambda/function.zip")
}
