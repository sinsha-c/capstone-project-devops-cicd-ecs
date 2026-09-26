pipeline {

    agent any

    environment {
        AWS_REGION = "${AWS_REGION}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                script {
                    env.IMAGE_TAG = sh(
                        script: 'git rev-parse --short=12 HEAD',
                        returnStdout: true
                    ).trim()

                    echo "Git Commit: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Discover Infrastructure') {
            steps {
                script {

                    echo 'Reading existing Terraform outputs...'

                    dir('terraform') {

                        // Connect to existing S3 Terraform state
                        sh '''
                            terraform init -input=false
                        '''

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

                    echo "ECR Repository : ${env.ECR_REPOSITORY}"
                    echo "ECS Cluster    : ${env.ECS_CLUSTER}"
                    echo "ECS Service    : ${env.ECS_SERVICE}"
                    echo "Task Definition: ${env.TASK_DEFINITION}"

                    /*
                     * Container name is obtained directly from
                     * the existing ECS task definition.
                     */
                    env.CONTAINER_NAME = sh(
                        script: '''
                            aws ecs describe-task-definition \
                              --task-definition "${TASK_DEFINITION}" \
                              --region "${AWS_REGION}" \
                              --query 'taskDefinition.containerDefinitions[].name' \
                              --output text
                        ''',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_URI = "${env.ECR_REPOSITORY}:${env.IMAGE_TAG}"

                    echo "Container Name : ${env.CONTAINER_NAME}"
                    echo "Image URI      : ${env.IMAGE_URI}"
                }
            }
        }

        stage('SonarQube Analysis') {
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

        stage('Docker Build') {
            steps {
                sh '''
                    docker build \
                      -t "${IMAGE_URI}" \
                      ./app
                '''
            }
        }

        stage('Trivy Scan') {
            steps {
                sh '''
                    trivy image \
                      --exit-code 1 \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      "${IMAGE_URI}"
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    echo "Logging in to Amazon ECR..."

                    aws ecr get-login-password \
                      --region "${AWS_REGION}" |
                    docker login \
                      --username AWS \
                      --password-stdin "${ECR_REPOSITORY}"

                    echo "Pushing image: ${IMAGE_URI}"

                    docker push "${IMAGE_URI}"
                '''
            }
        }

        stage('Create ECS Task Definition') {
            steps {
                sh '''
                    echo "Getting current ECS task definition..."

                    aws ecs describe-task-definition \
                      --task-definition "${TASK_DEFINITION}" \
                      --region "${AWS_REGION}" \
                      --query 'taskDefinition' \
                      --output json > task-definition.json


                    echo "Removing ECS-generated metadata..."

                    jq '
                      del(
                        .taskDefinitionArn,
                        .revision,
                        .status,
                        .requiresAttributes,
                        .compatibilities,
                        .registeredAt,
                        .registeredBy
                      )
                    ' task-definition.json \
                    > task-definition-clean.json


                    echo "Updating container image..."

                    jq \
                      --arg CONTAINER_NAME "${CONTAINER_NAME}" \
                      --arg IMAGE_URI "${IMAGE_URI}" \
                      '
                      (.containerDefinitions[]
                        | select(.name == $CONTAINER_NAME)
                        | .image) = $IMAGE_URI
                      ' \
                      task-definition-clean.json \
                      > new-task-definition.json


                    echo "New task definition prepared."

                    cat new-task-definition.json
                '''
            }
        }

        stage('Register New Task Definition') {
            steps {
                script {

                    echo 'Registering new ECS task definition...'

                    env.NEW_TASK_DEFINITION = sh(
                        script: '''
                            aws ecs register-task-definition \
                              --region "${AWS_REGION}" \
                              --cli-input-json file://new-task-definition.json \
                              --query 'taskDefinition.taskDefinitionArn' \
                              --output text
                        ''',
                        returnStdout: true
                    ).trim()

                    echo "New Task Definition: ${env.NEW_TASK_DEFINITION}"
                }
            }
        }

        stage('Deploy to ECS') {
            steps {
                sh '''
                    echo "Updating ECS service..."

                    aws ecs update-service \
                      --cluster "${ECS_CLUSTER}" \
                      --service "${ECS_SERVICE}" \
                      --task-definition "${NEW_TASK_DEFINITION}" \
                      --region "${AWS_REGION}"

                    echo "ECS service update initiated."
                '''
            }
        }

        stage('Deployment Verification') {
            steps {
                sh '''
                    echo "Waiting for ECS service to become stable..."

                    aws ecs wait services-stable \
                      --cluster "${ECS_CLUSTER}" \
                      --services "${ECS_SERVICE}" \
                      --region "${AWS_REGION}"

                    echo "ECS deployment completed successfully."
                '''
            }
        }
    }

    post {

        always {
            sh '''
                rm -f task-definition.json
                rm -f task-definition-clean.json
                rm -f new-task-definition.json
            '''

            echo 'Application pipeline finished.'
        }
    }
}
