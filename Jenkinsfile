// =============================================================================
// 本地构建并推送 Harbor，再通过 SSH 调用远端全局部署脚本。
//
// 一次性前置条件：
//   Jenkins 执行环境需要 Maven、Docker CLI 和 Docker daemon 访问权限。
//   Harbor 使用 HTTP 时，Jenkins 使用的 Docker daemon 需将 Harbor 配置为
//   insecure registry（例如 192.168.128.41:80），然后重启 Docker。
//   HARBOR_PROJECT 指定的项目需已在 Harbor 中创建。
//   Jenkins 需配置 ID 为 k8s-master-ssh 的 SSH 私钥凭据，允许 root 无密码登录目标机。
// =============================================================================

def harborBuildPush() {
    sh '''
        set -eu
        curl -fsS -o /dev/null "http://${HARBOR_REGISTRY}/api/v2.0/ping"

        echo "-------- 开始输出 docker info --------"
        docker info 2>&1 | tee /tmp/dockerinfo.log || true
        echo "-------- 结束输出 docker info --------"

        grep -Fq "${HARBOR_REGISTRY}" /tmp/dockerinfo.log || {
            echo "Docker daemon 未将 ${HARBOR_REGISTRY} 配置为 insecure registry"
            exit 1
        }

        printf '%s' "$HARBOR_SECRET" |
            docker login "$HARBOR_REGISTRY" --username "$HARBOR_ACCOUNT" --password-stdin
        docker build --tag "$FULL_IMAGE" .
        docker push "$FULL_IMAGE"
        docker logout "$HARBOR_REGISTRY"
    '''
}

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
        IMAGE_TAG  = 'v1.0.0'
        APP_PORT   = '8090'

        HOST       = '192.168.128.41'
        USER       = 'root'
        WORK_DIR   = '/home/sanopll/MLops/jenkins-file/work-jenkins'

        HARBOR_REGISTRY = '192.168.128.41:80'
        HARBOR_PROJECT  = 'devops'
        HARBOR_USER     = 'admin'
        HARBOR_PASSWORD = 'Harbor12345'
        HARBOR_CRED_ID  = ''

        HARBOR_IMAGE = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}"
        FULL_IMAGE   = "${HARBOR_IMAGE}:${IMAGE_TAG}"

        SSH_OPTS   = '-o StrictHostKeyChecking=no -o ConnectTimeout=10'
        SSH_TARGET = "${USER}@${HOST}"
    }

    stages {
        stage('检出代码') {
            steps {
                checkout scm
                sh 'git rev-parse --short HEAD'
                sh 'echo "当前 GIT_BRANCH=${GIT_BRANCH}"'
                sh 'git status -s'
            }
        }

        stage('本地构建并测试') {
            steps {
                sh 'mvn -B clean package'
            }
            post {
                always {
                    junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true
                }
            }
        }

        stage('本地构建并推送 Harbor') {
            steps {
                script {
                    def credId = env.HARBOR_CRED_ID ? env.HARBOR_CRED_ID.trim() : ''
                    if (credId) {
                        withCredentials([usernamePassword(credentialsId: credId,
                                                          usernameVariable: 'HARBOR_ACCOUNT',
                                                          passwordVariable: 'HARBOR_SECRET')]) {
                            harborBuildPush()
                        }
                    } else {
                        echo '未配置 Jenkins Harbor 凭据，使用 Jenkinsfile 中的账号密码；建议改用 Jenkins 凭据。'
                        withEnv(["HARBOR_ACCOUNT=${env.HARBOR_USER}",
                                 "HARBOR_SECRET=${env.HARBOR_PASSWORD}"]) {
                            harborBuildPush()
                        }
                    }
                }
            }
        }

        stage('调用远端部署脚本') {
            steps {
                sshagent(credentials: ['k8s-master-ssh']) {
                    sh """
                        ssh ${SSH_OPTS} ${SSH_TARGET} 'cd ${WORK_DIR} && /usr/bin/deploy.sh ${HARBOR_REGISTRY} ${HARBOR_PROJECT} ${IMAGE_NAME} ${IMAGE_TAG} ${APP_PORT}'
                    """
                    sh """
                        ssh ${SSH_OPTS} ${SSH_TARGET} 'for i in \$(seq 1 30); do curl -fsS http://localhost:${APP_PORT}/actuator/health >/dev/null && exit 0; sleep 2; done; docker logs --tail 100 ${IMAGE_NAME}; exit 1'
                    """
                }
                sh "curl -fsS --connect-timeout 10 http://${HOST}:${APP_PORT}/api/hello"
            }
        }
    }

    post {
        success {
            echo "流水线成功"
            echo "镜像：${FULL_IMAGE}"
            echo "Harbor：http://${HARBOR_REGISTRY}/harbor/projects/${HARBOR_PROJECT}/repositories/${IMAGE_NAME}"
            echo "应用：http://${HOST}:${APP_PORT}"
        }
        failure {
            echo "流水线失败：请查看控制台日志 —— ${env.BUILD_URL}"
        }
        cleanup {
            cleanWs()
        }
    }
}
