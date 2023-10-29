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

      nimMarkdown = pkgs.fetchFromGitHub {
        owner = "soasme";
        repo = "nim-markdown";
        rev = "v0.8.7";
        hash = "sha256-5k9SrSgHLBeNUVm03h7a7GwQSpyg/aGhbjSoaBWsM7I=";
      };
      nimbleDeps = [nimMarkdown] ++ (import ./nitter.nimble.nix { fetchNimble = pkgs.nimPackages.fetchNimble; });

      mkShell = pkgs.mkShell;
      mkDerivation = pkgs.stdenv.mkDerivation;
      buildNimPackage = pkgs.nimPackages.buildNimPackage;

      nitter = buildNimPackage {
        pname = "nitter";
        version = "0.1.0";
        src = ./.;
        nimbleFile = ./nitter.nimble;
        nimRelease = true;
        buildInputs = nimbleDeps;
      };
      assets = 
        let 
          nimc = "${pkgs.nim}/bin/nim";
          mkLibFlag = path: sep: ''--path:"${path}/src"'' + sep;
        in mkDerivation rec {
          pname = "nitter-assets";
          version = "0.1.0";
          src = ./.;
          buildInputs = nimbleDeps ++ [pkgs.libsass];
          buildPhase = let 
            libFlags = builtins.foldl' 
              (p: n: p + (mkLibFlag n " "))
              "" buildInputs
            ;
            libNimCfg = builtins.foldl' 
              (p: n: p + (mkLibFlag n "\n"))
              "" buildInputs
            ;
            genCss = "${nimc} r ${libFlags} -d:release -d:nimDebugDlOpen --nimcache:$TMPDIR tools/gencss.nim";
            renderMd = "${nimc} r ${libFlags} -d:release -d:nimDebugDlOpen --nimcache:$TMPDIR tools/rendermd.nim";
          in ''
            ${genCss}
            ${renderMd}
          '';
          installPhase = ''
            mkdir -p $out/public
            cp -r public/** $out/public
          '';
        };
      hmacgen = 
        let
          nimc = "${pkgs.nim}/bin/nim";
        in mkDerivation {
          pname = "nitter-hmac";
          version = "0.1.0";
          src = ./tools;
          buildInputs = nimbleDeps ++ [pkgs.sass];
          buildPhase = ''
            ${nimc} -d:release -o:hmacgen --nimcache:$TMPDIR c hmacgen.nim 
          '';
          installPhase = ''
            install -Dt $out/bin hmacgen
          '';
        };
    in rec {
      devShells.default = mkShell {
        buildInputs = nimDeps ++ nimbleDeps;
        # buildInputs = nimDeps;
      };

      packages.nitter = nitter;
      packages.default = nitter;
      packages.hmacgen = hmacgen;
      packages.assets = assets;

      nixosModules.default = 
        { 
          lib
          , config
          , pkgs
          , nitterPkgs 
          , ... 
        }: {
          imports = [
            ./nitter-service.nix
          ];
        };
    }
  );
}
