@Library('Shared') _

pipeline{

    agent any

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
                    clone("https://github.com/Shubhankar-24x/Ai-career-coach.git", "main")
                }

            }
        }

        
        stage("Trivy: Filesystem Scanning"){
            steps{
                script{
                    trivy_scan()
                }
            }
        }

        stage("OWASP: Dependency Check"){
            steps{
                script{
                    owasp_dependency_check()
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

        stage("SonarQube: Code Quality Gates"){
            steps{
                script{
                    sonarqube_code_quality()
                }
            }
        }


     

        stage("Docker: Build Images"){
            steps{
                script{
                    docker_build("career-coach-test", "${params.FRONTEND_DOCKER_TAG}", "shubhankar24")

                   // docker_build("career-coach-test", "${params.BACKEND_DOCKER_TAG}", "shubhankar24")
                }
            }
        }

        stage("Docker: Image Push to DockerHub"){
            steps{
                script{
                    docker_push()
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
