pipeline {

    agent any

    environment {
        AWS_REGION = "${AWS_REGION}"
    }

    stages {

        // =========================================================
        // 1. CHECKOUT
        // =========================================================
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


        // =========================================================
        // 2. DISCOVER INFRASTRUCTURE
        // =========================================================
        stage('Discover Infrastructure') {
            steps {
                script {

                    echo 'Reading existing Terraform outputs...'

                    dir('terraform') {

                        // Read-only Terraform access.
                        // This pipeline never runs terraform apply.
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

                        env.ECS_BLUE_SERVICE = sh(
                            script: 'terraform output -raw ecs_blue_service_name',
                            returnStdout: true
                        ).trim()

                        env.ECS_GREEN_SERVICE = sh(
                            script: 'terraform output -raw ecs_green_service_name',
                            returnStdout: true
                        ).trim()

                        env.TASK_DEFINITION = sh(
                            script: 'terraform output -raw task_definition_arn',
                            returnStdout: true
                        ).trim()

                        env.ALB_ARN = sh(
                            script: 'terraform output -raw alb_arn',
                            returnStdout: true
                        ).trim()

                        env.ALB_LISTENER_ARN = sh(
                            script: 'terraform output -raw alb_listener_arn',
                            returnStdout: true
                        ).trim()

                        env.TEST_LISTENER_ARN = sh(
                            script: 'terraform output -raw test_listener_arn',
                            returnStdout: true
                        ).trim()

                        env.BLUE_TARGET_GROUP = sh(
                            script: 'terraform output -raw blue_target_group_arn',
                            returnStdout: true
                        ).trim()

                        env.GREEN_TARGET_GROUP = sh(
                            script: 'terraform output -raw green_target_group_arn',
                            returnStdout: true
                        ).trim()
                    }


                    // -------------------------------------------------
                    // Get ALB DNS name
                    // -------------------------------------------------
                    env.ALB_DNS_NAME = sh(
                        script: '''
                            aws elbv2 describe-load-balancers \
                              --load-balancer-arns "${ALB_ARN}" \
                              --region "${AWS_REGION}" \
                              --query 'LoadBalancers[0].DNSName' \
                              --output text
                        ''',
                        returnStdout: true
                    ).trim()


                    // -------------------------------------------------
                    // Display infrastructure information
                    // -------------------------------------------------
                    echo "=============================================="
                    echo "Infrastructure"
                    echo "=============================================="
                    echo "ECR Repository      : ${env.ECR_REPOSITORY}"
                    echo "ECS Cluster         : ${env.ECS_CLUSTER}"
                    echo "Blue Service        : ${env.ECS_BLUE_SERVICE}"
                    echo "Green Service       : ${env.ECS_GREEN_SERVICE}"
                    echo "Task Definition     : ${env.TASK_DEFINITION}"
                    echo "ALB ARN             : ${env.ALB_ARN}"
                    echo "ALB DNS             : ${env.ALB_DNS_NAME}"
                    echo "Production Listener : ${env.ALB_LISTENER_ARN}"
                    echo "Test Listener       : ${env.TEST_LISTENER_ARN}"
                    echo "Blue Target Group   : ${env.BLUE_TARGET_GROUP}"
                    echo "Green Target Group  : ${env.GREEN_TARGET_GROUP}"
                    echo "=============================================="


                    // -------------------------------------------------
                    // Get container name from current task definition
                    // -------------------------------------------------
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


        // =========================================================
        // 3. DETECT ACTIVE COLOR
        // =========================================================
        stage('Detect Active Color') {
            steps {
                script {

                    echo 'Detecting active production color...'

                    def activeTargetGroup = sh(
                        script: '''
                            aws elbv2 describe-listeners \
                              --listener-arn "${ALB_LISTENER_ARN}" \
                              --region "${AWS_REGION}" \
                              --query 'Listeners[0].DefaultActions[0].TargetGroupArn' \
                              --output text
                        ''',
                        returnStdout: true
                    ).trim()


                    echo "Active Target Group: ${activeTargetGroup}"


                    if (activeTargetGroup == env.BLUE_TARGET_GROUP) {

                        env.ACTIVE_COLOR = 'blue'
                        env.DEPLOY_COLOR = 'green'

                        env.ACTIVE_SERVICE = env.ECS_BLUE_SERVICE
                        env.DEPLOY_SERVICE = env.ECS_GREEN_SERVICE

                        env.ACTIVE_TARGET_GROUP = env.BLUE_TARGET_GROUP
                        env.DEPLOY_TARGET_GROUP = env.GREEN_TARGET_GROUP

                    }
                    else if (activeTargetGroup == env.GREEN_TARGET_GROUP) {

                        env.ACTIVE_COLOR = 'green'
                        env.DEPLOY_COLOR = 'blue'

                        env.ACTIVE_SERVICE = env.ECS_GREEN_SERVICE
                        env.DEPLOY_SERVICE = env.ECS_BLUE_SERVICE

                        env.ACTIVE_TARGET_GROUP = env.GREEN_TARGET_GROUP
                        env.DEPLOY_TARGET_GROUP = env.BLUE_TARGET_GROUP

                    }
                    else {

                        error(
                            "ALB production listener is pointing to an unknown target group: ${activeTargetGroup}"
                        )
                    }


                    echo "=============================================="
                    echo "Blue-Green Deployment Plan"
                    echo "=============================================="
                    echo "Active Color       : ${env.ACTIVE_COLOR}"
                    echo "Deployment Color   : ${env.DEPLOY_COLOR}"
                    echo "Active Service     : ${env.ACTIVE_SERVICE}"
                    echo "Deployment Service : ${env.DEPLOY_SERVICE}"
                    echo "=============================================="
                }
            }
        }


        // =========================================================
        // 4. SONARQUBE ANALYSIS
        // =========================================================
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


        // =========================================================
        // 5. QUALITY GATE
        // =========================================================
        stage('Quality Gate') {
            steps {

                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }


        // =========================================================
        // 6. DOCKER BUILD
        // =========================================================
        stage('Docker Build') {
            steps {

                sh '''
                    echo "Building Docker image..."

                    docker build \
                      -t "${IMAGE_URI}" \
                      ./app
                '''
            }
        }


        // =========================================================
        // 7. TRIVY SCAN
        // =========================================================
        stage('Trivy Scan') {
            steps {

                sh '''
                    echo "Scanning Docker image with Trivy..."

                    trivy image \
                      --exit-code 1 \
                      --severity HIGH,CRITICAL \
                      --ignore-unfixed \
                      "${IMAGE_URI}"
                '''
            }
        }


        // =========================================================
        // 8. PUSH IMAGE TO ECR
        // =========================================================
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


        // =========================================================
        // 9. CREATE NEW ECS TASK DEFINITION
        // =========================================================
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
                '''
            }
        }


        // =========================================================
        // 10. REGISTER NEW TASK DEFINITION
        // =========================================================
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

        stage('Prepare Test Listener') {
            steps {
                sh '''
                    echo "=============================================="
                    echo "Preparing test listener"
                    echo "=============================================="

                    echo "Routing test listener :8080 to ${DEPLOY_COLOR}"

                    aws elbv2 modify-listener \
                        --listener-arn "${TEST_LISTENER_ARN}" \
                        --default-actions Type=forward,TargetGroupArn="${DEPLOY_TARGET_GROUP}" \
                        --region "${AWS_REGION}"

                    echo "Test listener :8080 now points to ${DEPLOY_COLOR}."
                '''
            }
        }

        // =========================================================
        // 11. DEPLOY TO INACTIVE COLOR
        // =========================================================
        stage('Deploy to Inactive Color') {
            steps {

                sh '''
                    echo "=============================================="
                    echo "Deploying new version to ${DEPLOY_COLOR}"
                    echo "=============================================="

                    aws ecs update-service \
                      --cluster "${ECS_CLUSTER}" \
                      --service "${DEPLOY_SERVICE}" \
                      --task-definition "${NEW_TASK_DEFINITION}" \
                      --desired-count 1 \
                      --region "${AWS_REGION}"

                    echo "Deployment started."
                '''
            }
        }


        // =========================================================
        // 12. WAIT FOR ECS STABILITY
        // =========================================================
        stage('Wait for Inactive Service') {
            steps {

                sh '''
                    echo "Waiting for ${DEPLOY_COLOR} ECS service to become stable..."

                    aws ecs wait services-stable \
                      --cluster "${ECS_CLUSTER}" \
                      --services "${DEPLOY_SERVICE}" \
                      --region "${AWS_REGION}"

                    echo "${DEPLOY_COLOR} ECS service is stable."
                '''
            }
        }


        // =========================================================
        // 13. VERIFY TARGET HEALTH
        // =========================================================
        stage('Verify Target Health') {
            steps {

                script {

                    int maxAttempts = 10
                    boolean healthy = false

                    for (int attempt = 1; attempt <= maxAttempts; attempt++) {

                        def healthState = sh(
                            script: '''
                                aws elbv2 describe-target-health \
                                  --target-group-arn "${DEPLOY_TARGET_GROUP}" \
                                  --region "${AWS_REGION}" \
                                  --query 'TargetHealthDescriptions[].TargetHealth.State' \
                                  --output text
                            ''',
                            returnStdout: true
                        ).trim()

                        echo "Target health attempt ${attempt}: ${healthState}"


                        if (healthState.contains('healthy')) {
                            healthy = true
                            break
                        }


                        if (attempt < maxAttempts) {
                            echo "Waiting for ALB target health..."
                            sleep 15
                        }
                    }


                    if (!healthy) {
                        error(
                            "${env.DEPLOY_COLOR} target group did not become healthy."
                        )
                    }


                    echo "${env.DEPLOY_COLOR} target group is healthy."
                }
            }
        }


        // =========================================================
        // 14. ROUTE TEST TRAFFIC + TEST NEW COLOR
        // =========================================================
        stage('Test New Color') {
            steps {

                script {

                    echo "=============================================="
                    echo "Routing test traffic to ${env.DEPLOY_COLOR}"
                    echo "=============================================="


                    // -------------------------------------------------
                    // Point ALB :8080 to the new/inactive environment
                    // -------------------------------------------------
                    sh '''
                        aws elbv2 modify-listener \
                          --listener-arn "${TEST_LISTENER_ARN}" \
                          --default-actions Type=forward,TargetGroupArn="${DEPLOY_TARGET_GROUP}" \
                          --region "${AWS_REGION}"
                    '''


                    echo "Test listener :8080 now points to ${env.DEPLOY_COLOR}."


                    // -------------------------------------------------
                    // Smoke test the new environment
                    // -------------------------------------------------
                    echo "Testing ${env.DEPLOY_COLOR} application..."

                    sh '''
                        curl --fail --silent --show-error \
                          --max-time 10 \
                          "http://${ALB_DNS_NAME}:8080"

                        echo ""
                        echo "${DEPLOY_COLOR} application test PASSED."
                    '''
                }
            }
        }


        // =========================================================
        // 15. SWITCH PRODUCTION TRAFFIC
        // =========================================================
        stage('Switch Production Traffic') {
            steps {

                sh '''
                    echo "=============================================="
                    echo "Switching production traffic"
                    echo "=============================================="

                    echo "Old Active Color : ${ACTIVE_COLOR}"
                    echo "New Active Color : ${DEPLOY_COLOR}"


                    aws elbv2 modify-listener \
                      --listener-arn "${ALB_LISTENER_ARN}" \
                      --default-actions Type=forward,TargetGroupArn="${DEPLOY_TARGET_GROUP}" \
                      --region "${AWS_REGION}"


                    echo "Production traffic switched to ${DEPLOY_COLOR}."
                '''
            }
        }


        // =========================================================
        // 16. VERIFY PRODUCTION
        // =========================================================
        stage('Application Verification') {
            steps {

                script {

                    echo "Testing production application..."


                    sh '''
                        curl --fail --silent --show-error \
                          --max-time 10 \
                          "http://${ALB_DNS_NAME}"

                        echo ""
                        echo "Production application HTTP check PASSED."
                    '''


                    echo "=============================================="
                    echo "BLUE-GREEN DEPLOYMENT SUCCESSFUL"
                    echo "=============================================="
                    echo "Previous Color : ${env.ACTIVE_COLOR}"
                    echo "New Color      : ${env.DEPLOY_COLOR}"
                    echo "Application URL:"
                    echo "http://${env.ALB_DNS_NAME}"
                    echo "=============================================="
                }
            }
        }
    }


    // =============================================================
    // POST ACTIONS
    // =============================================================
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
