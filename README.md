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

## 2. What Terraform Creates

Terraform provisions the AWS foundation:

``` text
Terraform
|
+-- VPC
|   +-- Public Subnets
|   +-- Private Subnets
|   +-- Internet Gateway
|   +-- Route Tables
|
+-- Security Groups
|   +-- ALB SG
|   +-- ECS SG
|
+-- ECR
|   +-- capstone-devops-app
|
+-- ECS
|   +-- ECS Cluster
|   +-- Task Definition
|   +-- ECS Service
|
+-- ALB
|   +-- Load Balancer
|   +-- Target Group
|   +-- Listener
|
+-- IAM
|   +-- ECS Task Execution Role
|   +-- ECS Task Role
|
+-- CloudWatch
|   +-- ECS application logs
|
+-- S3
    +-- terraform.tfstate
```

The exact ECS deployment resources can vary depending on whether the
project uses a simpler rolling deployment or a Blue/Green CodeDeploy
architecture.

------------------------------------------------------------------------

# 3. Bootstrap the DevOps EC2

## 3.1 Launch the EC2 manually

The first machine is intentionally bootstrapped manually.

  Setting     Recommendation
  ----------- -------------------------
  OS          Ubuntu 24.04 LTS
  Instance    t3.large
  vCPU        2
  RAM         8 GiB
  Storage     30 GB gp3
  Region      ap-south-1
  Public IP   Yes
  IAM Role    Yes
  Purpose     Jenkins / DevOps server

The t3.large recommendation provides more headroom because Jenkins,
SonarQube, Prometheus, Grafana, Docker, Terraform, Ansible and Trivy may
run on the same machine.

<img src="screenshots/01-launch-cicd-devops-server.png" alt="Launch DevOps EC2 instance">

## 4. Create the DevOps EC2 Security Group

Create:

``` text
devops-ci-cd-sg
```

Recommended inbound rules:

    Port Service     Source
  ------ ----------- --------------
      22 SSH         Your IP only
    8080 Jenkins     Your IP only
    9000 SonarQube   Your IP only
    3000 Grafana     Your IP only

Avoid exposing these management ports to:

``` text
0.0.0.0/0
```

unless there is a specific reason.

<img src="screenshots/02-devops-security-group.png" alt="DevOps EC2 security group">


------------------------------------------------------------------------

## 5. Attach an IAM Role to the DevOps EC2

Create an EC2 IAM role, for example:

``` text
DevOpsEC2Role
```

Jenkins and Terraform will use the EC2 instance profile to communicate
with AWS.

The architecture is:

``` text
Jenkins
   |
   v
EC2 Instance Profile
   |
   v
IAM Role
   |
   v
AWS APIs
```

Do **not** place long-lived AWS access keys inside the Jenkinsfile.

For the learning environment, the role can initially have sufficient
permissions for the Terraform-managed resources. The permissions should
be tightened later according to least-privilege requirements.


# 6. Connect to the EC2

``` bash
ssh -i your-key.pem ubuntu@YOUR_EC2_PUBLIC_IP
```

Update the server:

``` bash
sudo apt update
sudo apt upgrade -y
```

### 7. Install Docker

``` bash
sudo apt install -y docker.io
```

Enable Docker:

``` bash
sudo systemctl enable --now docker
```

Add the Ubuntu user to the Docker group:

``` bash
sudo usermod -aG docker ubuntu
```

Later, Jenkins will also be added to the Docker group.

Verify:

``` bash
docker --version
```

# 8. Install AWS CLI

Check whether AWS CLI already exists:

``` bash
aws --version
```

If necessary:

``` bash
sudo apt install -y awscli
```

Verify the EC2 IAM role:

``` bash
aws sts get-caller-identity
```

This should return information associated with the EC2 instance role.

# 9. Install Terraform

Install the required packages:

``` bash
sudo apt update
sudo apt install -y gnupg software-properties-common curl
```

Add the HashiCorp repository:

``` bash
wget -O- https://apt.releases.hashicorp.com/gpg \
| gpg --dearmor \
| sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
```

``` bash
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
| sudo tee /etc/apt/sources.list.d/hashicorp.list
```

Install Terraform:

``` bash
sudo apt update
sudo apt install -y terraform
```

Verify:

``` bash
terraform version
```

