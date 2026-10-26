# BnsMacroThemes

李慕玄取色宏的公开主题资源仓库。

## 目录结构

- `themes/yijianqingxin/`：一见倾心过图主题
- `themes/qiyue-huashang/`：绮月华裳过图主题
- `themes/xian-ni/`：仙逆过图主题
- `themes/catalog.json`：客户端使用的主题目录
- `themes/*/manifest.json`：每个主题的文件列表、校验值及版本信息
- `published-versions.json`：已经正式发布的目录及主题版本基线

客户端只会在用户启用过图美化并选择在线主题后下载对应资源，并在应用前校验文件完整性。

## 更新清单

运行 `generate-all-theme-manifests.bat` 会重新计算全部图片的 SHA-256。

- 图片尚未正式发布时，目录和主题始终使用“已发布版本 + 1”，重复修改、重复运行不会继续递增。
- 正式发布完成后，运行 `powershell -ExecutionPolicy Bypass -File .\generate-all-theme-manifests.ps1 -MarkPublished`，把当前版本记录为新的已发布基线。
- `-NoVersionBump` 只重算清单，不调整任何版本号。
