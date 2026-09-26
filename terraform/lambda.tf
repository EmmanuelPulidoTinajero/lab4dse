locals {
  lambda_common_env = {
    DB_HOST     = aws_db_instance.postgres.address
    DB_PORT     = tostring(aws_db_instance.postgres.port)
    DB_NAME     = var.db_name
    DB_USER     = var.db_username
    DB_PASSWORD = var.db_password
    REDIS_HOST  = aws_elasticache_cluster.redis.cache_nodes[0].address
    REDIS_PORT  = tostring(aws_elasticache_cluster.redis.cache_nodes[0].port)
    REDIS_TTL   = tostring(var.redis_ttl_seconds)
  }
}

# --- direct lambda (RDS only) ---
resource "null_resource" "npm_install_direct" {
  triggers = {
    package_json = filemd5("${path.module}/../lambda/direct/package.json")
    index_js     = filemd5("${path.module}/../lambda/direct/index.js")
  }

  provisioner "local-exec" {
    command     = "npm install --omit=dev"
    working_dir = "${path.module}/../lambda/direct"
  }
}

data "archive_file" "direct" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/direct"
  output_path = "${path.module}/../lambda/direct.zip"
  excludes    = ["dist.zip"]

  depends_on = [null_resource.npm_install_direct]
}

resource "aws_lambda_function" "direct" {
  function_name    = "${var.project_name}-direct"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 10
  memory_size      = 256
  filename         = data.archive_file.direct.output_path
  source_code_hash = data.archive_file.direct.output_base64sha256
  publish          = true

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = local.lambda_common_env
  }
}

resource "aws_lambda_alias" "direct_live" {
  name             = "live"
  function_name    = aws_lambda_function.direct.function_name
  function_version = aws_lambda_function.direct.version
}

resource "aws_lambda_permission" "direct_alb" {
  statement_id  = "AllowALBInvokeDirect"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_alias.direct_live.function_name
  qualifier     = aws_lambda_alias.direct_live.name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.direct.arn
}

# --- cached lambda (ElastiCache + RDS, cache-aside) ---
resource "null_resource" "npm_install_cached" {
  triggers = {
    package_json = filemd5("${path.module}/../lambda/cached/package.json")
    index_js     = filemd5("${path.module}/../lambda/cached/index.js")
  }

  provisioner "local-exec" {
    command     = "npm install --omit=dev"
    working_dir = "${path.module}/../lambda/cached"
  }
}

data "archive_file" "cached" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/cached"
  output_path = "${path.module}/../lambda/cached.zip"
  excludes    = ["dist.zip"]

  depends_on = [null_resource.npm_install_cached]
}

resource "aws_lambda_function" "cached" {
  function_name    = "${var.project_name}-cached"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 10
  memory_size      = 256
  filename         = data.archive_file.cached.output_path
  source_code_hash = data.archive_file.cached.output_base64sha256
  publish          = true

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = local.lambda_common_env
  }
}

resource "aws_lambda_alias" "cached_live" {
  name             = "live"
  function_name    = aws_lambda_function.cached.function_name
  function_version = aws_lambda_function.cached.version
}

resource "aws_lambda_permission" "cached_alb" {
  statement_id  = "AllowALBInvokeCached"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_alias.cached_live.function_name
  qualifier     = aws_lambda_alias.cached_live.name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.cached.arn
}

# --- one-shot DB init lambda (creates table + seed rows) ---
resource "null_resource" "npm_install_db_init" {
  triggers = {
    package_json = filemd5("${path.module}/../lambda/db-init/package.json")
    index_js     = filemd5("${path.module}/../lambda/db-init/index.js")
  }

  provisioner "local-exec" {
    command     = "npm install --omit=dev"
    working_dir = "${path.module}/../lambda/db-init"
  }
}

data "archive_file" "db_init" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/db-init"
  output_path = "${path.module}/../lambda/db-init.zip"
  excludes    = ["dist.zip"]

  depends_on = [null_resource.npm_install_db_init]
}

resource "aws_lambda_function" "db_init" {
  function_name    = "${var.project_name}-db-init"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 120
  memory_size      = 256
  filename         = data.archive_file.db_init.output_path
  source_code_hash = data.archive_file.db_init.output_base64sha256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_HOST     = aws_db_instance.postgres.address
      DB_PORT     = tostring(aws_db_instance.postgres.port)
      DB_NAME     = var.db_name
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password
    }
  }
}

resource "aws_lambda_invocation" "db_init" {
  function_name = aws_lambda_function.db_init.function_name
  input          = jsonencode({ action = "init" })

  depends_on = [aws_db_instance.postgres, aws_lambda_function.db_init]
}