# 10. Install Jenkins

Installation steps should refer from `https://www.jenkins.io/doc/book/installing/linux/`

Install Java:

``` bash
sudo apt install -y fontconfig openjdk-21-jre
```

Install Jenkins using the current Jenkins repository instructions.

Enable and start Jenkins:

``` bash
sudo systemctl enable jenkins
sudo systemctl start jenkins
```

Check status:

``` bash
sudo systemctl status jenkins
```

Open:

``` text
http://EC2_PUBLIC_IP:8080
```

Retrieve the initial administrator password:

``` bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

# 11. Give Jenkins Docker Access

Jenkins needs Docker access for:

``` text
docker build
docker push
```

Add Jenkins to the Docker group:

``` bash
sudo usermod -aG docker jenkins
```

Restart Jenkins:

``` bash
sudo systemctl restart jenkins
```


# 13. Install Ansible

Ansible is responsible for installing and configuring software on the
DevOps server.

Install:

``` bash
sudo apt update
sudo apt install -y ansible
```

Verify:

``` bash
ansible --version
```

Test local Ansible:

``` bash
ansible localhost -m ping -c local
```

Expected result:

``` text
localhost | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

**Verfy all the versions installed above**
<img src="screenshots/03-pre-installation-versions.png" alt="all packages versions">


# 16. Create the Ansible Inventory

Create:

``` text
ansible/inventory.ini
```

Contents:

``` ini
[devops]
localhost ansible_connection=local
```

> If you running the ansible for the remote server or If you later use a separate monitoring EC2, configure inventory as below and control node ssh key should be added in managed nodes.

```ini
[devops]
monitoring ansible_host=<MONITORING_EC2_IP> ansible_user=ubuntu
```

Test:

``` bash
cd ansible
ansible all -i inventory.ini -m ping
```

Expected:

``` text
localhost | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

# 17. Create the Main Ansible Playbook

Create:

``` text
ansible/site.yml
```

``` yaml
---
- name: Configure DevOps Server
  hosts: devops
  become: true

  roles:
    - trivy
    - sonarqube
    - node_exporter
    - prometheus
    - grafana
```

> This makes the main playbook responsible for calling the all the roles.

### Run the complete playbook

Before running everything, check the syntax:

```bash
cd ~/ansible

ansible-playbook -i inventory.ini site.yml --syntax-check
```

Then:
```bash
ansible-playbook -i inventory.ini site.yml --check
```
Finally:
```bash
ansible-playbook -i inventory.ini site.yml
```

<img src="screenshots/04-ansible-playbook-output" >


The desired result is:

``` text
Ansible
   |
   +-- Install Prometheus
   +-- Configure Prometheus
   +-- Install Grafana
   +-- Configure Grafana
   +-- Add Prometheus datasource
   +-- Provision dashboards
```

This avoids requiring manual configuration through the Grafana UI after
every server rebuild.

### Verification

**Versions and service status**
<img src="screenshots/05-monitoring-tool-verify.png" alt="docker,trivy">

<img src="screenshots/05-monitoring-tool-verify2.png" alt="service running">

**SonarQube Dashboard**
- Login with default username/password(admin/admin) and update new password

<img src="screenshots/06-sonarqube-dashboard.png" alt="sonarqube monitoring dashboard">

**Prometheus Dashboard**

<img src="screenshots/07-prometheus-dashboard.png" alt="prometheous monitoring dashboard">

**Grafana Dashboard**
- Login with default username/password(admin/admin) and update new password

<img src="screenshots/08-grafana-dashboard.png" alt="Grafana monitoring dashboard">

## Monitoring Tools Configuration 

### SonarQube — configure
1. Login to SonarQube dashboard  → My Account → Security → Generate Token screen.
2. No expiration is acceptable because this is a dedicated token that Jenkins will use for the project.
3. After clicking Generate, SonarQube will show the token once.
4. Copy it immediately and store it in Jenkins as a `Secret text` credential 
5. Configure git credential also in jenkins as `Username and Password`
6. → Manage Jenkins→ Credentials → System → Global credentials → Add Credentials
> Do not put the token in your GitHub repository, Jenkinsfile, Terraform files, or screenshots.

<img src="screenshots/11-configure-jenkins-secrets.png" alt="Grafana monitoring dashboard">

7. Configure SonarQube server in Jenkins Manage Jenkins → System → SonarQube servers 

```text
Name:
SonarQube

