{
  description = "Sure (csille00/finance-dashboard), packaged for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      sure = pkgs.callPackage ./nix/package.nix {
        rev = self.rev or self.dirtyRev or "unknown";
      };

      update-gems = pkgs.writeShellApplication {
        name = "update-gems";
        runtimeInputs = [ sure.ruby pkgs.bundix pkgs.git pkgs.gawk pkgs.gnused ];
        text = builtins.readFile ./nix/update-gems.sh;
      };
    in
    {
      packages.${system} = {
        default = sure;
        inherit sure update-gems;
      };

      apps.${system}.update-gems = {
        type = "app";
        program = "${update-gems}/bin/update-gems";
      };

      # Ruby and the gemset the package is built with, plus Postgres and Redis
      # clients for local development.
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          sure.gems
          sure.gems.wrappedRuby
          pkgs.bundix
          pkgs.postgresql
          pkgs.redis
          pkgs.poppler-utils
        ];
        BUNDLE_GEMFILE = "${sure.gems.confFiles}/Gemfile";
        TAILWINDCSS_INSTALL_DIR = "${sure.tailwindcss}/bin";
      };
    };
}
