{
  lib,
  stdenv,
  bundlerEnv,
  ruby_3_4,
  tailwindcss_4,
  fetchurl,
  makeWrapper,
  poppler-utils,
  rev ? "unknown",
  # Rails writes to tmp/, log/ and storage/ under its root, which is read-only
  # in the store. Those three are symlinks into this directory at runtime.
  stateDir ? "/var/lib/sure/app",
}:

let
  ruby = ruby_3_4;

  # nix/gems is generated from the root Gemfile/Gemfile.lock by
  # `nix run .#update-gems`; see nix/update-gems.sh for why it differs.
  gems = bundlerEnv {
    name = "sure-gems";
    inherit ruby;
    gemdir = ./gems;
    groups = [ "default" "production" ];
  };

  # The tailwindcss-ruby gem normally ships the CLI binary inside a platform
  # gem. The Nix build uses the plain-Ruby gem instead, which has no binary, so
  # supply the exact release that gem version wraps — read from the gemset, so
  # it follows the lockfile. When that version changes the build fails with a
  # hash mismatch: paste the hash it prints here.
  tailwindVersion = (import ./gems/gemset.nix).tailwindcss-ruby.version;
  tailwindcss = tailwindcss_4.overrideAttrs (_: {
    version = tailwindVersion;
    src = fetchurl {
      url = "https://github.com/tailwindlabs/tailwindcss/releases/download/v${tailwindVersion}/tailwindcss-linux-x64";
      hash = "sha256-j4TOgQvf8iXlmXgdHi2qgrQoIikCHIZ6cbQZ9Z+aqDY=";
    };
  });

  # Everything the app needs at runtime besides Ruby and gems.
  # pdftoppm: PDF statement imports (Provider::Openai::PdfProcessor).
  runtimePath = lib.makeBinPath [ poppler-utils ];

  # Only what the Rails app needs; the mobile/desktop clients, Helm charts and
  # test suites would otherwise rebuild the package whenever they change.
  # docs/ stays: the app reads docs/onboarding (Settings -> Guides and its
  # images, which are precompiled assets) and docs/api (the API docs UI).
  root = ../.;
  src = lib.fileset.toSource {
    inherit root;
    fileset = lib.fileset.difference root (
      lib.fileset.unions (
        map lib.fileset.maybeMissing [
          ../nix
          ../flake.nix
          ../flake.lock
          ../.github
          ../mobile
          ../desktop
          ../charts
          ../design
          ../spec
          ../test
          ../node_modules
          ../tmp
          ../log
          ../storage
          ../public/assets
        ]
      )
    );
  };
in
stdenv.mkDerivation {
  pname = "sure";
  version = "0-unstable-${builtins.substring 0 7 rev}";
  inherit src;

  nativeBuildInputs = [ gems gems.wrappedRuby makeWrapper ];

  env = {
    RAILS_ENV = "production";
    BUNDLE_GEMFILE = "${gems.confFiles}/Gemfile";
    # Must match `groups` above, or Bundler looks for gems that were not built.
    BUNDLE_WITHOUT = "development:test";
    TAILWINDCSS_INSTALL_DIR = "${tailwindcss}/bin";
  };

  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR
    mkdir -p tmp log storage

    # Same as the upstream Dockerfile: assets compile without real secrets.
    SECRET_KEY_BASE_DUMMY=1 ruby bin/rails assets:precompile

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    app=$out/share/sure
    mkdir -p $app $out/bin
    cp -r . $app
    rm -rf $app/tmp $app/log $app/storage
    ln -s ${stateDir}/tmp $app/tmp
    ln -s ${stateDir}/log $app/log
    ln -s ${stateDir}/storage $app/storage

    # Shared by every launcher: run from the app root against the Nix gemset.
    common=(
      --chdir $app
      --set BUNDLE_GEMFILE ${gems.confFiles}/Gemfile
      --set BUNDLE_WITHOUT development:test
      --set-default RAILS_ENV production
      --set BUILD_COMMIT_SHA ${rev}
      --prefix PATH : ${runtimePath}
    )

    # `sure-rails db:migrate`, `sure-rails console`, `sure-rails runner ...`
    makeWrapper ${gems.wrappedRuby}/bin/ruby $out/bin/sure-rails \
      "''${common[@]}" --add-flags $app/bin/rails

    # Puma straight from its CLI so the bind address set here wins over the
    # `port` in config/puma.rb, which would otherwise listen on 0.0.0.0.
    # Takes the address as SURE_BIND (e.g. tcp://127.0.0.1:8095).
    makeWrapper ${gems}/bin/puma $out/bin/sure-web \
      "''${common[@]}" --add-flags "-C $app/config/puma.rb" \
      --run 'set -- -b "''${SURE_BIND:?SURE_BIND must be set}" "$@"'

    makeWrapper ${gems}/bin/sidekiq $out/bin/sure-worker \
      "''${common[@]}" --add-flags "-C $app/config/sidekiq.yml"

    runHook postInstall
  '';

  passthru = { inherit gems ruby tailwindcss; };

  meta = {
    description = "Sure personal finance app (csille00/finance-dashboard fork)";
    homepage = "https://github.com/csille00/finance-dashboard";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
