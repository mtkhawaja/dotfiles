# dotfiles  <!-- omit in toc -->

## Table of Contents  <!-- omit in toc -->

- [Linux](#linux)
  - [Installation](#installation)
    - [Running Setup Script](#running-setup-script)
    - [Convenience Script](#convenience-script)
- [Windows & WSL](#windows--wsl)
  - [Prerequisites](#prerequisites)
    - [Download Fonts for Powerline](#download-fonts-for-powerline)

## Linux

### Installation

#### Running Setup Script

```bash
git clone 'https://github.com/mtkhawaja/dotfiles.git' '/var/tmp/dotfiles'
source '/var/tmp/dotfiles/scripts/setup.sh'
rm -r --interactive=never '/var/tmp/dotfiles'
```

#### Convenience Script

Alternatively, copy and run the following command:

```bash
wget -O - 'https://raw.githubusercontent.com/mtkhawaja/utility-scripts/master/src/bash/run_dotfile_config.sh' | bash || rm run_dotfile_config.sh 
```

## Windows & WSL

### Prerequisites

#### Download Fonts for Powerline

- [UbuntuMono Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Ubuntu.zip)
- [mononoki Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Mononoki.zip)
