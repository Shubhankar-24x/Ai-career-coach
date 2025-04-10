pipeline {
    agent { label 'tyson' }

    environment {
        SONAR_HOME = tool 'Sonar'
        DockerHubUser = 'shubhankar24'
        ProjectName = 'career-coach'
        ImageTag = "${params.FRONTEND_DOCKER_TAG}"
        //DockerHubPassword = credentials('dockerhub-password-id') // Set this ID in Jenkins Credentials
    }

    parameters {
        string(name: 'FRONTEND_DOCKER_TAG', defaultValue: 'v0.1', description: 'Docker image tag for frontend')
    }

    stages {

        stage("Workspace Cleanup") {
            steps {
                echo "Cleaning the Workspace Before Proceeding"
                cleanWs()
            }
        }

        stage("Git: Clone") {
            steps {
                git url: 'https://github.com/Shubhankar-24x/Ai-career-coach.git', branch: 'main'
            }
        }

        stage("NodeJS: Installing ") {
            steps {
                sh '''
                    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
                    sudo apt-get install -y nodejs
                    node -v
                    npm -v'''

            }
        }

        stage('OWASP Dependency-Check Vulnerabilities') {
            steps {

                dependencyCheck additionalArguments: '--scan ./', odcInstallation: 'OWASP Dependency-Check Vulnerabilities'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                
            }
        }

        stage("Trivy: Filesystem Scanning") {
            steps {
                echo "Scanning the Filesystem for Vulnerabilities"
                sh "trivy fs ."
            }
        }

        stage('SonarQube: Code Analysis') {
            steps {
                withSonarQubeEnv('Sonar') {
                    sh """
                        $SONAR_HOME/bin/sonar-scanner \
                        -Dsonar.projectKey=Career-Coach \
                        -Dsonar.projectName=Career-Coach 
                    """
                }
            }
        }

        stage('SonarQube: Quality Gate Check') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage("Docker: Build Images") {
            environment {
                NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY = credentials('clerk-publishable-key')
                CLERK_SECRET_KEY = credentials('clerk-secret-key')
                DATABASE_URL = credentials('database-url')
                GEMINI_API_KEY = credentials('gemini-api-key')
        }
            steps {
                echo "Building Docker Image: ${DockerHubUser}/${ProjectName}:${ImageTag}"
                sh """
                    docker build -t ${DockerHubUser}/${ProjectName}:${ImageTag} \
                    --build-arg NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=${NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY} \
                    --build-arg CLERK_SECRET_KEY=${CLERK_SECRET_KEY} \
                    --build-arg DATABASE_URL=${DATABASE_URL} \
                    --build-arg GEMINI_API_KEY=${GEMINI_API_KEY} .
                """
            }
        }


        stage("Trivy Image Scanning") {
            steps {
                echo "Scanning the Docker Image for Vulnerabilities"
                sh "trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 ${DockerHubUser}/${ProjectName}:${ImageTag}"
            }
        }

        stage("Docker: Login to DockerHub") {
            steps {
                echo "Docker Login"
                sh " docker login -u ${DockerHubUser} --password ${DockerHubPassword}"
            }
        }

        stage("Docker: Image Push to DockerHub") {
            steps {
                echo "Pushing Docker Image to DockerHub"
                sh "docker push ${DockerHubUser}/${ProjectName}:${ImageTag}"
            }
        }
    }

    post {
        failure {
            echo "❌ Pipeline failed!"
        }
        success {
            echo "✅ Pipeline completed successfully."
        }
    }
}
