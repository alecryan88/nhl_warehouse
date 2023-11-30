resource "aws_s3_bucket" "bucket" {
  bucket        = local.project_name
  force_destroy = true
}

resource "aws_iam_role" "snowflake_acccess_role" {
  name               = "${var.environment}-${local.config.project_name}-snowflake-access-role"
  assume_role_policy = data.aws_iam_policy_document.snowflake_assume_role_policy.json

  inline_policy {
    name   = "${var.environment}-${local.config.project_name}-snowflake_s3_access_policy"
    policy = data.aws_iam_policy_document.s3_inline_acces_policy.json
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  queue {
    queue_arn = snowflake_pipe.pipe.notification_channel
    #When object is created in S3 bucket => send notification to queue
    events = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    #Requires a bucket to configure the notification
    aws_s3_bucket.bucket,
    #Requires an exisiting pipe to get the SQS notification channel
    snowflake_pipe.pipe
  ]
}

resource "aws_iam_policy" "lambda_s3" {
  name        = "${var.environment}-${local.project_name}-lambda-s3-permissions"
  description = "Policy for lambda function to put objects to the necessary bucket."
  policy      = data.aws_iam_policy_document.lambda_s3.json
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "${var.environment}-${local.config.project_name}-role-for-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_execution_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_s3.arn
}

// Create the "cron" schedule
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = local.project_name
  schedule_expression = local.schedule
}

// Set the action to perform when the event is triggered
resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule = aws_cloudwatch_event_rule.schedule.name
  arn  = aws_lambda_function.loader_lambda.arn
}

// 
resource "aws_lambda_function" "loader_lambda" {
    function_name    = local.project_name
    role             = aws_iam_role.iam_for_lambda.arn
    package_type     = "Zip"
    runtime          = local.lambda_runtime
    handler          = "app.handler"
    filename         = data.archive_file.zip.output_path
    timeout          = 60
    source_code_hash = data.archive_file.zip.output_sha
    environment {
      variables = {
        "S3_BUCKET_NAME" : aws_s3_bucket.bucket.id
      }
    }
  depends_on = [
    #Requires a zip file with app code/dependencies before function can be created
    data.archive_file.zip,
    aws_iam_role_policy_attachment.lambda_s3,
    aws_iam_role.iam_for_lambda,
    #Neeed to copy add code into env so that lambda can run
    null_resource.copy_app_code
  ]

}

// Allow CloudWatch to invoke our function
resource "aws_lambda_permission" "allow_cloudwatch_to_invoke" {
  function_name = aws_lambda_function.loader_lambda.id
  statement_id  = "CloudWatchInvoke"
  action        = "lambda:InvokeFunction"

  source_arn = aws_cloudwatch_event_rule.schedule.arn
  principal  = "events.amazonaws.com"
}


resource "null_resource" "copy_app_code" {
  triggers = {
    code_change = "${sha1(file("../app.py"))}"
  }

  provisioner "local-exec" {
    command = "cp ../app.py ../venv/lib/${local.lambda_runtime}/site-packages"
  }

}

resource "null_resource" "copy_requirements" {
  triggers = {
    code_change = "${sha1(file("../requirements.txt"))}"
  }

  provisioner "local-exec" {
    command = "cp ../app.py ../venv/lib/${local.lambda_runtime}/site-packages"
  }

}