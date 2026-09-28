pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        IMAGE_NAME = 'spring-boot-jenkins-devops'
        IMAGE_TAG  = "build-${BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'nocommit'}"
        // 容器内 server.port 与宿主机映射端口统一为 8081
        APP_PORT   = '8081'
        HOST       = '192.168.128.41'
        USER       = 'root'
        WORK_DIR   = '/home/sanopll/MLops/jenkins-file/jenkins-maven'
        SSH_OPTS   = '-o StrictHostKeyChecking=no -o ConnectTimeout=10'
        SSH_TARGET = "${USER}@${HOST}"
    }

    stages {
        stage('检出代码') {
            steps {
                checkout scm
                sh 'git rev-parse --short HEAD'
                sh 'git status -s'
            }
        }

        stage('同步代码到宿主机') {
            steps {
                sshagent(credentials: ['k8s-master-ssh']) {
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'mkdir -p ${WORK_DIR}'"
                    sh "rsync -av --delete --exclude '.git' -e \"ssh ${SSH_OPTS}\" ./ ${SSH_TARGET}:${WORK_DIR}/ || scp -r ${SSH_OPTS} ./* ${SSH_TARGET}:${WORK_DIR}/"
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'cd ${WORK_DIR} && ls -la target/ 2>/dev/null || echo target not built yet'"
                }
            }
        }

        stage('宿主机构建并测试') {
            steps {
                sshagent(credentials: ['k8s-master-ssh']) {
                    // mvn package 已包含 test，单条命令即可，无需再单独跑 mvn test
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'cd ${WORK_DIR} && mvn -B -Dmaven.repo.local=/root/.m2 clean package'"
                }
            }
            post {
                always {
                    sshagent(credentials: ['k8s-master-ssh']) {
                        sh "scp ${SSH_OPTS} ${SSH_TARGET}:${WORK_DIR}/target/surefire-reports/*.xml . || true"
                    }
                    junit testResults: '**/target/surefire-reports/*.xml', allowEmptyResults: true
                }
            }
        }

        stage('宿主机构建镜像') {
            steps {
                sshagent(credentials: ['k8s-master-ssh']) {
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'cd ${WORK_DIR} && docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .'"
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest'"
                }
            }
        }

        stage('部署并验证') {
            when { branch 'main' }
            steps {
                sshagent(credentials: ['k8s-master-ssh']) {
                    // 注意端口映射改为 APP_PORT:APP_PORT，与容器内 8081 对应
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'docker rm -f ${IMAGE_NAME} || true'"
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'docker run -d --name ${IMAGE_NAME} -p ${APP_PORT}:${APP_PORT} --restart unless-stopped ${IMAGE_NAME}:${IMAGE_TAG}'"
                    sh """
                        ssh ${SSH_OPTS} ${SSH_TARGET} 'for i in \$(seq 1 30); do curl -fsS http://localhost:${APP_PORT}/actuator/health >/dev/null && exit 0; sleep 2; done; docker logs --tail 100 ${IMAGE_NAME}; exit 1'
                    """
                }
                // 外部访问使用宿主机 IP + APP_PORT
                sh "curl -fsS --connect-timeout 10 http://${HOST}:${APP_PORT}/api/hello"
            }
        }
    }

    post {
        success {
            echo "流水线成功：${IMAGE_NAME}:${IMAGE_TAG}  http://${HOST}:${APP_PORT}"
        }
        failure {
            echo "流水线失败：请查看控制台日志 —— ${env.BUILD_URL}"
        }
        cleanup {
            cleanWs()
        }
    }
}
