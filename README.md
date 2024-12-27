# Dotfiles

My personal dotfiles.

## Setup

- [Ghostty](https://ghostty.org/) (terminal emulator)

## On a new machine

Step through the
[MacOS](https://github.com/waydegg/dotfiles-public/blob/master/macos-setup.sh) or
[Ubuntu](https://github.com/waydegg/dotfiles-public/blob/master/ubuntu-setup.sh) setup
scripts line-by-line depending on what OS you're on.

I update these scripts to work on my local machines (M1 macs running some version of
Ventura and linux boxes running Ubuntu 22.04) and virtual private servers (running
Ubuntu 22.04), so depending on your OS version or hardware you may run accross issues
running all of these commands successfully.

Run `:PlugInstall` and `:LspInstall` when opening NeoVim for the first time. It will
complain about missing plugins and language servers, so you will have to restart it a
couple times after installing everything.
