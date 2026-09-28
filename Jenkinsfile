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
        HOST_PORT  = '8090'
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
                    // rsync 只传增量，比 cp -r 快且幂等；缺 rsync 时退化为 scp -r
                    sh "rsync -av --delete --exclude '.git' -e \"ssh ${SSH_OPTS}\" ./ ${SSH_TARGET}:${WORK_DIR}/ || scp -r ${SSH_OPTS} ./* ${SSH_TARGET}:${WORK_DIR}/"
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'cd ${WORK_DIR} && ls -la target/ 2>/dev/null || echo target not built yet'"
                }
            }
        }

        stage('宿主机构建并测试') {
            steps {
                sshagent(credentials: ['k8s-master-ssh']) {
                    // mvn package 已经包含 test，重复跑 mvn test 是浪费两轮时间；保留单条命令
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'cd ${WORK_DIR} && mvn -B -Dmaven.repo.local=/root/.m2 clean package -DskipTests=false'"
                }
            }
            post {
                always {
                    // 把测试报告从目标机取回，供 Jenkins JUnit 展示趋势
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
                    // 镜像名带上本次 tag，避免 :latest 互相覆盖导致回滚失败
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'cd ${WORK_DIR} && docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest'"
                }
            }
        }

        stage('部署并验证') {
            when { branch 'main' }
            steps {
                sshagent(credentials: ['k8s-master-ssh']) {
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'docker rm -f ${IMAGE_NAME} || true'"
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'docker run -d --name ${IMAGE_NAME} -p ${HOST_PORT}:8080 --restart unless-stopped ${IMAGE_NAME}:${IMAGE_TAG}'"
                    sh """
                        ssh ${SSH_OPTS} ${SSH_TARGET} 'for i in \$(seq 1 30); do curl -fsS http://localhost:${HOST_PORT}/actuator/health >/dev/null && exit 0; sleep 2; done; docker logs --tail 100 ${IMAGE_NAME}; exit 1'
                    """
                }
                sh "curl -fsS --connect-timeout 10 http://${HOST}:${HOST_PORT}/api/hello"
            }
        }
    }

    post {
        success {
            echo "流水线成功：${IMAGE_NAME}:${IMAGE_TAG}  http://${HOST}:${HOST_PORT}"
        }
        failure {
            echo "流水线失败：请查看控制台日志 —— ${env.BUILD_URL}"
        }
        cleanup {
            cleanWs()
        }
    }
}


