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
        string(name: 'FRONTEND_DOCKER_TAG', defaultValue: '', description: 'Docker image tag for frontend')
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
            steps {
                echo "Building Docker Image: ${DockerHubUser}/${ProjectName}:${ImageTag}"
                sh "docker build -t ${DockerHubUser}/${ProjectName}:${ImageTag} ."
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
