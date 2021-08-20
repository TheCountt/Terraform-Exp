output "public_ip" {
    value = aws_instance.example.public_ip
    description = "public IP address of web server" 
}

output "alb_dns_name" {
    value = aws_lb.example.dns_name
    description = "the domain name of the load balancer"
}

output "asg_name" {
  value = aws_autoscaling_group.example.name
  description = "The name of the AutoScaling Group"
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
  description = "The ID of the Security Group attached to the load balancer"
}