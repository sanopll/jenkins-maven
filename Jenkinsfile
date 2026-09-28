pipeline {
	agent any
	environment {
		IMAGE_NAME = "spring-boot-jenkins-devops"
		IMAGE_TAG = "build-${BUILD_NUMBER}"
		HOST_PORT = "8081"
	}
	stages {
		stage("检出代码") {
			steps {
				checkout scm
			}
		}
		stage("构建应用") {
			steps {
				sh "mvn -B clean package -DskipTests"
			}
		}
		stage("运行测试") {
			steps {
				sh "mvn -B test"
			}
		}
		stage("构建镜像") {
			steps {
				sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
			}
		}
		stage("部署验证") {
			when {
				branch "main"
			}
			steps {
				sh "docker rm -f ${IMAGE_NAME} || true"
				sh "docker run -d --name ${IMAGE_NAME} -p ${HOST_PORT}:8080 ${IMAGE_NAME}:${IMAGE_TAG}"
				sh "for i in \$(seq 1 30); do curl -fsS http://localhost:${HOST_PORT}/actuator/health >/dev/null && exit 0; sleep 2; done; exit 1"
				sh "curl -fsS http://localhost:${HOST_PORT}/api/hello"
			}
		}
	}
	post {
		success {
			echo "流水线成功：镜像 ${IMAGE_NAME}:${IMAGE_TAG}"
		}
		failure {
			echo "流水线失败：请查看各阶段日志"
		}
	}
}
