# GitHub 推送凭证（本地使用，勿提交）

**正确做法**：在项目根目录创建 `.github-token`（一行 token，已在 .gitignore）。

**错误做法**：不要把 token 写在 `docs/1111`、README 或任何会被提交的文件里。

Classic Token 权限：`repo` + `workflow`（推送 CI 配置需要）。

安装 wxyyds **不需要** GitHub Token。
