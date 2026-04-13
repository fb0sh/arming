# ⚔️ Arming

> 一个专为网络安全研究员和 CTF 战队打造的极简 Git 军火库管理工具。

Arming 是一个轻量级、无依赖、纯 POSIX 兼容的 Shell 脚本。它通过自动识别输入输出流，实现了对本地 Git 仓库集群的**一键导出**、**并行浅克隆**和**全量同步**，特别适合用于管理庞大的漏洞复现环境、CTF 题库或学术文献库。

---

## ✨ 核心特性

- **智能模式感知**: 无需记忆复杂的命令行参数，通过管道（Pipe）和重定向（Redirect）自动推断用户意图。
- **纯净输出**: 严格分离 `stdout` 和 `stderr`。运行日志和进度提示带高亮色彩，而导出的数据文件保持绝对纯净，无任何 ANSI 污染。
- **视觉友好**: 专为浅色终端（Light Mode）优化的 ANSI 配色方案，内置进度预告与视觉分隔线，减轻长期面对代码墙的视觉疲劳。
- **零依赖**: 纯 Shell 编写，仅依赖系统自带的 `git`，在 macOS (Apple Silicon) 和各种 Linux 发行版上开箱即用。

---

## 📥 安装指南

将脚本下载到本地并赋予执行权限即可：

```bash
# 下载脚本 (假设已经在目标目录下)
curl -O https://raw.githubusercontent.com/fb0sh/arming/main/arming.sh

# 赋予执行权限
chmod +x arming.sh
```

*(推荐将其加入到系统的 `PATH` 中，或者在 `.zshrc` 中设置 alias 以便全局调用。)*

-----

## 🛠️ 使用说明

Arming 仅需一个参数：`<目标目录>`。它会根据你的操作符（`>`,`<`）自动决定执行哪种模式。

### 1\. 导出模式 (Export)

扫描指定目录下的所有子目录，提取存在的 Git 远程仓库地址，并自动生成安全的目录命名。

```bash
./arming.sh ~/Sec-Tools > weapons.list
```

  * **效果**: 终端会显示彩色的扫描进度，而 `weapons.list` 中会干净地保存形如 `https://github.com/user/repo.git repo_user` 的纯文本列表。\*

### 2\. 克隆模式 (Clone - 并行部署)

读取清单文件，在目标目录中**并行**执行浅克隆 (`git clone --depth 1`)。

```bash
./arming.sh ~/New-Workspace < weapons.list
```

  * **效果**: 自动跳过已存在的目录，极大节省硬盘空间和克隆时间。开始前会预告总任务数。\*

### 3\. 更新模式 (Update)

遍历指定目录下的所有 Git 仓库，执行 `git pull --ff-only` 将它们同步至最新状态。

```bash
./arming.sh ~/Sec-Tools
```

  * **效果**: 自动跳过非 Git 目录，并在每个仓库更新时提供清晰的视觉分隔线。\*

-----

## ⚙️ 高级配置

如果需要调整并发数量或配色方案，可以直接使用文本编辑器打开 `arming.sh` 修改头部变量：

```bash
# 修改此数字以调整克隆时的最大并发数 (默认暂未启用，可自行扩展 wait 逻辑)
max_jobs=5 
```

-----

##  作者与贡献

  - **Author**: fb0sh
  - **Team**: FloatCTF

欢迎提交 Issue 或 Pull Request 来改进此脚本。

##  许可证

本项目采用 [MIT License](https://www.google.com/search?q=LICENSE) 开源协议。