Server URL:
http://localhost:9000
```
Since SonarQube and Jenkins are on the same EC2, localhost is appropriate for Jenkins-to-SonarQube communication.
8. Select the credential: sonarqube-token
9. Configure jenkins webhook in Sonarqube. This allows SonarQube to tell Jenkins Quality Gate = PASSED/FAILED.
10. In SonarQube, go to: Administration → Configuration → Webhooks → Create then enter the webhook details:

``` text
Name: Jenkins

URL: 
http://<JENKINS_PRIVATE_IP>:8080/sonarqube-webhook/

Secret:
Leave empty
```

11. Go to: Jenkins → Manage Jenkins → Tools
Look for SonarQube Scanner installations
12. Click: Add SonarQube Scanner
Enter Name:sonar-scanner

<img src="screenshots/sonarqube-webhook.png" width="100%">

### Node Exporter — configure
1. Check:

```bash
sudo systemctl status node_exporter
```
2. Then:
```bash
curl http://localhost:9100/metrics
```
3. You should see metrics such as:

```bash
node_cpu_seconds_total
node_memory_MemAvailable_bytes
node_filesystem_avail_bytes
node_load1
```
4. Make sure it starts automatically:
```bash
sudo systemctl enable node_exporter
```
### Prometheus — configureOpen:

1. Open `http://DEVOPS-EC2-IP:9090`
2. Go to: Status → Targets
3. You want:
```text
prometheus    UP
node          UP
```
4. The important one is: node → localhost:9100 → UP

<img src="screenshots/11-prometheus-verify.png" width="100%">

### Grafana — configure

1. Open: `http://DEVOPS-EC2-IP:3000` then add Prometheus datasource
2. Go to: Connections → Data sources → Add data source → Prometheus
3. Add URL: `http://localhost:9090` 
4. Click: `Save & test` You should get a successful connection.
5. Create/import a Node Exporter dashboard.
6. Here i have imported dashboard from json file

At minimum, you want to see:

CPU
Memory
Disk
Network
Load
Filesystem

<img src="screenshots/12-grafana-dashboard.png" width="100%">

#### Configure Alert from grafana
1. Go to: Alerting → Contact points, Create a contact point, for example:

```text
Name: Email Notifications
Type: Email
Address: your-email@example.com
```

2. Then configure your SMTP settings in Grafana /etc/grafana/grafana.ini under smtp section
3. Create an alert rule from the panel. In the panel editor, go to the Alert section, Alert rules → Create alert rule Click it.
4. Configure the CPU condition Rule name: High CPU Usage
5. Then create the condition: `WHEN A IS ABOVE 80`
6. Set: Evaluate every: 1m For: 5m

Meaning:

CPU = 85%
   ↓
Check every minute
   ↓
Still > 80%
   ↓
after 5 minutes
   ↓
ALERT

This prevents a brief CPU spike from immediately sending an email.

7. Configure the notification select Contact points configured already.
8. Repeat the same step for other panels too

<img src="screenshots/14-alert-rule-grafana.png" width="100%">

**Email fired for High Memory Usage**

<img src="screenshots/13-email-alert-high-memory.png" width="100%">

---

# Move Ansible playbooks to Jenkins

After Terraform infrastructure provisioning, Jenkins can run Ansible.

``` groovy

pipeline {

    agent any

    parameters {
        string(name: 'SERVER_IP', defaultValue: '', description: 'Target server IP for Ansible inventory')
        string(name: 'SERVER_USER', defaultValue: 'ec2-user', description: 'SSH user for the target server')
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/sinsha-c/capstone-project-devops-cicd-ecs.git'
            }
        }

        stage('Validate Input') {
            steps {
                script {
                    if (params.SERVER_IP == null || params.SERVER_IP.trim().isEmpty()) {
                        error("Build failed: SERVER_IP is required and cannot be null or empty.")
                    }
                    if (params.SERVER_USER == null || params.SERVER_USER.trim().isEmpty()) {
                        error("Build failed: SERVER_USER is required and cannot be null or empty.")
                    }
                }
            }
        }

        stage('Generate Inventory') {
            steps {
                sh '''
                    cd ansible
                    cat > inventory.ini <<EOF
[devops_server]
${SERVER_IP} ansible_user=${SERVER_USER} ansible_ssh_private_key_file=/path/to/key.pem
EOF
                    cat inventory.ini
                    '''
            }
        }

        stage('Configure DevOps Server') {
            steps {
                sh '''
                    cd ansible
                    ansible-playbook -i inventory.ini site.yml
                    '''
            }
        }
    }
}
```

