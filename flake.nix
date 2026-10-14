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
  }: let
    parseVersionFieldFromZon = name:
      nixpkgs.lib.pipe ./build.zig.zon [
        builtins.readFile
        (builtins.match ".*\n[[:space:]]*\\.${name}[[:space:]]=[[:space:]]\"([^\"]+)\".*")
        builtins.head
      ];
    version = parseVersionFieldFromZon "version";
  in
    builtins.foldl' nixpkgs.lib.recursiveUpdate {} (
      builtins.map (
        system: let
          pkgs = nixpkgs.legacyPackages.${system};
          deps = pkgs.callPackage ./build.zig.zon.nix {};
          fs = pkgs.lib.fileset;
        in {
          formatter.${system} = pkgs.alejandra;
          packages.${system} = rec {
            default = tracy;
            tracy = pkgs.stdenv.mkDerivation {
              name = "tracy";
              version = version;
              meta.mainProgram = "tracy-profiler";
              src = fs.toSource {
                root = ./.;
                fileset = fs.intersection (fs.fromSource ./.) (
                  fs.unions [
                    ./capture
                    ./csvexport
                    ./import
                    ./include
                    ./manual/tracy.md
                    ./merge
                    ./monitor
                    ./profiler
                    ./public
                    ./server
                    ./tests/tracy
                    ./update
                    ./build.zig
                    ./build.zig.zon
                    ./build.zig.zon.nix
                  ]
                );
              };
              buildInputs = with pkgs;
                [curl zstd lz4 freetype gtk3 dbus]
                ++ lib.optionals (stdenv.hostPlatform.isLinux) [libxkbcommon];
              nativeBuildInputs = with pkgs;
                [zig_0_17 pkg-config makeWrapper]
                ++ lib.optionals (stdenv.hostPlatform.isLinux) [wayland-scanner wayland-protocols];
              dontSetZigDefaultFlags = true;
              zigBuildFlags = [
                "--system"
                "${deps}"
                "-fno-sys=capstone"
                "-Dcpu=baseline"
                "-Doptimize=ReleaseFast"
                "--color"
                "off"
              ];

              postFixup = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
                wrapProgram $out/bin/tracy-profiler --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [pkgs.libglvnd]}"
              '';
            };
          };
          devShells.${system}.default = pkgs.mkShell {
            buildInputs = with pkgs;
              [gtk3 dbus]
              ++ lib.optionals (stdenv.hostPlatform.isLinux) [libxkbcommon];
            nativeBuildInputs = with pkgs; [zig_0_17 pkg-config];
            # shellHook = ''
            #   export XKB_CONFIG_ROOT=${pkgs.xkeyboard_config}/etc/X11/xkb
            #   export XLOCALEDIR=${pkgs.xorg.libX11.out}/share/X11/locale
            # '';
          };
        }
      )
      ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]
    );
}
