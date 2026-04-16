pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                sh 'docker build -t yourdocker/app .'
            }
        }
        stage('Push') {
            steps {
                sh 'docker push yourdocker/app'
            }
        }
        stage('Deploy') {
            steps {
                sh 'kubectl apply -f k8s/'
            }
        }
    }
}