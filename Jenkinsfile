pipeline {
    //agent { label 'tyson' }

agent any

    environment {
        SONAR_HOME = tool 'Sonar'
        ProjectName = 'career-coach'
        ImageTag = "${params.FRONTEND_DOCKER_TAG}"
        NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY = credentials('NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY')
        CLERK_SECRET_KEY = credentials('CLERK_SECRET_KEY')
        DATABASE_URL = credentials('DATABASE_URL')
        GEMINI_API_KEY = credentials('GEMINI_API_KEY')
    }

    parameters {
        string(name: 'FRONTEND_DOCKER_TAG', defaultValue: 'V1', description: 'Docker image tag for frontend')
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
                sh "trivy fs --format table -o fs.html ."
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

        stage("Docker: Image Build") {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-cred', passwordVariable: 'dockerHubPass', usernameVariable: 'dockerHubUser')]) {
                    echo "Building Docker Image: ${dockerHubUser}/${ProjectName}:${ImageTag}"
                    sh """
                        docker build -t ${dockerHubUser}/${ProjectName}:${ImageTag} \\
                        --build-arg NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=${NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY} \\
                        --build-arg CLERK_SECRET_KEY=${CLERK_SECRET_KEY} \\
                        --build-arg DATABASE_URL=${DATABASE_URL} \\
                        --build-arg GEMINI_API_KEY=${GEMINI_API_KEY} .
                    """
                }
            }
        }


        stage("Trivy Image Scanning") {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-cred', passwordVariable: 'dockerHubPass', usernameVariable: 'dockerHubUser')]) {
                    echo "Scanning the Docker Image for Vulnerabilities"
                    sh "trivy image --format table -o dimage.html ${dockerHubUser}/${ProjectName}:${ImageTag}"
                }
            }
        }

        stage("Docker: Image Push") {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker-cred', passwordVariable: 'dockerHubPass', usernameVariable: 'dockerHubUser')]) {
                        echo "Logging into DockerHub"
                        sh "docker login -u ${dockerHubUser} -p ${dockerHubPass}"
                        echo "Login to DockerHub successful"

                        echo "Pushing image to Docker Hub"
                        sh "docker push ${dockerHubUser}/${ProjectName}:${ImageTag}"
                        echo "Image pushed successfully to Docker Hub"
                    }
                }
            }
        }
        stage("Update Kubernetes Manifest") {
                steps {
                withCredentials([
                    usernamePassword(credentialsId: 'docker-cred', usernameVariable: 'dockerHubUser', passwordVariable: 'dockerHubPass'),
                    usernamePassword(credentialsId: 'github-cred', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_TOKEN')
                ]) {
                    script {
                        def newImage = "${dockerHubUser}/${ProjectName}:${ImageTag}"
                        echo "Updating kubernetes/deployment.yaml with image: ${newImage}"

                        sh """
                            sed -i "s|^\\(\\s*image:\\s*\\).*|\\1${newImage}|g" kubernetes/deployment.yaml
                        """

                        sh """
                            git config user.name "Jenkins"
                            git config user.email "jenkins@example.com"
                            git add kubernetes/deployment.yaml
                            git diff --cached --quiet || git commit -m "Update Kubernetes deployment with image tag: ${ImageTag} [skip ci]"
                            git remote set-url origin https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/Shubhankar-24x/Ai-career-coach.git
                            git pull --no-rebase origin main
                            git push origin main
                        """
                    }
                }
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
// This Jenkinsfile is designed to automate the CI/CD pipeline for the Ai Career Coach project.
