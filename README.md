# my-shell

个人 Shell 配置仓库，目前包含适用于 Linux、macOS 和 WSL 的模块化 Zsh 配置。

## Zsh 配置

- **提示符**：Starship Pastel Powerline Preset，显示用户名、目录、Git 状态、语言版本和时间。
- **交互体验**：Vi 模式、自动建议、语法高亮、历史子串搜索和大小写不敏感补全。
- **搜索与导航**：可选 fzf 文件及历史搜索、zoxide 目录跳转。
- **常用工具**：按需启用 eza、bat、fd、Neovim 等，并兼容 Ubuntu 的 `batcat`、`fdfind` 命令名。
- **模块化管理**：插件手动安装与更新，启动时不自动下载；机器专属配置放在 `local.zsh` 中。

增强工具未安装时可使用基础配置。PowerShell 不能直接加载这些 Zsh 配置，Windows 用户请在 WSL 中使用。

## 完整安装

查看 [多系统安装指南](docs/install.md)，覆盖 Debian、Ubuntu、Arch Linux、Fedora 和 macOS，包含 btop、jq、tealdeer、git-delta、AstroNvim、Zellij 及 Zsh 插件。共用配置脚本会备份已有设置，不安装 Go。

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
├── scripts/install-config.sh # 用户配置安装脚本
└── zsh/
    ├── .zshenv           # 环境变量与 XDG 路径
    ├── .zshrc            # 主入口、历史与补全
    ├── aliases.zsh       # 常用别名与函数
    ├── bindings.zsh      # 按键绑定
    ├── fzf.zsh           # 模糊搜索
    ├── plugins.zsh       # 插件安装、更新与加载
    ├── prompt.zsh        # Starship 初始化及回退提示符
    ├── starship.toml     # Pastel Powerline 主题
    ├── local.zsh.example # 机器专属配置示例
    └── README.md         # 详细使用说明
```

## 参考与许可

- Zsh 配置参考 [radleylewis/zsh](https://github.com/radleylewis/zsh)，保留其 [MIT 许可](LICENSE)。
- Starship 主题使用官方 [Pastel Powerline Preset](https://starship.rs/presets/pastel-powerline)。