<img src="screenshots/10-ansible-in-jenkins.png" alt="ansible task">

# 23. Terraform Infrastructure Pipeline

The infrastructure pipeline is responsible for provisioning AWS
resources.

``` text
GitHub
   |
   v
Jenkins
   |
   v
infra-Jenkinsfile
   |
   +-- terraform init
   +-- terraform fmt
   +-- terraform validate
   +-- terraform plan
   +-- terraform apply
   |
   v
AWS Infrastructure
```

- let's create terraform-infrastructure job in Jenkins with pipeline script below:
- Make sure you have configured git credentails in jenkins

### Create a jenkins job with below infra pipeline

``` groovy
pipeline {

    agent any

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/sinsha-c/capstone-project-devops-cicd-ecs.git'
            }
        }

        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    sh 'terraform validate'
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    sh 'terraform plan'
                }
            }
        }
        stage('Terraform Apply') {
            steps {

                input message: 'Apply Terraform infrastructure?'

                dir('terraform') {
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }
}
```
- Job name : terraform-infrastructur
- Test Infra pipeline with plan then add apply in the pipeline code
- Approve the job to proceed on apply

<img src="screenshots/09-infra-pipeline-approve.png" alt="Terraform Jenkins pipeline">

- Jenkins will show pipeline stage view as below:

<img src="screenshots/09-infra-pipeline-stage.png" alt="Terraform Jenkins pipeline">

- All infra has been launched with output

<img src="screenshots/09-infra-pipeline-apply-success.png" alt="Terraform Jenkins pipeline">

- verify terraform state has been saved in sinsha-capstone-devops-tfstate?

<img src="screenshots/10-terraform-backend.png" alt="Terraform state in s3">


### AWS Network Architecture

Terraform creates the VPC and networking foundation.

Example:

VPC: 10.0.0.0/16

The VPC provides the network boundary and routing.


### Security Group Architecture

#### ALB Security Group

The ALB is the public entry point.

Example inbound rules:

``` text
80  <- 0.0.0.0/0
```

#### ECS Security Group

ECS should not accept application traffic directly from the entire
internet.

This is an important security design principle: application tasks accept
traffic from the load balancer rather than directly from the internet.


## ECS/Fargate Application Deployment

Terraform creates:

``` text
ECS Cluster
Task Definition
ECS Service
```

The ECS tasks run in private subnets behind the ALB.


<img src="screenshots/ecs-service-running.png" alt="ECS service and running tasks">

### ECR

Terraform creates the ECR repository:

The application pipeline pushes the Docker image:

<img src="screenshots/ecr-repo.png" alt="Amazon ECR application image">

---

# Application Pipeline

```text
Application Pipeline
       |
       +--> Build application
       +--> Build Docker image
       +--> Scan image
       +--> Push image → existing ECR
       +--> Update existing ECS service
```
## Create a Jenkins Pipeline Job
1. Login to jenkins and create a pipeline job with `GitHub hook trigger for GITScm polling` enabled
2. Job name : `DevOps-application-pipeline`
3. Choose pipeline script from SCM with mentioned Jenkinsfile
4. Configure aws region in jenkins environment variables.
5. Job will build when github gets the new commit.

**Application pipeline job successs**

<img src="screenshots/application-pipeline-stage-view.png">

**Jenkins job success**
<img src="screenshots/app-jenkins-job-success.png">

# Final Validation

1. Open the DNS name from the browser and check your application works

<img src="screenshots/final-output.png">

2. Trivy scan result with no vulnerabilities

<img src="screenshots/trivy-scan-no-vulnerabilities.png">

3. Verify ECS tasks and ECS fargate is in private network

<img src="screenshots/ecs-tasks.png">

<img src="screenshots/ecs-fargate-in-private-nw.png">

4. Verify ECR image

<img src="screenshots/ecr-repo-images.png">

