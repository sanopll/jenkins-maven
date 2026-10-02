// =============================================================================
// Harbor 推送流水线
//
// 一次性前置条件（宿主机 192.168.128.41 上执行一次）：
//   Harbor 跑在 HTTP 的 80 端口，Docker 默认只信任 HTTPS，必须配 insecure-registries：
//     sudo mkdir -p /etc/docker
//     echo '{ "insecure-registries": ["192.168.128.41:80"] }' | sudo tee /etc/docker/daemon.json
//     sudo systemctl restart docker
//   （若 daemon.json 已有其它配置，只往 "insecure-registries" 数组里追加，别整个覆盖）
//
// 另外 HARBOR_PROJECT 指定的项目要已存在，不存在的话去 Harbor 网页新建即可。
//
// 所有可调参数都在下面 environment 块里，只改那里就够了。
// =============================================================================

// 登录 Harbor → 构建镜像 → 推送，全程在宿主机上执行。
// 密码写入临时文件后用 stdin 传给 docker login，不会出现在构建日志和进程列表里。
def harborBuildPush(String account, String secret) {
    writeFile file: '.harbor-secret', text: "${secret}\n"
    sh """
        set -e
        ssh -T ${env.SSH_OPTS} ${env.SSH_TARGET} '
            set -e
            REG="${env.HARBOR_REGISTRY}"
            PROJ="${env.HARBOR_PROJECT}"
            FULL="${env.HARBOR_IMAGE}:${env.IMAGE_TAG}"
            ACCOUNT="${account}"
            WORKDIR="${env.WORK_DIR}"
            read -r SECRET

            echo "─── [1/4] 检查 Harbor 是否可达 ───"
            curl -fsS -o /dev/null "http://\$REG/api/v2.0/ping" || { echo "❌ 无法访问 http://\$REG ，请确认 Harbor 已启动"; exit 1; }
            echo "    ✔ Harbor 可达"

            echo "─── [2/4] 检查 Docker 是否信任该仓库 ───"
            docker info 2>/dev/null | grep -q "\$REG" || { echo "❌ 宿主机 Docker 未把 \$REG 加入 insecure-registries，push 会失败"; echo "   见 Jenkinsfile 顶部注释，改完重启 Docker 再试"; exit 1; }
            echo "    ✔ 已信任 \$REG"

            echo "─── [3/4] 检查 Harbor 项目 \$PROJ ───"
            CODE=\$(curl -s -o /dev/null -w "%{http_code}" -u "\$ACCOUNT:\$SECRET" "http://\$REG/api/v2.0/projects/\$PROJ")
            [ "\$CODE" = "200" ] || { echo "❌ 项目 \$PROJ 不存在或账号无权限（HTTP \$CODE），请先去 Harbor 网页创建该项目"; exit 1; }
            echo "    ✔ 项目存在"

            echo "─── [4/4] 登录 Harbor → 构建 → 推送 ───"
            printf "%s\\n" "\$SECRET" | docker login "\$REG" -u "\$ACCOUNT" --password-stdin
            cd "\$WORKDIR"
            docker build -t "\$FULL" .
            docker push "\$FULL"
            echo "✔ 推送完成：\$FULL"
        ' < .harbor-secret
    """
    sh 'rm -f .harbor-secret'
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
        IMAGE_TAG  = "build-${BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'nocommit'}"

       
        APP_PORT   = '8090'

        HOST       = '192.168.128.41'
        USER       = 'root'
        WORK_DIR   = '/home/sanopll/MLops/jenkins-file/jenkins-maven'

        // ================= Harbor 镜像仓库（按需修改） =================
        HARBOR_REGISTRY = '192.168.128.41:80'   // Harbor 地址，必须带端口
        HARBOR_PROJECT  = 'devops'              // Harbor 项目名（需已存在）
        HARBOR_USER     = 'admin'               // Harbor 账号
        HARBOR_PASSWORD = 'Harbor12345'         // Harbor 密码（回退用）
        HARBOR_CRED_ID  = ''                    // Jenkins 凭据 ID；填了就优先用它，密码不进日志

        // 完整镜像名（不含 tag）：192.168.128.41:80/devops/spring-boot-jenkins-devops
        HARBOR_IMAGE = "${HARBOR_REGISTRY}/${HARBOR_PROJECT}/${IMAGE_NAME}"
        // =============================================================

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

        stage('同步代码到宿主机') {
            steps {
                sshagent(credentials: ['k8s-master-ssh']) {
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'mkdir -p ${WORK_DIR}'"
                    // rsync 缺失时退化为 scp
                    sh "rsync -av --delete --exclude '.git' -e \"ssh ${SSH_OPTS}\" ./ ${SSH_TARGET}:${WORK_DIR}/ || scp -r ${SSH_OPTS} ./* ${SSH_TARGET}:${WORK_DIR}/"
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'cd ${WORK_DIR} && ls -la target/ 2>/dev/null || echo target not built yet'"
                }
            }
        }

        stage('宿主机构建并测试') {
            steps {
                sshagent(credentials: ['k8s-master-ssh']) {
                    // mvn package 生命周期已包含 test，无需再单独跑 mvn test
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'cd ${WORK_DIR} && mvn -B -Dmaven.repo.local=/root/.m2 clean package'"
                }
            }
            post {
                always {
                    sshagent(credentials: ['k8s-master-ssh']) {
                        // 关键：先保存到 Jenkins 工作空间，否则 junit 步骤读不到
                        sh "mkdir -p ${WORKSPACE}/target/surefire-reports"
                        sh "scp ${SSH_OPTS} '${SSH_TARGET}:${WORK_DIR}/target/surefire-reports/*.xml' ${WORKSPACE}/target/surefire-reports/ || true"
                    }
                    junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true
                }
            }
        }

        stage('构建并推送 Harbor') {
            steps {
                sshagent(credentials: ['k8s-master-ssh']) {
                    script {
                        // HARBOR_CRED_ID 填了就走 Jenkins 凭据，密码不会进构建日志
                        def credId = env.HARBOR_CRED_ID ? env.HARBOR_CRED_ID.trim() : ''
                        if (credId) {
                            withCredentials([usernamePassword(credentialsId: credId,
                                                              usernameVariable: 'HARBOR_ACCOUNT',
                                                              passwordVariable: 'HARBOR_SECRET')]) {
                                echo "使用 Jenkins 凭据 ${credId} 登录 Harbor"
                                harborBuildPush(env.HARBOR_ACCOUNT, env.HARBOR_SECRET)
                            }
                        } else {
                            echo '⚠️ 未配置 Jenkins 凭据（HARBOR_CRED_ID 为空），本次使用 Jenkinsfile 中的明文账号密码，建议改用凭据'
                            harborBuildPush(env.HARBOR_USER, env.HARBOR_PASSWORD)
                        }
                    }
                }
            }
        }

        stage('部署并验证') {
            // 放宽分支判断，避免 origin/main 等写法导致部署被跳过
            when {
                anyOf {
                    branch 'main'
                    branch 'origin/main'
                    expression { env.GIT_BRANCH?.contains('main') }
                }
            }
            steps {
                sshagent(credentials: ['k8s-master-ssh']) {
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'docker rm -f ${IMAGE_NAME} || true'"
                 
                    sh "ssh ${SSH_OPTS} ${SSH_TARGET} 'docker run -d --name ${IMAGE_NAME} -p ${APP_PORT}:${APP_PORT} --restart unless-stopped ${IMAGE_NAME}:${IMAGE_TAG}'"
                    sh """
                        ssh ${SSH_OPTS} ${SSH_TARGET} 'for i in \$(seq 1 30); do curl -fsS http://localhost:${APP_PORT}/actuator/health >/dev/null && exit 0; sleep 2; done; docker logs --tail 100 ${IMAGE_NAME}; exit 1'
                    """
                }
                // 外部通过宿主机 IP + APP_PORT 访问
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
