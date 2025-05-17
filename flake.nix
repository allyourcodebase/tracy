{
  description = "Tracy Profiler";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-compat.url = "github:edolstra/flake-compat";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }:
    builtins.foldl' nixpkgs.lib.recursiveUpdate {} (
      builtins.map (
        system: let
          pkgs = nixpkgs.legacyPackages.${system};
          deps = pkgs.callPackage ./build.zig.zon.nix {};
          zig_hook = pkgs.zig_0_14.hook.overrideAttrs {
            zig_default_flags = "-Doptimize=ReleaseFast -Dcpu=baseline --color off";
          };
          fs = pkgs.lib.fileset;
        in {
          formatter.${system} = pkgs.alejandra;
          packages.${system} = rec {
            default = tracy;
            tracy = pkgs.stdenv.mkDerivation {
              name = "tracy";
              version = "0.11.0";
              meta.mainProgram = "tracy-profiler";
              src = fs.toSource {
                root = ./.;
                fileset = fs.intersection (fs.fromSource ./.) (
                  fs.unions [
                    ./capture
                    ./csvexport
                    ./import
                    ./include
                    ./profiler
                    ./public
                    ./server
                    ./update
                    ./build.zig
                    ./build.zig.zon
                    ./build.zig.zon.nix
                  ]
                );
              };
              dontConfigure = true;
              buildInputs = with pkgs;
                [glfw zstd capstone lz4 gtk3 dbus]
                ++ lib.optionals (stdenv.hostPlatform.isLinux) [libxkbcommon];
              nativeBuildInputs = with pkgs;
                [zig_hook pkg-config makeWrapper]
                ++ lib.optionals (stdenv.hostPlatform.isLinux) [wayland-scanner];
              zigBuildFlags = ["--system" "${deps}"];

              postFixup = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
                wrapProgram $out/bin/tracy-profiler --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [pkgs.libglvnd]}"
              '';
            };
          };
          devShells.${system}.default = pkgs.mkShell {
            buildInputs = with pkgs; [gtk3 dbus];
            nativeBuildInputs = with pkgs; [zig_hook pkg-config];
            shellHook = ''
              export XKB_CONFIG_ROOT=${pkgs.xkeyboard_config}/etc/X11/xkb
              export XLOCALEDIR=${pkgs.xorg.libX11.out}/share/X11/locale
            '';
          };
        }
      )
      ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]
    );
}
