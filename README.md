# S3 Compose (AutoBackup S3)

一个轻量级的 Docker 容器，用于将数据自动备份到任何兼容 S3 的存储服务（AWS S3, Cloudflare R2, MinIO, Aliyun OSS 等），并支持自动轮换和保留策略。

## 功能特性

- **S3 兼容**: 适用于任何兼容 S3 协议的存储提供商。
- **自动轮换**: 根据 `RETENTION_DAYS` 设置自动删除过期的旧备份。
- **定时任务**: 内置 Cron 调度程序，支持自定义备份周期。
- **高性能**: 使用 `s5cmd` 进行极速并发上传。
- **灵活配置**: 支持文件排除模式、自定义 S3 端点和项目命名。

## 使用方法

### Docker Compose

1. 创建一个 `.env` 文件来存储你的凭证（**切勿**将此文件提交到代码仓库）：
   ```ini
   AWS_ACCESS_KEY_ID=your_key_id
   AWS_SECRET_ACCESS_KEY=your_secret_key
   S3_ENDPOINT=https://<account_id>.r2.cloudflarestorage.com
   S3_BUCKET=my-backup-bucket
   ```

2. 使用提供的 `compose.yml` 启动容器：
   ```bash
   docker compose up -d
   ```

### 集成到现有 Docker Compose 项目

如果你想将备份服务添加到现有的 docker compose 项目中，只需将以下服务定义添加到你的 `compose.yml` 文件中：

```yaml
services:
  # 你的其他服务...
  web:
    image: nginx
    volumes:
      - ./data:/var/www/html

  # 添加备份服务
  backup:
    image: ghcr.io/yumusb/s3-compose:main
    environment:
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - S3_BUCKET=${S3_BUCKET}
      - S3_ENDPOINT=${S3_ENDPOINT}
      - S3_REGION=${S3_REGION:-auto}
      - PROJECT_NAME=${COMPOSE_PROJECT_NAME:-my-project}
      - CRON_SCHEDULE=0 3 * * *
    volumes:
      # 挂载你想备份的目录 (例如 web 服务的 data)
      # 注意：这里的 ./data 应该对应你想要备份的主机目录
      - ./data:/data
    restart: unless-stopped
```

### 环境变量说明

| 变量名 | 描述 | 默认值 |
|--------|------|--------|
| `AWS_ACCESS_KEY_ID` | S3 Access Key ID (必需) | - |
| `AWS_SECRET_ACCESS_KEY` | S3 Secret Access Key (必需) | - |
| `S3_BUCKET` | 目标 S3 存储桶名称 (必需) | - |
| `S3_ENDPOINT` | 自定义 S3 端点 (R2, MinIO 等必需) | - |
| `S3_REGION` | S3 区域 | `auto` |
| `PROJECT_NAME` | 备份文件的子目录名称 | `my-app-backup` |
| `CRON_SCHEDULE` | Cron 调度表达式 | `0 3 * * *` (每天凌晨 3 点) |
| `RETENTION_DAYS` | 备份保留天数 | `30` |
| `EXCLUDE_PATTERNS` | 要排除的文件模式（逗号分隔） | `*.log,*.tmp,vmdata` |
| `RUN_ON_START` | 容器启动时是否立即执行一次备份 | `true` |

## 数据卷 (Volumes)

将你需要备份的数据目录挂载到容器内的 `/data` 目录：

```yaml
volumes:
  - ./your-data:/data
```

## 许可证

MIT
