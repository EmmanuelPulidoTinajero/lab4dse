resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "direct" {
  name        = "${var.project_name}-tg-direct"
  target_type = "lambda"

  health_check {
    enabled  = true
    path     = "/direct/health"
    interval = 35
    timeout  = 30
    matcher  = "200"
  }
}

resource "aws_lb_target_group_attachment" "direct" {
  target_group_arn = aws_lb_target_group.direct.arn
  target_id        = aws_lambda_alias.direct_live.arn

  depends_on = [aws_lambda_permission.direct_alb]
}

resource "aws_lb_target_group" "cached" {
  name        = "${var.project_name}-tg-cached"
  target_type = "lambda"

  health_check {
    enabled  = true
    path     = "/cached/health"
    interval = 35
    timeout  = 30
    matcher  = "200"
  }
}

resource "aws_lb_target_group_attachment" "cached" {
  target_group_arn = aws_lb_target_group.cached.arn
  target_id        = aws_lambda_alias.cached_live.arn

  depends_on = [aws_lambda_permission.cached_alb]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found. Use /direct/item or /cached/item"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "direct" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.direct.arn
  }

  condition {
    path_pattern {
      values = ["/direct*"]
    }
  }
}

resource "aws_lb_listener_rule" "cached" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cached.arn
  }

  condition {
    path_pattern {
      values = ["/cached*"]
    }
  }
}
