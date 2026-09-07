# 多系统安装指南

适用：Debian 13、Ubuntu 24.04 及以上、Arch Linux、Fedora、macOS（Homebrew）。WSL 按内部 Linux 发行版选择命令。其他版本的软件源可能缺包；不要混用不同发行版的软件源。以下步骤安装当前用户环境，不安装 Go、Go 工具或 Fish。

## 1. 安装系统依赖

选择自己系统的一组。Linux 普通用户使用 sudo；root 用户去掉 sudo。macOS 的 brew 不要使用 sudo。

### Debian / Ubuntu

Ubuntu 需启用 universe 仓库。先安装工具，Neovim、Zellij、Starship 若版本不适用或无软件包，按下一节的官方方式安装：

```bash
sudo apt update
sudo apt install -y zsh git curl ca-certificates btop jq tealdeer git-delta \
  fzf fd-find bat eza zoxide ripgrep unzip 7zip tar gzip bzip2 xz-utils \
  build-essential
```

Debian 13 可直接安装 Starship：

```bash
sudo apt install -y starship
```

### Arch Linux

```bash
sudo pacman -Syu --needed zsh git curl ca-certificates btop jq tealdeer git-delta \
  fzf fd bat eza zoxide ripgrep unzip 7zip tar gzip bzip2 xz \
  base-devel neovim zellij starship
```

### Fedora

```bash
sudo dnf install -y zsh git curl ca-certificates btop jq tealdeer git-delta \
  fzf fd-find bat eza zoxide ripgrep unzip 7zip tar gzip bzip2 xz \
  gcc gcc-c++ make neovim zellij starship
```

### macOS

