{
  description = "My personal website";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-colors.url = "github:Misterio77/nix-colors";
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      lib = nixpkgs.lib;
      systems = lib.systems.flakeExposed;
      pkgsFor = lib.genAttrs systems (system: import nixpkgs { inherit system; });
      forEachSystem = f: lib.genAttrs systems (system: f pkgsFor.${system});

      colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;
    in
    {
      devShells = forEachSystem (pkgs: {
        default = import ./shell.nix { inherit pkgs; };
      });
      packages = forEachSystem (pkgs: {
        default = pkgs.writeShellApplication {
          name = "update-colorscheme";
          runtimeInputs = with pkgs; [ gnused ];
          text = lib.concatStringsSep "\n" (
            lib.attrsets.mapAttrsToList (
              name: value: "sed -i '/--${name}/s/#.\\{6\\}/#${value}/' src/styles/global.css"
            ) colorScheme.palette
          );
        };
      });
    };
}
