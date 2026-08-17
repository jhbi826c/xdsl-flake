{
  description = "xDSL Python environment";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
  outputs = { self, nixpkgs }:
    let
      xdslVersion = "0.69.0";
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          python = pkgs.python312.override {
            packageOverrides = pfinal: pprev: {
              llvmlite = pprev.llvmlite.overridePythonAttrs (old: rec {
                version = "0.47.0";
                src = pkgs.fetchFromGitHub {
                  owner = "numba"; repo = "llvmlite"; tag = "v${version}";
                  hash = "sha256-YEIdIdbk19JHYtgL2gWjnAUYu13CH+7ikoyBUkOPpws=";
                };
              });
              xdsl = pfinal.buildPythonPackage rec {
                pname = "xdsl"; version = xdslVersion; pyproject = true;
                src = pkgs.fetchPypi {
                  inherit pname version;
                  hash = "sha256-zDZcwcdGvVy/B/NI5smeLahagU917kSpHLnKog6jwWY=";
                };
                build-system = [ pfinal.setuptools pfinal.setuptools-scm ];
                dependencies = [
                  pfinal.immutabledict
                  pfinal.ordered-set
                  pfinal.typing-extensions
                ];
                optional-dependencies = {
                  llvm = [ pfinal.llvmlite ];
                };
                doCheck = false;
                pythonImportsCheck = [ "xdsl" ];
              };
            };
          };
          pythonEnv = python.withPackages (ps: with ps; [
            xdsl
            pytest
          ] ++ ps.xdsl.optional-dependencies.llvm);
        in {
          inherit python pythonEnv;
          default = pythonEnv;
        });
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          pythonEnv = self.packages.${system}.pythonEnv;
        in {
          default = pkgs.mkShell {
            packages = [ pythonEnv ];
            shellHook = ''
              VENV_DIR=.venv
              if [ ! -d "$VENV_DIR" ]; then
                ${pythonEnv}/bin/python -m venv --system-site-packages "$VENV_DIR"
              fi
              source "$VENV_DIR/bin/activate"
            '';
          };
        });
      overlays.default = final: prev: {
        xdsl-python = self.packages.${final.system}.python;
        xdsl-env = self.packages.${final.system}.pythonEnv;
      };
      nixosModules.default = { pkgs, ... }: {
        nixpkgs.overlays = [ self.overlays.default ];
        environment.systemPackages = [ pkgs.xdsl-env ];
      };
    };
}
