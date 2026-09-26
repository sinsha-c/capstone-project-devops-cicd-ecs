pipeline {

    agent any

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: "${REPO_URL}"

                script {
                    env.IMAGE_TAG = sh(
                        script: 'git rev-parse --short=12 HEAD',
                        returnStdout: true
                    ).trim()

                    echo "Git Commit: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Test Jenkins Environment') {
            steps {
                sh '''
                    echo "================================"
                    echo "Jenkins Environment Test"
                    echo "================================"

                    echo "Repository : ${REPO_URL}"
                    echo "AWS Region : ${AWS_REGION}"
                    echo "Git Commit : ${IMAGE_TAG}"

                    echo ""
                    echo "AWS Identity:"
                    aws sts get-caller-identity
                '''
            }
        }

        stage('Test Terraform Outputs') {
            steps {
                dir('terraform') {
                    sh '''
                        echo "Initializing Terraform..."

                        terraform init -input=false

                        echo ""
                        echo "Terraform Outputs:"
                        terraform output
                    '''

                    script {
                        env.ECR_REPOSITORY = sh(
                            script: 'terraform output -raw ecr_repository_url',
                            returnStdout: true
                        ).trim()

                        env.ECS_CLUSTER = sh(
                            script: 'terraform output -raw ecs_cluster_name',
                            returnStdout: true
                        ).trim()

                        env.ECS_SERVICE = sh(
                            script: 'terraform output -raw ecs_service_name',
                            returnStdout: true
                        ).trim()

                        env.TASK_DEFINITION = sh(
                            script: 'terraform output -raw task_definition_arn',
                            returnStdout: true
                        ).trim()
                    }
                }

                echo "ECR Repository : ${env.ECR_REPOSITORY}"
                echo "ECS Cluster    : ${env.ECS_CLUSTER}"
                echo "ECS Service    : ${env.ECS_SERVICE}"
                echo "Task Definition: ${env.TASK_DEFINITION}"
            }
        }

        stage('Test ECS Access') {
            steps {
                sh '''
                    echo "Testing ECS access..."

                    aws ecs describe-task-definition \
                      --task-definition "${TASK_DEFINITION}" \
                      --region "${AWS_REGION}" \
                      --query 'taskDefinition.containerDefinitions[].name' \
                      --output table
                '''
            }
        }

        stage('Test Docker') {
            steps {
                sh '''
                    echo "Testing Docker access..."

                    docker --version
                    docker ps
                '''
            }
        }

        stage('Test Trivy') {
            steps {
                sh '''
                    echo "Testing Trivy..."

                    trivy --version
                '''
            }
        }

        stage('Test SonarQube') {
            steps {
                script {
                    def scannerHome = tool 'sonar-scanner'

                    withSonarQubeEnv('SonarQube') {
                        sh "${scannerHome}/bin/sonar-scanner"
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Test Complete') {
            steps {
                echo '================================'
                echo 'Jenkins configuration test PASSED'
                echo 'No Docker image was built.'
                echo 'No image was pushed to ECR.'
                echo 'No ECS deployment was performed.'
                echo '================================'
            }
        }
    }
}
