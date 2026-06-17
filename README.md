# CICD（Builder 子模块）

远端仓库：[Zero-Day-Echo/CICD](https://github.com/Zero-Day-Echo/CICD)

**AIExamPlatform 根仓库没有任何 GitHub Actions 流水线。** 所有 CI/CD 只在本仓库（CICD）运行。

## 流程

1. 业务代码合并进 **AIExamPlatform `main`**
2. 在 **CICD 仓库** 打 tag 并 push（或 Actions 手动 Run）
3. 流水线 checkout **AIExamPlatform@main** 构建镜像
4. 导出 `tar.gz` 上传 OSS
5. **自动清理**该子项目在 OSS 上的旧版本目录（每个子项目只保留本次上传的版本）

## Tag 规则（打在 CICD 仓库）

```
{子项目 key}-{版本}
all-{版本}          # 全量：一次构建 projects.json 中全部镜像（同版本号）
```

### 版本号格式 `v[mmdd][no]`

Docker 镜像 tag（即 tag 中 `-` 后面的 `{版本}` 段）统一采用：

```
v + MM + DD + [序号]
```

| 段 | 含义 | 示例 |
|----|------|------|
| `v` | 固定前缀 | `v` |
| `MM` | 月（两位） | `06` → 6 月 |
| `DD` | 日（两位） | `12` → 12 日 |
| `[序号]` | 可选；**当天第几次编译**，两位起，从 `01` 递增 | `01` → 当天第 1 次 |

**示例**

| 版本号 | 含义 |
|--------|------|
| `v061201` | 6 月 12 日第 **1** 次编译 |
| `v061202` | 6 月 12 日第 **2** 次编译（同日重发、热修复） |
| `v0612` | 合法但**不推荐**（未带序号，无法区分同日多次构建） |

完整 Git tag 示例：`appbackend-v061201`、`all-v061201`。

| CICD Git tag | 源码 | Docker 镜像 tag |
|--------------|------|-----------------|
| `appbackend-v061201` | `AIExamPlatform@main` | `appbackend:v061201` |
| `all-v061201` | `AIExamPlatform@main` | 全部 11 个子项目均为 `:v061201` |
| `agentapi-v061202` | `AIExamPlatform@main` | `agentapi:v061202` |

Tag 名**不**用于 checkout，只用于：触发流水线、解析子项目、打 Docker 镜像版本。

子项目列表见 [`projects.json`](./projects.json)。

### 全量发布 `all-v****`

适用于日志格式统一、依赖升级等需要**同时重建全部镜像**的场景：

```bash
cd CICD
git tag all-v061201
git push origin all-v061201
```

或在 Actions 手动 Run，填写 `tag=all-v061201`。

流水线会并行构建（最多 4 路）全部子项目，并分别上传 OSS。节点导入：

```bash
./k8s/scripts/import-image-from-url.sh all v061201
IMAGE_TAG=v061201 ./k8s/scripts/deploy-local-images-v0617.sh
```

## 触发方式

### 方式 A：在 CICD 仓库打 tag（推荐）

```bash
git clone git@github.com:Zero-Day-Echo/CICD.git
cd CICD
git tag appbackend-v061201
git push origin appbackend-v061201
```

### 方式 B：CICD → Actions → Run workflow

手动填写 `tag`（如 `appbackend-v061201`），无需真的创建 Git tag。

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
SKIP_UPLOAD=1 ./Builder/scripts/release.sh appbackend-v061201
SKIP_UPLOAD=1 ./Builder/scripts/release.sh all-v061201   # 全量（耗时较长）
SKIP_UPLOAD=1 ./Builder/scripts/release.sh managefront-v061703
```

本地 `release.sh` 与 CICD 流水线 `tag-release.yml` 均从 `projects.json` 读取 `build_args`（managefront 的 `VITE_*` 域名在此配置）。

### ManageFront 生产 API 域名

`VITE_*` 在 **docker build** 时编译进静态 JS，运行时改 K8s ConfigMap 无效。流水线构建 managefront 时会自动传入 `projects.json` → `managefront.build_args`；同时 `ManageFront/.env.production` 作为兜底。

改域名时同步：`ManageFront/.env.production`、`projects.json`（`build_args`）、`k8s/configmap-common.yaml`（对照文档），然后在 **CICD** 打 tag 重编 managefront。

## GitHub Secrets（仅配置在 CICD 仓库）

| Secret | 必填 | 说明 |
|--------|------|------|
| `GH_SECRET` | 是 | PAT，Contents 读权限，可访问 `AIExamPlatform` 及子模块 |
| `OSS_ENDPOINT` | 是 | 如 `oss-cn-hangzhou.aliyuncs.com` |
| `OSS_BUCKET` | 是 | Bucket 名称 |
| `OSS_ACCESS_KEY_ID` | 是 | RAM AccessKey |
| `OSS_ACCESS_KEY_SECRET` | 是 | RAM Secret |
| `OSS_PREFIX` | 否 | 默认 `aiexam/docker-images` |
| `OSS_CLEANUP_OLD` | 否 | 上传后删除同子项目其它版本目录，默认 `1`；本地保留历史可设 `0` |

上传路径：`{OSS_PREFIX}/{project}/{version}/{project}-{version}.tar.gz`  
清理规则：上传成功后删除 `{OSS_PREFIX}/{project}/` 下除当前 `version` 外的所有 `v*` 目录。

## 新增子项目

编辑 `projects.json`，发布时在 **CICD** 打 tag：`my-service-v061201`（版本号见上文 `v[mmdd][no]`）。
