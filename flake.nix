{
  description = "Tracy Profiler";

  inputs = {
    zig2nix.url = "github:Cloudef/zig2nix";
  };

  outputs = { zig2nix, ... }: let
    flake-utils = zig2nix.inputs.flake-utils;
  in (flake-utils.lib.eachDefaultSystem (system: let
      # Zig flake helper
      # Check the flake.nix in zig2nix project for more options:
      # <https://github.com/Cloudef/zig2nix/blob/master/flake.nix>
      env = zig2nix.outputs.zig-env.${system} rec {
        enableOpenGL = true;
        # enableWayland = true;
        enableX11 = true;
        customRuntimeDeps = with env.pkgs; [ gtk3 dbus ];
        customAppHook = ''
            export XKB_CONFIG_ROOT=${env.pkgs.xkeyboard_config}/etc/X11/xkb
            export XLOCALEDIR=${env.pkgs.xorg.libX11.out}/share/X11/locale
        '';
        customDevShellHook = customAppHook;
      };
      system-triple = env.lib.zigTripleFromString system;
    in with builtins; with env.lib; with env.pkgs.lib; rec {
      # nix build .#target.{zig-target}
      # e.g. nix build .#target.x86_64-linux-gnu
      packages.target = genAttrs allTargetTriples (target: env.packageForTarget target ({
        src = cleanSource ./.;

        nativeBuildInputs = with env.pkgs; [];
        buildInputs = with env.pkgsForTarget target; [ gtk3 dbus ];

        # Smaller binaries and avoids shipping glibc.
        zigPreferMusl = true;

        # This disables LD_LIBRARY_PATH mangling, binary patching etc...
        # The package won't be usable inside nix.
        zigDisableWrap = true;

        # TODO: A non-legacy i.e. Wayland only build is not possible because Zig reports that it can't wayland-scanner on the host.
        #
        # error: the host system is unable to execute binaries from the target
        #   because the host dynamic linker is '/lib/ld-musl-x86_64.so.1',
        #   while the target dynamic linker is '/lib/ld-musl-x86_64.so.1'.
        #   consider setting the dynamic linker or enabling skip_foreign_checks in the Run step
        zigBuildFlags = ["-Dlegacy"];
      }));

      # nix build .
      packages.default = packages.target.${system-triple}.override {
        # Prefer nix friendly settings.
        zigPreferMusl = false;
        zigDisableWrap = false;
      };

      # For bundling with nix bundle for running outside of nix
      # example: https://github.com/ralismark/nix-appimage
      apps.bundle.target = genAttrs allTargetTriples (target: let
        pkg = packages.target.${target};
      in {
        type = "app";
        program = "${pkg}/bin/@SED_ZIG_BIN@";
      });

      # default bundle
      apps.bundle.default = apps.bundle.target.${system-triple};

      # nix run .
      apps.default = env.app [] "zig build run -- \"$@\"";

      # nix run .#build
      apps.build = env.app [] "zig build \"$@\"";

      # nix run .#test
      apps.test = env.app [] "zig build test -- \"$@\"";

      # nix run .#docs
      apps.docs = env.app [] "zig build docs -- \"$@\"";

      # nix run .#deps
      apps.deps = env.showExternalDeps;

      # nix run .#zon2json
      apps.zon2json = env.app [env.zon2json] "zon2json \"$@\"";

      # nix run .#zon2json-lock
      apps.zon2json-lock = env.app [env.zon2json-lock] "zon2json-lock \"$@\"";

      # nix run .#zon2nix
      apps.zon2nix = env.app [env.zon2nix] "zon2nix \"$@\"";

      # nix develop
      devShells.default = env.mkShell {};
    }));
}