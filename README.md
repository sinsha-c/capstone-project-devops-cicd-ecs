# DevOps Capstone --- Terraform + Ansible + Jenkins + ECS Fargate

A practical AWS DevOps capstone demonstrating **Infrastructure as Code,
configuration management, CI/CD, container security, monitoring, and
application deployment**.

The architecture separates responsibilities clearly:

  Tool                     Responsibility
  ------------------------ ------------------------------------------------
  **Terraform**            AWS infrastructure provisioning
  **Ansible**              Software installation and server configuration
  **Jenkins**              Pipeline orchestration
  **Docker**               Application containerization
  **Trivy**                Filesystem/container security scanning
  **SonarQube**            Code quality analysis
  **Prometheus**           Metrics collection
  **Grafana**              Monitoring dashboards
  **Amazon ECR**           Container image registry
  **Amazon ECS Fargate**   Application runtime
  **Amazon S3**            Terraform remote state

> **Architecture decision:** For the learning capstone, use one manually
> bootstrapped DevOps EC2 instance. Keep Jenkins itself outside the
> Terraform-managed infrastructure initially, so Jenkins does not try to
> recreate the machine on which it is running.

------------------------------------------------------------------------

## 1. Final Architecture

``` text
                                  GITHUB
                                     |
                     +---------------+---------------+
                     |                               |
                     v                               v
          INFRASTRUCTURE PIPELINE          APPLICATION PIPELINE
                     |                               |
                     v                               v
                 TERRAFORM                         JENKINS
                     |                               |
                     v                    +----------+----------+
              AWS INFRASTRUCTURE          |          |          |
                     |                  SonarQube  Docker     Trivy
                     |                               |
                     |                               v
                     |                              ECR
                     |                               |
                     v                               v
              +-------------+                    ECS/Fargate
              |     VPC     |                       |
              |             |                       |
              | Public      |                       |
              | Subnets     |                       |
              |   ALB       |                       |
              |             |                       |
              | Private     |                       |
              | Subnets     |                       |
              |   ECS       |                       |
              +-------------+                       |
                                                    |
                                                    v
                                             Web Application


                    DEVOPS EC2
                 Ubuntu / t3.large
                       |
       +---------------+----------------+
       |               |                |
     Jenkins        Terraform         Ansible
       |                                |
       |                    +-----------+-----------+
       |                    |           |           |
       |                SonarQube   Prometheus   Grafana
       |                                |
       |                                v
       |                           Monitoring
       |
       +---- Docker / Trivy / AWS CLI


                         S3
                          |
                          v
                  Terraform State
```

### Traffic flow

``` text
Internet
   |
   v
ALB
(Public Subnet)
   |
   | HTTP/HTTPS
   v
ECS Fargate
(Private Subnet)
   |
   v
Application
```

The ECS security group allows application traffic **from the ALB
security group**, rather than allowing the entire internet to reach the
ECS tasks directly.

------------------------------------------------------------------------
