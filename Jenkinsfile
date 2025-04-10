pipeline{

   // agent any
    agent { label 'tyson' }

    environment{
        SONAR_HOME= tool "Sonar"
    }

    // Building with Parameters

    parameters{

        string(name: 'FRONTEND_DOCKER_TAG',defaultValue: '', description: 'Setting docker image for latest push')
        //string(name: 'BACKEND_DOCKER_TAG',defaultValue: '', description: 'Setting docker image for latest push')
    }


    stages{

        stage("Workspace Cleanup"){
            steps{
                script{
                    echo "Cleaning the Workspace Before Proceeding"
                    cleanWs()
                }
                
            }
        }


        stage("Git: Clone"){
            steps{
                script{
                    git{url: "https://github.com/Shubhankar-24x/Ai-career-coach.git", 
                        branch: "main"}
                }

            }
        }
        stage('OWASP Dependency-Check Vulnerabilities') {
            steps {
                dependencyCheck additionalArguments: ''' 
                            -o './'
                            -s './'
                            -f 'ALL' 
                            --prettyPrint''', odcInstallation: 'OWASP Dependency-Check Vulnerabilities'
        
                dependencyCheckPublisher pattern: 'dependency-check-report.xml'
             }
         }

        stage("Trivy: Filesystem Scanning"){
            steps{
                script{
                    echo "Scanning the Filesystem for Vulnerabilities"
                    sh "trivy fs ."
                }
            }
        }

        stage("SonarQube: Code Analysis"){
            steps{
                script{
                    sonarqube_analysis("Sonar","career-coach","career-coach")
                }
            }
        }
        stage("SonarQube Quality Gate Check") {
            steps {
                script {
                def qualityGate = waitForQualityGate()
                    
                    if (qualityGate.status != 'OK') {
                        echo "${qualityGate.status}"
                        error "Quality Gate failed: ${qualityGateStatus}"
                    }
                    else {
                        echo "${qualityGate.status}"
                        echo "SonarQube Quality Gates Passed"
                    }
                }
            }
        }


     

        stage("Docker: Build Images"){
            steps{
                script{
                    sh "docker build -t ${DockerHubUser}/${ProjectName}:${ImageTag} ."
                   // docker_build("career-coach-test", "${params.FRONTEND_DOCKER_TAG}", "shubhankar24")

                   // docker_build("career-coach-test", "${params.BACKEND_DOCKER_TAG}", "shubhankar24")
                }
            }
        }

        stage("Trivy Image Scanning"){
            steps{
                script{
                    echo "Scanning the Docker Image for Vulnerabilities"
                    sh "trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 ${DockerHubUser}/${ProjectName}:${ImageTag}"
                }
            }
            
        }

        stage{
            steps{
                script{
                    echo "Docker Login"
                    sh "docker login -u ${DockerHubUser} -p ${DockerHubPassword}"
                    echo "Docker Login Successful"
                }
            }
        }


        stage("Docker: Image Push to DockerHub"){
            steps{
                script{
                    echo "Pushing Docker Image to DockerHub"
                    sh "docker push ${DockerHubUser}/${ProjectName}:${ImageTag}"
                    echo "Docker Image Pushed to DockerHub Successfully"
                }
            }
        }

        

       // stage("Docker Build & Deploy"){
         //   steps{
             //   script{
                //    sh "docker compose down && docker compose up -d "
             //   }
           // }
       // }



    }
}
