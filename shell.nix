{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    nixd
    nixfmt-rfc-style
    nodejs
    nodePackages.npm
    nodePackages.typescript
    nodePackages.typescript-language-server
    # Prettierd doesn't work for some reason, so falling back to prettier
    # (prettier is installed with npm i --save-dev prettier prettier-plugin-astro)
    # prettierd
    vscode-langservers-extracted
    nodePackages."@astrojs/language-server"
    emmet-ls
  ];
}
