# Spring Boot Jenkins DevOps 示例

这是一个用于练习基础 CI/CD 流程的 Spring Boot 项目。Jenkins 从 Git 仓库检出代码，运行 Maven 构建和测试，构建 Docker 镜像并推送到 Harbor，最后通过 SSH 在部署主机上调用 `deploy.sh` 更新应用。

## 项目组成

- **Spring Boot**：提供简单的 HTTP 接口和 Actuator 健康检查。
- **Maven**：管理依赖、运行测试并打包应用。
- **Docker**：将应用打包为镜像。
- **Harbor**：保存构建好的应用镜像。
- **Jenkins**：按 `Jenkinsfile` 编排构建、推送和部署。
- **部署主机**：通过 `deploy.sh` 拉取镜像并启动容器。

流水线顺序：

```text
Git 仓库 → Maven 构建与测试 → Docker 构建镜像 → 推送 Harbor
         → SSH 到部署主机 → deploy.sh 拉取并启动镜像 → 健康检查
```

## 本地运行

需要安装 JDK 17 或更高版本及 Maven。

```bash
mvn clean package
java -jar target/spring-boot-jenkins-devops-0.0.1-SNAPSHOT.jar
```

应用启动后可访问：

```bash
curl http://localhost:8090/api/hello
curl http://localhost:8090/actuator/health
```

## Jenkins 流水线配置

### Jenkins 执行环境

Jenkins 节点需要具备以下工具和权限：

- Git、JDK 17 或更高版本、Maven。
- Docker CLI，并且 Jenkins 能访问 Docker daemon。
- SSH 客户端和 `ssh-agent` 插件。
- 能访问 Git 仓库、Harbor 和部署主机的网络。

Harbor 当前地址为 `192.168.128.41:80`，使用 HTTP。若 Docker daemon 尚未允许访问该 HTTP registry，需要在**运行 Docker daemon 的主机**配置 `/etc/docker/daemon.json`，然后重启 Docker：

```json
{
  "insecure-registries": ["192.168.128.41:80"]
}
```

Harbor 中需预先创建项目 `devops`。

### Jenkins 凭据

在 Jenkins 的 **Manage Jenkins → Credentials** 中添加：

1. SSH 私钥凭据，ID 为 `k8s-master-ssh`，用于连接 `root@192.168.128.41`。
2. Harbor 用户名/密码凭据。将该凭据 ID 填入 `Jenkinsfile` 的 `HARBOR_CRED_ID`，避免使用文件中的演示账号密码。

部署主机需要安装 Docker，并满足以下条件：

- `/usr/bin/deploy.sh` 存在且可执行。
- Jenkins 配置的 SSH 私钥可以登录该主机。
- 部署脚本可使用传入的 Harbor 地址、项目名、镜像名、版本和端口拉取镜像并启动容器。

### 创建 Pipeline 任务

1. 在 Jenkins 中新建 **Pipeline** 任务。
2. 在 **Pipeline** 中选择 **Pipeline script from SCM**。
3. SCM 选择 Git，填入项目仓库地址；私有仓库需配置相应的 Git 凭据。
4. 分支指定为 `*/main`，脚本路径设为 `Jenkinsfile`。
5. 保存后先手动执行一次构建，检查控制台输出和部署结果。

需要自动触发时，在 GitHub 仓库的 **Settings → Webhooks** 添加 Webhook：

- Payload URL：`http://<JENKINS地址>/github-webhook/`
- Content type：`application/json`
- 事件：`Just the push event`

仅将 Webhook 所需入口开放给 GitHub；不要直接将 Jenkins 管理界面暴露到公网。

## 当前镜像与部署参数

参数在 `Jenkinsfile` 的 `environment` 中维护：

| 参数 | 当前值 | 用途 |
| --- | --- | --- |
| Harbor 地址 | `192.168.128.41:80` | 镜像仓库地址 |
| Harbor 项目 | `devops` | 镜像所在项目 |
| 镜像名称 | `spring-boot-jenkins-devops` | 应用镜像名称 |
| 镜像版本 | `v1.0.0` | 推送和部署使用的标签 |
| 应用端口 | `8090` | 应用及容器映射端口 |
| 部署主机 | `192.168.128.41` | SSH 部署目标 |
| 部署脚本 | `/usr/bin/deploy.sh` | 远端拉取镜像并启动容器的脚本 |

当前镜像完整名称为：

```text
192.168.128.41:80/devops/spring-boot-jenkins-devops:v1.0.0
```

流水线在远端脚本执行后会检查 `http://localhost:8090/actuator/health`，并从 Jenkins 节点访问 `http://192.168.128.41:8090/api/hello`。若修改镜像名、标签、端口或主机地址，请同步检查部署脚本和网络配置。

## 常见问题

- **Docker 推送 Harbor 失败**：检查 Harbor 地址与项目是否正确，并确认 Docker daemon 已配置 HTTP registry。
- **Harbor 登录失败**：检查 Harbor 凭据及 `HARBOR_CRED_ID`，确认 Jenkins 执行节点可以访问 Harbor。
- **SSH 部署失败**：检查 `k8s-master-ssh` 凭据、目标主机连通性，以及远端 `/usr/bin/deploy.sh` 的路径和执行权限。
- **健康检查失败**：在部署主机检查容器状态与日志：`docker ps -a`、`docker logs spring-boot-jenkins-devops`；同时确认 8090 端口未被占用且可访问。
