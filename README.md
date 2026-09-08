# my-shell

个人 Shell 配置仓库，包含适用于 Linux、macOS 和 WSL 的模块化 Zsh 与 Fish 配置。

## Fish 配置

新增 [Fish 安装与使用说明](fish/README.md)，参照 Zsh 的主题与工具体验。安装器查询 Fish 和 zoxide 官方最新稳定版（Linux/macOS，x86_64/ARM64），保留已有 Zsh 配置。

```sh
bash scripts/install-fish-config.sh
exec "$HOME/.local/bin/fish"
```

已安装 Fish 4+、只更新配置、跳过 Fish/zoxide 下载时使用 `--config-only`。Fish 内的 `shell-update` 操作 Fish 配置；自动建议、语法高亮、补全和 Vi 模式使用内置功能。完整工具选项与恢复步骤见 Fish 说明。

## Zsh 配置

- **提示符**：Starship Pastel Powerline Preset，显示用户名、目录、Git 状态、语言版本和时间。
- **交互体验**：Vi 模式、自动建议、语法高亮、历史子串搜索和大小写不敏感补全。
- **搜索与导航**：可选 fzf 文件及历史搜索、zoxide 目录跳转。
- **常用工具**：按需启用 eza、bat、fd、Neovim 等，并兼容 Ubuntu 的 `batcat`、`fdfind` 命令名。
- **模块化管理**：插件手动安装与更新，启动时不自动下载；机器专属配置放在 `local.zsh` 中。

增强工具未安装时可使用基础配置。PowerShell 不能直接加载这些 Zsh 配置，Windows 用户请在 WSL 中使用。

## 完整安装

查看 [多系统安装指南](docs/install.md)，覆盖 Debian、Ubuntu、Arch Linux、Fedora 和 macOS，包含 btop、jq、tealdeer、git-delta、AstroNvim、Zellij、Yazi 及 Zsh 插件。共用配置脚本会备份已有设置；`--astronvim` / `--zellij` / `--yazi` 会从 GitHub 安装 Neovim / Zellij / Yazi 最新稳定版，不安装 Go。

Yazi 视频、PDF、SVG 和压缩包预览依赖（ffmpeg、Poppler、resvg、7-Zip）的多系统安装及服务器补装命令见 [预览依赖](docs/install.md#补齐-yazi-预览依赖)。这些依赖使用系统包管理器安装。

旧版 tldr 缓存更新失败时，可用 `bash scripts/install-config.sh --tealdeer` 安装官方最新稳定版；然后 `exec zsh`、`tldr --update`。后续由 `shell-update tools tealdeer` 更新。

zoxide 也使用官方最新稳定版安装器：`bash scripts/install-zoxide.sh`，后续 `shell-update tools zoxide`。

## 检查与更新

加载新配置后使用 shell-doctor 检查当前会话；shell-update config、shell-update plugins、shell-update tools 分别更新配置、插件和已安装工具。shell-update all 按顺序更新，工具版本一致时跳过安装包下载。详见 [维护与恢复指南](docs/maintenance.md)。GitHub Actions 会在提交推送和 PR 时运行 Linux/macOS 检查。

## 快速试用

先在目标系统安装 Zsh 和 Git，然后在 Bash 或 Zsh 中执行：

```sh
git clone https://github.com/LazyFaiz/my-shell.git
cd my-shell/zsh
ZDOTDIR="$PWD" zsh
```

如需完整主题，请安装 Starship，并在终端中启用 Nerd Font，例如 Caskaydia Cove Nerd Font。

进入新启动的 Zsh 后，可安装交互增强插件：

```sh
zplugin-install
exec zsh
```

试用结束后执行 `exit` 返回原来的 Shell。永久安装、依赖说明、快捷键、自定义设置及恢复方式见 **[Zsh 使用说明](zsh/README.md)**。

## 目录结构

```text
.
├── README.md
├── LICENSE               # MIT 许可（保留上游版权声明）
├── docs/install.md       # 多系统依赖、安装与恢复说明
├── docs/maintenance.md   # 检查、分类更新与故障恢复
├── scripts/install-config.sh # 用户配置安装脚本
├── scripts/install-neovim.sh # GitHub 最新稳定版 Neovim
├── scripts/install-zellij.sh # GitHub 最新稳定版 Zellij
├── scripts/install-yazi.sh   # GitHub 最新稳定版 Yazi + ya
├── scripts/install-tealdeer.sh # GitHub 最新稳定版 tldr
├── scripts/install-zoxide.sh # GitHub 最新稳定版 zoxide
├── fish/                # 原生 Fish 模块、同款 Starship 主题与中文说明
└── zsh/
    ├── .zshenv           # 环境变量与 XDG 路径
    ├── .zshrc            # 主入口、历史与补全
    ├── aliases.zsh       # 常用别名与函数
    ├── bindings.zsh      # 按键绑定
    ├── fzf.zsh           # 模糊搜索
    ├── plugins.zsh       # 插件安装、更新与加载
    ├── maintenance.zsh   # shell-doctor / shell-update
    ├── prompt.zsh        # Starship 初始化及回退提示符
    ├── starship.toml     # Pastel Powerline 主题
    ├── local.zsh.example # 机器专属配置示例
    └── README.md         # 详细使用说明
```

## 参考与许可

- Zsh 配置参考 [radleylewis/zsh](https://github.com/radleylewis/zsh)，保留其 [MIT 许可](LICENSE)。
- Starship 主题使用官方 [Pastel Powerline Preset](https://starship.rs/presets/pastel-powerline)。
