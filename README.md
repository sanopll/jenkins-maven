# spring-boot-jenkins-devops

这是一个面向 DevOps 初学者的个人练习项目：
- Spring Boot 提供 REST API 与 Actuator 健康检查
- GitHub 托管源代码与 `Jenkinsfile`
- Jenkins 执行构建、测试、Docker 镜像构建和本机容器部署
- Maven 管理依赖并生成可执行 jar

## 1. 本地验证

```bash
mvn clean package
java -jar target/*.jar
curl http://localhost:8080/api/hello
```

## 2. Jenkins 前置条件

在 Ubuntu 主机确认以下组件：

```bash
java -version
mvn -version
git -v
docker -v
systemctl status jenkins docker
```

Jenkins 需要能够执行 `docker`。推荐将 Jenkins 运行时用户加入 Docker 组，然后重启相关服务。

## 3. Jenkins 任务

1. 新建 **Pipeline** 任务。
2. 「构建触发器」选择 **GitHub hook trigger for GIscm polling**。
3. 「流水线」选择 **Pipeline script from SCM**。
4. SCM 选择 **Git**，填入仓库地址；私有仓库配置 Deploy Key 或 Personal Access Token。
5. 分支保持 `*/main`，脚本路径保持 `Jenkinsfile`。
6. 保存后先手动「立即构建」验证。

## 4. Webhook

在 GitHub 仓库的 `Settings → Webhooks → Add webhook` 中：

- Payload URL：`http://<JENKINS地址>/github-webhook/`
- Content type：`application/json`
- 事件：`Just the push event` 或 `Let me select → Pull requests + Pushes`

若 Jenkins 位于内网，可使用 frp、Tailscale、Zerotier 等安全方案暴露 webhook 端点，不要直接开放 Jenkins 管理界面。

## 5. 学习与扩展路线

1. 加入 JaCoCo 测试覆盖率报告。
2. 将镜像推送到 GitHub Container Registry。
3. 增加 `develop` 分支 PR 自动构建，只有 `main` 分支执行部署。
4. 引入 SonarQube 静态扫描。
5. 将应用拆分为多个微服务，使用 Docker Compose。
6. 使用 Ansible 部署到另一台主机。
7. 迁移到 Kubernetes/Minikube，实现滚动更新和回滚。
8. 加入 Prometheus、Grafana 和 Alertmanager。
9. 加入 Trivy 镜像漏洞扫描与 cosign 镜像签名。
10. 引入 GitOps：Argo CD/Flux 监听镜像版本变化并自动同步。

建议不要一次做完全部内容，而是每完成一项提交一个可验证版本。
