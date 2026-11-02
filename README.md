# BnsMacroThemes

李慕玄取色宏的在线过图主题资源仓库。仓库保存主题图片、客户端目录、逐文件 SHA-256 清单和已发布版本基线，不包含主程序代码。

主程序只有在用户启用过图美化、打开在线主题列表并主动选择下载时，才会读取本仓库资源。下载完成后仍需在工具窗口中应用；资源下载成功不等于已经修改游戏文件。

## 当前主题

| 主题 | ID | 图片数 | 清单版本 | 简介 |
| --- | --- | ---: | ---: | --- |
| 一见倾心 | `yijianqingxin` | 12 | 5 | 十二张唯美过图图片 |
| 仙逆 | `xian-ni` | 24 | 2 | 王林与仙逆群像主题 |
| 绮月华裳 | `qiyue-huashang` | 24 | 2 | 绮月华裳成熟性感主题 |
| 绮境芳华 | `qijing-fanghua` | 24 | 1 | 二十四张东方奇幻电影感成熟华裳主题 |

表格内容与 `themes/catalog.json` 对应。客户端以目录和各主题的 `manifest.json` 为准，不应从 README 推断资源版本。

## 客户端使用方式

1. 客户端读取 [`themes/catalog.json`](themes/catalog.json)，获得主题 ID、名称、版本、图片数和清单路径。
2. 用户选择下载后，客户端读取对应主题的 `manifest.json`。
3. 图片下载到本地缓存后，客户端逐文件校验 SHA-256。
4. 校验通过的主题可在过图设置中预览和应用；缓存与已应用到游戏目录的文件是两个独立状态。

当前客户端限制单个主题 1–25 张 JPG，单张不超过 16 MB，主题总大小不超过 64 MB。仓库清单生成脚本同样会检查图片数量。

## 目录结构

```text
themes/
├─ catalog.json                 客户端读取的主题目录
├─ yijianqingxin/
├─ xian-ni/
├─ qiyue-huashang/
└─ qijing-fanghua/
   ├─ manifest.json             主题 ID、名称、版本及文件 SHA-256
   └─ scene-*.jpg               按名称排序的过图图片
published-versions.json         已正式发布的目录与主题版本基线
generate-all-theme-manifests.*  清单生成入口
```

每个主题目录必须包含一个有效的 `manifest.json` 和 1–25 张 `.jpg` 图片。清单中的文件名和 URL 均为主题目录内的相对文件名。

## 添加或更新主题

1. 在 `themes/` 下创建主题目录，加入按顺序命名的 JPG 图片。
2. 创建 `manifest.json`，填写唯一的 `id`、显示名称和当前版本。
3. 在 `themes/catalog.json` 中补充主题名称、简介和清单相对路径；新主题会在重新生成时追加到现有目录顺序之后。
4. 运行清单生成脚本，检查图片数并重新计算全部 SHA-256。
5. 复核 `catalog.json`、主题清单、图片顺序和客户端预览后，再提交发布。

```powershell
# 重新计算清单；内容变化时占用“已发布版本 + 1”
.\generate-all-theme-manifests.ps1

# 只重算清单，不调整版本
.\generate-all-theme-manifests.ps1 -NoVersionBump

# 发布确认后，把当前目录和主题版本写入发布基线
.\generate-all-theme-manifests.ps1 -MarkPublished
```

也可以双击 `generate-all-theme-manifests.bat` 执行默认生成流程。

## 版本规则

- 图片内容变化时，主题版本使用“已发布版本 + 1”。未发布期间重复修改、重复生成不会连续累加版本。
- 目录内容变化时，目录版本采用相同规则。
- `-MarkPublished` 会把当前目录及全部主题版本写入 `published-versions.json`，应只在正式发布确认后执行。
- `-NoVersionBump` 与 `-MarkPublished` 不能同时使用。
- 删除主题目录后重新生成清单，会将对应项目从目录中移除；执行前应确认客户端兼容和缓存处理。

## 相关仓库

- [`restoflife/BnsMacro`](https://github.com/restoflife/BnsMacro)：读取本仓库目录、下载并校验主题的主程序。
- [`restoflife/limuxuan-update`](https://github.com/restoflife/limuxuan-update)：主程序正式版本附件。
