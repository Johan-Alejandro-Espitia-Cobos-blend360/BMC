# Application Load Balancer, Target Group y Listener HTTP 80. Equivalente a
# LoadBalancer/TargetGroup/Listener en cloudformation/langflow-ecs.yaml.

resource "aws_lb" "this" {
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id,
  ]
}

resource "aws_lb_target_group" "langflow" {
  vpc_id      = aws_vpc.this.id
  port        = 7860
  protocol    = "HTTP"
  target_type = "ip"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  deregistration_delay = 30
}

resource "aws_lb_listener" "langflow" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.langflow.arn
  }
}
