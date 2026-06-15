# CICD（Builder 子模块）

AIExamPlatform 的 CI/CD 构建子模块（远端仓库：[Zero-Day-Echo/CICD](https://github.com/Zero-Day-Echo/CICD)）：按 **Git tag** 触发单个子项目的 `docker build`，导出镜像为 `tar.gz` 并上传到阿里云 OSS。

## Tag 规则

```
{子项目 key}-{版本}
```

**Git tag / 手动输入的 tag 名只用于：**

1. **触发**流水线（monorepo push tag）
2. 解析**构建哪个子项目**（`appbackend` → `AppBackend/`）
3. **Docker 镜像 tag**（`appbackend-v0615` → `appbackend:v0615`）

**源码 checkout 固定拉 monorepo 的 `main` 分支**（手动 dispatch 可改 `monorepo_ref`，默认 `main`）。  
不会、也不应按该 Git tag 去 checkout 代码。

| Git tag | 构建目录 | 镜像 tag | OSS 对象示例 |
|---------|----------|----------|----------------|
| `appbackend-v0615` | `AppBackend/` | `appbackend:v0615` | `aiexam/docker-images/appbackend/v0615/appbackend-v0615.tar.gz` |
| `agentapi-v1.2.0` | `AgentAPI/` | `agentapi:v1.2.0` | `.../agentapi/v1.2.0/agentapi-v1.2.0.tar.gz` |
| `mcp-llm-wiki-v0615` | `MCPs/LLM_wiki/` | `mcp-llm-wiki:v0615` | `.../mcp-llm-wiki/v0615/...` |

子项目列表见 [`projects.json`](./projects.json)。

## 流水线位置

| 仓库 | 路径 | 作用 |
|------|------|------|
| **[Zero-Day-Echo/CICD](https://github.com/Zero-Day-Echo/CICD)** | `.github/workflows/tag-release.yml` | **主构建流水线**（docker build → tar.gz → OSS） |
| **AIExamPlatform（monorepo）** | `.github/workflows/tag-release.yml` | **触发器**：push tag 时调用 CICD 可复用 workflow |

在 GitHub 上打开 CICD 仓库即可看到 Actions 流水线；也支持在 CICD 仓库 **Actions → Run workflow** 手动填写 tag 试跑。

Tag 打在 **monorepo** 上（例如 `appbackend-v0615`），触发 monorepo workflow → 调用 `Zero-Day-Echo/CICD/.github/workflows/tag-release.yml@main` → 用 `GH_SECRET` checkout 私有根库及子模块后构建。

## 作为 Git 子模块

Monorepo 根目录挂载路径为 `Builder/`，远端为 **CICD** 仓库：

```bash
# 首次克隆 monorepo 后
git submodule update --init Builder

# 或单独添加（仓库管理员）
git submodule add git@github.com:Zero-Day-Echo/CICD.git Builder
```

本地脚本与配置在本目录；**GitHub Actions 定义在同名远端仓库** `Zero-Day-Echo/CICD` 的 `.github/workflows/` 下。

## 本地试跑

```bash
# 仅构建 + 导出（不上传）
SKIP_UPLOAD=1 ./Builder/scripts/release.sh appbackend-v0615

# 构建并上传 OSS
export OSS_ENDPOINT=oss-cn-hangzhou.aliyuncs.com
export OSS_BUCKET=your-bucket
export OSS_ACCESS_KEY_ID=...
export OSS_ACCESS_KEY_SECRET=...
./Builder/scripts/release.sh appbackend-v0615
```

产物默认在 `Builder/dist/`。

## 新增子项目

编辑 `projects.json` 增加一项，key 与 tag 前缀一致，例如：

```json
"my-service": {
  "context": "MyService",
  "dockerfile": "Dockerfile",
  "image": "my-service"
}
```

发布时打 tag：`my-service-v0615`。

## GitHub Actions Secrets

在 **monorepo（AIExamPlatform）** 与 **CICD** 仓库均可配置（`secrets: inherit` 时以 monorepo 为准；手动在 CICD dispatch 时在 CICD 仓库配置）：

| Secret | 必填 | 说明 |
|--------|------|------|
| `GH_SECRET` | **是** | GitHub PAT（classic: `repo`；或 fine-grained：对本 org 下私有仓库只读）。用于 checkout 私有根库及子模块 `Builder`（CICD）、`questionagent` 等 |
| `OSS_ENDPOINT` | 是 | 如 `oss-cn-hangzhou.aliyuncs.com` |
| `OSS_BUCKET` | 是 | Bucket 名称 |
| `OSS_ACCESS_KEY_ID` | 是 | RAM AccessKey |
| `OSS_ACCESS_KEY_SECRET` | 是 | RAM Secret |
| `OSS_PREFIX` | 否 | 默认 `aiexam/docker-images` |

### GH_SECRET 说明

Workflow 跑在 monorepo 上（tag 触发），但 `actions/checkout` 开启 `submodules: recursive` 时，**默认 `GITHUB_TOKEN` 不能访问其他私有仓库**。因此需用组织/个人 PAT 写入 `GH_SECRET`：

1. GitHub → Settings → Developer settings → Personal access tokens
2. 勾选 `repo`（classic）或对 `Zero-Day-Echo/AIExamPlatform`、`Zero-Day-Echo/CICD` 等授予 Contents: Read
3. 在 monorepo 添加 Secret 名称 **`GH_SECRET`**，值为该 PAT

若根库与子模块均为 public，可去掉 workflow 中的 `GH_SECRET` 校验并改回默认 token（当前按私有仓库配置）。
