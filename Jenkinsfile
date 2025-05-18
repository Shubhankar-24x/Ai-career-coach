pipeline {
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
        string(name: 'FRONTEND_DOCKER_TAG', defaultValue: 'v1', description: 'Docker image tag for frontend')
       // string(name: 'NEXUS_URL', defaultValue: 'http://3.17.165.120:8082', description: 'Docker registry URL (not Nexus UI)')
        //string(name: 'NEXUS_REPOSITORY', defaultValue: 'Docker-Image', description: 'Docker repository name (used only for naming)')
        string(name: 'GIT_BRANCH', defaultValue: 'dev', description: 'Git branch to update deployment.yaml')
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


        stage("Trivy: Image Scanning") {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-cred', usernameVariable: 'dockerHubUser', passwordVariable: 'dockerHubPass')]) {
                    script {
                        def reportDir = "trivy-image-report/${ProjectName}-${ImageTag}"
                        sh "mkdir -p ${reportDir}"
                        echo "Scanning the Docker Image for Vulnerabilities"
                        sh "trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 0 ${dockerHubUser}/${ProjectName}:${ImageTag} > ${reportDir}/trivy-results.txt"
                    }
                }
            }
        }

           stage("Docker: Image Push") {
                steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker-cred', passwordVariable: 'dockerHubPass', usernameVariable: 'dockerHubUser')]) {
                        echo "Logging into DockerHub"
                        sh "docker login -u ${dockerHubUser} -p ${dockerHubPass}"

                        echo "Pushing image to Docker Hub"
                        sh "docker push ${dockerHubUser}/${ProjectName}:${ImageTag}"
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
    set +e

    git config user.name "Jenkins"
    git config user.email "jenkins@example.com"

    # Stage and commit changes first (on current branch)
    git add kubernetes/deployment.yaml
    git diff --cached --quiet || git commit -m "Update Kubernetes deployment with image tag: ${ImageTag} [skip ci]"

    # Save commit hash to re-apply later
    COMMIT_HASH=\$(git rev-parse HEAD)

    # Setup remote with credentials
    git remote set-url origin https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/Shubhankar-24x/Ai-career-coach.git

    # Fetch latest remote branches
    git fetch origin

    # Create and checkout local '${params.GIT_BRANCH}' branch from remote
    git checkout -B ${params.GIT_BRANCH} origin/${params.GIT_BRANCH}

    # Cherry-pick previously committed change onto the target branch
    git cherry-pick \$COMMIT_HASH
    STATUS=\$?

    if [ \$STATUS -ne 0 ]; then
        echo "❌ Cherry-pick failed due to conflict. Resolving using remote version."
        git checkout --theirs kubernetes/deployment.yaml
        git add kubernetes/deployment.yaml
        git cherry-pick --continue
    fi

    set -e

    # Push to '${params.GIT_BRANCH}' branch
    git push origin ${params.GIT_BRANCH}
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

     



    
