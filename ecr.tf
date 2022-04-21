// ECS is a scalable container orchestration service that allows to run and scale 
//dockerized applications on AWS.
resource "aws_ecr_repository" "worker" {
    name  = "worker"
}

resource "aws_ecs_cluster" "ecs_cluster" {
    name  = "my-cluster"
}