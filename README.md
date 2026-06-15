# CICD（Builder 子模块）

远端仓库：[Zero-Day-Echo/CICD](https://github.com/Zero-Day-Echo/CICD)

**AIExamPlatform 根仓库没有任何 GitHub Actions 流水线。** 所有 CI/CD 只在本仓库（CICD）运行。

## 流程

1. 业务代码合并进 **AIExamPlatform `main`**
2. 在 **CICD 仓库** 打 tag 并 push（或 Actions 手动 Run）
3. 流水线 checkout **AIExamPlatform@main** 构建镜像
4. 导出 `tar.gz` 上传 OSS

## Tag 规则（打在 CICD 仓库）

```
{子项目 key}-{版本}
```

| CICD Git tag | 源码 | Docker 镜像 tag |
|--------------|------|-----------------|
| `appbackend-v0616` | `AIExamPlatform@main` | `appbackend:v0616` |
| `agentapi-v1.2.0` | `AIExamPlatform@main` | `agentapi:v1.2.0` |

Tag 名**不**用于 checkout，只用于：触发流水线、解析子项目、打 Docker 镜像版本。

子项目列表见 [`projects.json`](./projects.json)。

## 触发方式

### 方式 A：在 CICD 仓库打 tag（推荐）

```bash
git clone git@github.com:Zero-Day-Echo/CICD.git
cd CICD
git tag appbackend-v0616
git push origin appbackend-v0616
```

### 方式 B：CICD → Actions → Run workflow

手动填写 `tag`（如 `appbackend-v0616`），无需真的创建 Git tag。

## 流水线位置

仅 **CICD** 仓库：

```
.github/workflows/tag-release.yml
```

## 作为 monorepo 子模块

```bash
git submodule update --init Builder
```

本地脚本在 `Builder/scripts/`；Actions 定义在远端 CICD 仓库。

## 本地试跑

```bash
cd AIExamPlatform
SKIP_UPLOAD=1 ./Builder/scripts/release.sh appbackend-v0616
```

## GitHub Secrets（仅配置在 CICD 仓库）

| Secret | 必填 | 说明 |
|--------|------|------|
| `GH_SECRET` | 是 | PAT，Contents 读权限，可访问 `AIExamPlatform` 及子模块 |
| `OSS_ENDPOINT` | 是 | 如 `oss-cn-hangzhou.aliyuncs.com` |
| `OSS_BUCKET` | 是 | Bucket 名称 |
| `OSS_ACCESS_KEY_ID` | 是 | RAM AccessKey |
| `OSS_ACCESS_KEY_SECRET` | 是 | RAM Secret |
| `OSS_PREFIX` | 否 | 默认 `aiexam/docker-images` |

## 新增子项目

编辑 `projects.json`，发布时在 **CICD** 打 tag：`my-service-v0615`。
