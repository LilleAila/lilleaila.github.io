---
title: "Contributing to nixpkgs and home-manager"
description: "A short guide for how to contribute something to nixpkgs or home-manager"
pubDate: "2024-07-01"
tags:
  - Tutorial
  - Nix
---

This is just a short guide for setting up a development environment. Make sure to also read the contribution guidelines of [nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md) and [home-manager](https://nix-community.github.io/home-manager/index.xhtml#ch-contributing)

## Getting started

First, create a fork on github, then clone your repo:

```bash
git clone git@github.com:LilleAila/nixpkgs --depth=1
cd nixpkgs
```

## Configure remotes

Set the upstream repo as a remote to your local repo. For nixpkgs, run this command:

```bash
git remote add upstream https://github.com/NixOS/nixpkgs
```

and for home-manager, run this

```bash
git remote add upstream https://github.com/nix-community/home-manager
```

, then fetch the upstream remote with

```bash
git fetch --depth=1 upstream
```

## Set up your development environment

After cloning the repo to your local machine, you want to configure your development environment. The easiest way to do this is using [direnv](https://github.com/nix-community/nix-direnv). Add the following to `.git/info/exclude`:

```
shell.nix
.envrc
.direnv
```

This file works the same as `.gitignore`, the only difference being that it doesn't get included in commits.

Now, you want to configure the devshell. Create a `shell.nix`, and enable direnv:

```nix
# shell.nix
{ pkgs ? import <nixpkgs> { }, }:
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    nixfmt-rfc-style
    nixd
  ];
}
```

```bash
echo "use nix" > .envrc && direnv allow
```

If you are contributing to `home-manager`, you want to use `nixfmt-classic` instead of `nixfmt-rfc-style` as the formatter.

## Adding your changes

Create a new branch based on `upstream/master`

```bash
git checkout -b descriptive-branch-name upstream/master
```

### Oh no, I forgot to make a new branch!

Run the following commands to move the changes to the correct place:

```bash
git branch the-new-branch
git reset origin/master --hard
git checkout the-new-branch
```

## Testing your changes

In your NixOS configuration, change the input url in your `flake.nix` to the path of your local repo, for example

```nix
inputs.home-manager = {
  url = "/home/olai/devel/home-manager/";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

## Creating a pull request

Make sure your commit messages are formatted like this

```
{component}: {short description}

{long description}
```

, then push your changes to your fork with

```bash
git push origin branch-name
```

Use the github interface to create a pull request, making sure the name is also formatted as `{component}: {short description}`.
