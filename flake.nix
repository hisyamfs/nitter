{
  description = "Nitter";

  nixConfig = {
    bash-prompt-prefix = "(nix-shell:dev-nitter)";
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs @ { self, nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system:
    let 
      pkgs = import nixpkgs { inherit system; };

      nimDeps = with pkgs; [
        nim
      ]; 
      nimbleDeps = import ./nitter.nimble.nix { fetchNimble = pkgs.nimPackages.fetchNimble; };

      mkShell = pkgs.mkShell;
      buildNimPackage = pkgs.nimPackages.buildNimPackage;

      nitter = buildNimPackage {
        pname = "nitter";
        version = "0.1.0";
        src = ./.;
        nimbleFile = ./nitter.nimble;
        nimRelease = true;
        buildInputs = nimbleDeps;
      };
      nitterCss = buildNimPackage {
        pname = "nitter-css";
        version = "0.1.0";
        src = ./tools/gencss.nim;
        nimbleFile = ./nitter.nimble;
        nimRelease = true;
        buildInputs = nimbleDeps;
      };
      nitterMd = buildNimPackage {
        pname = "nitter-md";
        version = "0.1.0";
        src = ./tools/rendermd.nim;
        nimbleFile = ./nitter.nimble;
        nimRelease = true;
        buildInputs = nimbleDeps;
      };

    in {
      devShells.default = mkShell {
        buildInputs = nimDeps ++ nimbleDeps;
        # buildInputs = nimDeps;
      };

      packages.nitter = nitter;
      packages.default = nitter;

      nixosModules.default = import ./nitter-service.nix;
    }
  );
}