5. SonarQube Passsed

<img src="screenshots/sonarqube-final-pass.png">

6. Make code changes in the application in git. Once the Jenkins build success and verify the application running with latest changes.

<img src="screenshots/final-output2.png">

7. Cloudwatch Alarm

<img src="screenshots/cloudwatch-alarm-configured-terraform.png">

# 32. Final Responsibility Matrix

  Tool              Responsibility
  ----------------- -------------------------------------
  Terraform         AWS infrastructure
  Ansible           Software installation/configuration
  Jenkins           Pipeline orchestration
  Docker            Containerization
  Trivy             Security scanning
  SonarQube         Code quality analysis
  Prometheus        Metrics collection
  Grafana           Monitoring dashboards
  ECR               Docker image registry
  ECS Fargate       Application runtime
  ALB               Public application entry point
  VPC               AWS network boundary
  Security Groups   Network access control
  CloudWatch        AWS/application logs and metrics
  S3                Terraform state

---

# 35. Important Architecture Decision

The initial bootstrap machine is intentionally manual:

``` text
MANUAL BOOTSTRAP
        |
        v
DevOps EC2
        |
        +-- Jenkins
        +-- Terraform
        +-- Ansible
        +-- AWS CLI
        |
        v
AUTOMATION
        |
        +-- Terraform -> AWS infrastructure
        |
        +-- Ansible -> Software configuration
        |
        +-- Jenkins -> Pipeline orchestration
```


# 37. Implementation Order

Follow this order when building the capstone:

### Phase 1 --- Bootstrap

-   [ ] Launch DevOps EC2
-   [ ] Configure Security Group
-   [ ] Attach IAM role
-   [ ] SSH into EC2

### Phase 2 --- DevOps tools

-   [ ] Install Docker
-   [ ] Install AWS CLI
-   [ ] Install Terraform
-   [ ] Install Jenkins
-   [ ] Give Jenkins Docker access
-   [ ] Install Trivy
-   [ ] Install Ansible

### Phase 3 --- Ansible

-   [ ] Create Ansible directory
-   [ ] Create inventory
-   [ ] Test localhost
-   [ ] Create `site.yml`
-   [ ] Create SonarQube role
-   [ ] Create Prometheus role
-   [ ] Create Grafana role
-   [ ] Configure Grafana Prometheus datasource
-   [ ] Provision dashboards

### Phase 4 --- Terraform

-   [ ] Configure Terraform backend
-   [ ] Create VPC
-   [ ] Create public/private subnets
-   [ ] Create route tables
-   [ ] Create security groups
-   [ ] Create ECR
-   [ ] Create ECS cluster
-   [ ] Create task definition
-   [ ] Create ECS service
-   [ ] Create ALB
-   [ ] Create IAM roles
-   [ ] Configure CloudWatch
-   [ ] Store state in S3

### Phase 5 --- Infrastructure pipeline

-   [ ] Create `infra-Jenkinsfile`
-   [ ] `terraform init`
-   [ ] `terraform fmt`
-   [ ] `terraform validate`
-   [ ] `terraform plan`
-   [ ] `terraform apply`
-   [ ] Run Ansible configuration

### Phase 6 --- Application pipeline

-   [ ] Checkout application
-   [ ] Run quality checks
-   [ ] Run SonarQube analysis
-   [ ] Build Docker image
-   [ ] Run Trivy filesystem scan
-   [ ] Run Trivy image scan
-   [ ] Authenticate with ECR
-   [ ] Push image to ECR
-   [ ] Deploy to ECS

### Phase 7 --- Monitoring

-   [ ] Verify Prometheus
-   [ ] Verify Grafana
-   [ ] Configure Prometheus datasource
-   [ ] Create/provision dashboards
-   [ ] Monitor DevOps EC2
-   [ ] Monitor ECS
-   [ ] Monitor application metrics

### Phase 8 --- Validation

-   [ ] Open ALB endpoint
-   [ ] Confirm application is running
-   [ ] Verify ECS tasks
-   [ ] Verify ECR image
-   [ ] Verify Jenkins pipeline
-   [ ] Verify SonarQube
-   [ ] Verify Trivy results
-   [ ] Verify Prometheus
-   [ ] Verify Grafana
-   [ ] Verify Terraform state in S3

---

