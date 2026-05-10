pipeline {
agent any

environment {
    DOCKER_IMAGE = "krishnabhujbal/terraform-aws-nodejs"
    TAG = "${BUILD_NUMBER}"
}

stages {

    stage('Checkout Code') {
        steps {
            git branch: 'main', url: 'https://github.com/IronClad42/Devops-Terraform-Project.git'
        }
    }

    stage('Build Docker Image') {
        steps {
            dir('App') {
                sh "docker build -t ${DOCKER_IMAGE}:${TAG} ."
            }
        }
    }

    stage('Docker Login') {
        steps {
            withCredentials([usernamePassword(
                credentialsId: 'docker-creds',
                usernameVariable: 'USER',
                passwordVariable: 'PASS'
            )]) {

                sh 'echo $PASS | docker login -u $USER --password-stdin'
            }
        }
    }

    stage('Push Image') {
        steps {
            sh "docker push ${DOCKER_IMAGE}:${TAG}"
        }
    }

    stage('Deploy to Kubernetes') {
        steps {
            dir('App') {

                sh """
                pwd

                ls -la

                ls -la K8s

                sed -i 's|IMAGE|${DOCKER_IMAGE}:${TAG}|g' K8s/deployment.yml

                kubectl apply -f K8s/
                """
            }
        }
    }

}

post {

    success {
        echo 'Deployment Successful 🚀'
    }

    failure {

        emailext(
            to: 'krishnabhujbal176@gmail.com',
            subject: '❌ Jenkins Build Failed',
            body: "Build Failed: ${env.BUILD_URL}"
        )
    }
}

}