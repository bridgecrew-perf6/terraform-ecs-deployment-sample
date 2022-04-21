// Having this prepared we can create terraform resource for the task definition:
resource "aws_ecs_task_definition" "task_definition" {
  family                = "worker"
  container_definitions = data.template_file.task_definition_template.rendered
}

//The last thing that will bind the cluster with the task is a ECS service. 
// The service will guarantee that we always have some number of tasks running all the time:
resource "aws_ecs_service" "worker" {
  name            = "worker"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.task_definition.arn
  desired_count   = 2
}