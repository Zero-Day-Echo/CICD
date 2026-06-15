# CICD（Builder 子模块）

AIExamPlatform 的 CI/CD 构建子模块（远端仓库：[Zero-Day-Echo/CICD](https://github.com/Zero-Day-Echo/CICD)）：按 **Git tag** 触发单个子项目的 `docker build`，导出镜像为 `tar.gz` 并上传到阿里云 OSS。

## Tag 规则

```
{子项目 key}-{版本}
```

| Git tag | 构建目录 | 镜像 tag | OSS 对象示例 |
|---------|----------|----------|----------------|
| `appbackend-v0615` | `AppBackend/` | `appbackend:v0615` | `aiexam/docker-images/appbackend/v0615/appbackend-v0615.tar.gz` |
| `agentapi-v1.2.0` | `AgentAPI/` | `agentapi:v1.2.0` | `.../agentapi/v1.2.0/agentapi-v1.2.0.tar.gz` |
| `mcp-llm-wiki-v0615` | `MCPs/LLM_wiki/` | `mcp-llm-wiki:v0615` | `.../mcp-llm-wiki/v0615/...` |

子项目列表见 [`projects.json`](./projects.json)。

## 作为 Git 子模块

Monorepo 根目录挂载路径为 `Builder/`，远端为 **CICD** 仓库：

```bash
# 首次克隆 monorepo 后
git submodule update --init Builder

# 或单独添加（仓库管理员）
git submodule add git@github.com:Zero-Day-Echo/CICD.git Builder
```

Tag 打在 **monorepo** 上；根目录 [`.github/workflows/tag-release.yml`](../.github/workflows/tag-release.yml) 会 checkout 子模块并调用 `Builder/scripts/release.sh`。

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

| Secret | 说明 |
|--------|------|
| `OSS_ENDPOINT` | 如 `oss-cn-hangzhou.aliyuncs.com` |
| `OSS_BUCKET` | Bucket 名称 |
| `OSS_ACCESS_KEY_ID` | RAM AccessKey |
| `OSS_ACCESS_KEY_SECRET` | RAM Secret |
| `OSS_PREFIX` | 可选，默认 `aiexam/docker-images` |
