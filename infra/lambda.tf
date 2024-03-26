resource "aws_iam_role" "lambda_execution_role" {
  name = "ecs_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "ecs_lambda_policy"
  description = "IAM policy for ECS Lambda to update service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:UpdateService",
        ]
        Resource = "*"
        Effect   = "Allow"
      },
      {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "ecs_updater" {
  function_name    = "ECSUpdater"
  filename         = "../lambda/lambda.zip"
  source_code_hash = filebase64sha256("../lambda/lambda.zip")
  handler          = "index.handler"
  role             = aws_iam_role.lambda_execution_role.arn
  runtime          = "nodejs20.x"

  environment {
    variables = {
      CLUSTER_NAME = "my-ecs-cluster"
      SERVICE_NAME = "minecraft-ondemand-terraform"
    }
  }
}

resource "aws_api_gateway_rest_api" "ecs_api" {
  name = "ECSUpdaterAPI"
}

resource "aws_api_gateway_resource" "ecs_resource" {
  rest_api_id = aws_api_gateway_rest_api.ecs_api.id
  parent_id   = aws_api_gateway_rest_api.ecs_api.root_resource_id
  path_part   = "interactions"
}

resource "aws_api_gateway_method" "ecs_post" {
  rest_api_id   = aws_api_gateway_rest_api.ecs_api.id
  resource_id   = aws_api_gateway_resource.ecs_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.ecs_api.id
  resource_id = aws_api_gateway_resource.ecs_resource.id
  http_method = aws_api_gateway_method.ecs_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ecs_updater.invoke_arn
}

resource "aws_api_gateway_deployment" "ecs_deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration]

  rest_api_id = aws_api_gateway_rest_api.ecs_api.id
  stage_name  = "discord"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecs_updater.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.ecs_api.execution_arn}/*/*"
}

output "api_gateway_invoke_url" {
  value = aws_api_gateway_deployment.ecs_deployment.invoke_url
}