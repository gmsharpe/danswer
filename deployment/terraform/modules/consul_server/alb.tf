data "aws_lb" "this" {
  count = var.lb_enabled ? 1 : 0
  arn = var.lb_arn
}

resource "aws_lb_target_group" "this" {
  count                = var.lb_enabled ? 1 : 0
  name                 = var.name
  port                 = 8500
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 10
  health_check {
    path                = "/v1/status/leader"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 30
    interval            = 60
  }
}

resource "aws_lb_listener" "this" {
  count             = var.lb_enabled ? 1 : 0
  load_balancer_arn = data.aws_lb.this[count.index].arn
  port              = "8500"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[count.index].arn
  }
}


resource "aws_security_group" "load_balancer" {
  count  = var.lb_enabled ? 1 : 0
  name   = "${var.name}-lb-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "Access to Consul dev server HTTP API and UI."
    from_port       = 8500
    to_port         = 8500
    protocol        = "tcp"
    cidr_blocks     = var.lb_ingress_rule_cidr_blocks
    security_groups = var.lb_ingress_rule_security_groups
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group_rule" "lb_ingress_to_service" {
  count = var.lb_enabled ? 1 : 0

  description              = "Access to Consul dev server from security group attached to load balancer"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.load_balancer[0].id
  security_group_id        = var.ecs_service_sg_id
}


# resource "aws_security_group_rule" "egress_from_service" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = var.ecs_service_sg_id
# }

resource "null_resource" "wait_for_consul_server" {
  count = var.lb_enabled ? 1 : 0
  triggers = {
    // Trigger update when Consul server ALB DNS name changes.
    consul_server_lb_dns_name = "${data.aws_lb.this[0].dns_name}"
  }
  provisioner "local-exec" {
    command = <<EOT
stopTime=$(($(date +%s) + ${var.consul_server_startup_timeout})) ; \
while [ $(date +%s) -lt $stopTime ] ; do \
  sleep 10 ; \
  statusCode=$(curl -s -o /dev/null -w '%%{http_code}' http://${data.aws_lb.this[0].dns_name}:8500/v1/catalog/services)
  [ $statusCode -eq 200 ] && break; \
done
EOT
  }
}