先安装 [Homebrew](https://brew.sh/)。编译器来自 Xcode Command Line Tools；没有时执行 `xcode-select --install` 并完成弹窗安装。

```bash
brew install zsh git btop jq tealdeer git-delta fzf fd bat eza zoxide \
  ripgrep unzip sevenzip neovim zellij starship
```

## 2. 检查 Neovim、Zellij、Starship

```bash
nvim --version
zellij --version
starship --version
```

AstroNvim 当前要求 **Neovim 0.11 或以上的稳定版本**、C 编译器和 Tree-sitter CLI。Tree-sitter CLI 可在首次进入 AstroNvim 后通过 Mason 安装。不要仅根据已安装 `neovim` 软件包判断版本足够。

Linux 缺少这些工具时，使用下列官方来源的安装步骤。已有满足要求的版本可以跳过。macOS 使用上面的 Homebrew 命令。

### Linux：安装新版 Neovim

此命令支持 x86_64 / ARM64，下载官方最新稳定版本，安装到当前用户目录。每次安装使用独立目录，旧二进制入口会备份。

```bash
bash <<'BASH'
set -euo pipefail
case "$(uname -m)" in
  x86_64) platform=x86_64 ;;
  aarch64|arm64) platform=arm64 ;;
  *) echo '此步骤仅支持 Linux x86_64 / ARM64'; exit 1 ;;
esac
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
asset="nvim-linux-$platform"
curl -fL --retry 3 "https://github.com/neovim/neovim/releases/latest/download/$asset.tar.gz" -o "$work/nvim.tar.gz"
tar -xzf "$work/nvim.tar.gz" -C "$work"
mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
target=$(mktemp -d "$HOME/.local/opt/nvim-XXXXXXXX")
cp -a "$work/$asset/." "$target/"
"$target/bin/nvim" --version
if [ -e "$HOME/.local/bin/nvim" ] || [ -L "$HOME/.local/bin/nvim" ]; then
  mv "$HOME/.local/bin/nvim" "$HOME/.local/bin/nvim.bak.$(date +%Y%m%d-%H%M%S).$$"
fi
ln -s "$target/bin/nvim" "$HOME/.local/bin/nvim"
BASH
```

### Linux：安装 Zellij

```bash
bash <<'BASH'
set -euo pipefail
case "$(uname -m)" in
  x86_64) platform=x86_64 ;;
  aarch64|arm64) platform=aarch64 ;;
  *) echo '此步骤仅支持 Linux x86_64 / ARM64'; exit 1 ;;
esac
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
curl -fL --retry 3 "https://github.com/zellij-org/zellij/releases/latest/download/zellij-$platform-unknown-linux-musl.tar.gz" -o "$work/zellij.tar.gz"
tar -xzf "$work/zellij.tar.gz" -C "$work"
"$work/zellij" --version
mkdir -p "$HOME/.local/bin"
if [ -e "$HOME/.local/bin/zellij" ] || [ -L "$HOME/.local/bin/zellij" ]; then
  mv "$HOME/.local/bin/zellij" "$HOME/.local/bin/zellij.bak.$(date +%Y%m%d-%H%M%S).$$"
fi
install -m 0755 "$work/zellij" "$HOME/.local/bin/zellij"
BASH
```

### Linux：安装 Starship（软件源没有时）

```bash
bash <<'BASH'
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$HOME/.local/bin"
curl -fsSL https://starship.rs/install.sh -o "$work/install-starship.sh"
sh "$work/install-starship.sh" -y -b "$HOME/.local/bin"
BASH
```

在继续下一步前，让当前 Bash 找到用户目录中的程序：

```bash
export PATH="$HOME/.local/bin:$PATH"
nvim --version
zellij --version
starship --version
```

## 3. 安装仓库配置

在目标账号下运行；root 执行会配置 root，不会配置其他用户。普通用户只在安装系统软件时使用 sudo，以下脚本不加 sudo。

```bash
git clone https://github.com/LazyFaiz/my-shell.git ~/my-shell
cd ~/my-shell
bash scripts/install-config.sh --astronvim --delta
```

已有仓库时进入原目录执行 `git pull --ff-only`，不必重新克隆。

脚本支持 Linux/macOS 自带 Bash，使用现有的 Zsh、Git、Neovim 和 delta，不安装系统软件。它会：

- 备份旧 Zsh 配置、入口文件；更新模块时保留 `local.zsh`。
- 在 `~/.zshenv` 追加一次配置入口，保留原文件内容。
- 使用 `--delta` 时备份 Git 配置，再启用彩色 diff、行号、差异导航；不改 Git 用户名和邮箱。
- 使用 `--astronvim` 时检查 Neovim 版本，克隆官方 AstroNvim 模板；已有 Neovim 配置则跳过。
- 首次安装 AstroNvim 时，将原有 Neovim data/state/cache 目录移到同级 `.bak.时间戳` 目录。

省略两个选项只安装 Zsh 配置。备份位置会在完成后打印，默认在 `~/.local/state/my-shell/backups/`。如果以前设置过自定义 `ZDOTDIR`，需确保 Zsh 实际读取的 `.zshenv` 也包含这里的入口，或先取消旧 `ZDOTDIR` 再启动。

## 4. 安装 Zsh 插件

```bash
zsh
```

进入 Zsh 后执行：

```zsh
zplugin-install
exec zsh
```

共四个插件：自动建议、语法高亮、历史子串搜索和增强 Vi 模式。启动时只加载本地插件，不联网下载。后续更新执行 `zplugin-update` 后重新打开 Zsh。

## 5. 完成 AstroNvim 与工具初始化

```zsh
tldr --update
nvim
```

首次打开 Neovim 会下载 AstroNvim 插件。等待完成后执行：

```vim
:Lazy sync
:Mason
:checkhealth
```

在 Mason 中确认 `tree-sitter-cli` 已安装；没有时安装它，再按 `:checkhealth` 的实际结果处理缺少的依赖。这里不添加任何 Go pack，也不安装 Go 工具链。Node.js、Python 和具体语言服务器按实际编辑需求安装，不是此次默认安装内容。

如果已有 Neovim 配置且想改用 AstroNvim，先退出 Neovim，再备份旧配置并重跑安装脚本：

```bash
mv "${XDG_CONFIG_HOME:-$HOME/.config}/nvim" "${XDG_CONFIG_HOME:-$HOME/.config}/nvim.bak.$(date +%Y%m%d-%H%M%S)"
bash scripts/install-config.sh --astronvim
```

Zellij 手动运行 `zj`，命名会话可用 `za work`，查看会话用 `zl`。不会每次打开 SSH 时自动启动。

请在本地 SSH 客户端或终端启用 Nerd Font 和真彩色。远程服务器不需要安装字体。纯 SSH 环境不能仅靠安装 xclip 就访问本地剪贴板；复制功能取决于终端的 OSC 52 支持及 Neovim/Zellij 设置。图标、剪贴板和快捷键需在实际终端中检查。

## 6. 默认 Shell（可选）

确认新配置正常后执行：

```sh
command -v zsh
cat /etc/shells
chsh -s "$(command -v zsh)"
```

如果 Zsh 路径未出现在 `/etc/shells`，先由管理员将该绝对路径加入文件。macOS Homebrew Zsh 也可能需要这一步。重新登录后生效。恢复默认 Bash 时可用 `chsh -s /bin/bash`（Linux 且该路径已在 `/etc/shells` 中）。

## 更新与恢复

- 更新配置：在仓库执行 `git pull --ff-only`，再运行 `bash scripts/install-config.sh`，随后 `exec zsh`。
- 更新 AstroNvim：在 Neovim 中执行 `:Lazy sync`；已有配置不会被安装脚本重置。
- 更新工具：包管理器安装的软件用原包管理器更新；用户目录下载的软件按对应步骤重新安装。
- 恢复 Zsh：退出当前 Zsh，把备份目录中的 `zsh`、`zshenv`、`zshrc` 恢复到原位置。若安装前没有 `.zshenv`，删除脚本追加的 `BEGIN/END my-shell` 段即可。
- 恢复 Git：从备份中的 `gitconfig`、`xdg-gitconfig` 恢复对应配置文件。若安装前没有配置文件，可用 `git config --global --unset-all` 分别移除脚本设置的五个键。
- 恢复 Neovim：先备份或移走新 `nvim` 配置，再把手动备份的配置与 `.bak` 运行目录移回原路径。

`extract` 会解压到压缩包旁的新目录 `文件名.extracted`，保留原压缩包并拒绝复用已有目录。它不是解压沙箱，仅用于可信压缩包。

## 官方参考

- [AstroNvim 安装要求与模板](https://docs.astronvim.com/)
- [Neovim 官方安装说明](https://github.com/neovim/neovim/blob/master/INSTALL.md)
- [Zellij 安装](https://zellij.dev/documentation/installation)
- [Starship 安装](https://starship.rs/guide/)
- [delta 配置](https://dandavison.github.io/delta/get-started.html)
