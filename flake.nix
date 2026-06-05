{
  description = "flake for ladybird fix on darwin";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      perSystem =
        { lib, pkgs, self', ... }:
        {
          packages = {
            default = self'.packages.patched-ladybird;

            # This probably should just stay local to the package
            patched-libtommath = pkgs.libtommath.overrideAttrs (old: {
              patches = [
                ./force_mp_set_double.patch
              ];
            });

            # [TODO] one last integrated build before opening a PR for this
            patched-angle = pkgs.angle.overrideAttrs (old: {
              # Fix pkg-config path
              installPhase = builtins.replaceStrings [ "<<EOF" ] ["<<'EOF'"] old.installPhase;
              # Fix otool -L / otool -D paths on Darwin, applying it on NixOS does nothing
              nativeBuildInputs = old.nativeBuildInputs ++ (lib.optionals pkgs.stdenv.hostPlatform.isDarwin (with pkgs; [
                apple-sdk
                fixDarwinDylibNames
              ]));
              env.NIX_LDFLAGS = lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "-headerpad_max_install_names";
              postFixup = ''
                install_name_tool \
                    -change ./libGLESv2.dylib \
                    $out/lib/libGLESv2.dylib \
                    $out/lib/libGLESv1_CM.dylib
              '';
            });

            patched-ladybird =
              let
                src = pkgs.fetchFromGitHub {
                  owner = "LadybirdBrowser";
                  repo = "ladybird";
                  rev = "5595efd46b625e6e56b9b8e7d0d7aa73d3a34fec";
                  hash = "sha256-bqEDQpbsOsi0b+8a/xpUPKPJ4TP2h/AlQ9aUIjvrn2I=";
                };

                transport_security_static_static_json = pkgs.stdenv.mkDerivation {
                  name = "transport_security_state_static.json";
                  src = pkgs.chromium.browser.chromiumDeps.src;
                  sourceRoot = "net";
                  nativeBuildInputs = [
                    pkgs.zstd
                  ];
                  installPhase = ''
                    cp http/transport_security_state_static.json $out
                  '';
                };

                replace = old: new: list: map (pkg:
                  let
                    maybeIndex = lib.lists.findFirstIndex (i: i == pkg) null old;
                  in
                    if maybeIndex != null then builtins.elemAt new maybeIndex else pkg
                ) list;
              in
                pkgs.ladybird.overrideAttrs (old: {
                  version = "0-unstable-2026-06-02";

                  inherit src;

                  cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
                    inherit src;
                    hash = "sha256-n0ACVH8NXwe7SIaGFoJ20WIGGR3XjcuLTwPSKGJpT5s=";
                  };

                  # Patch libtommath to include mp_set_double
                  nativeBuildInputs = replace [ pkgs.libtommath ] [ self'.packages.patched-libtommath ] old.nativeBuildInputs;

                  # Patch angle to fix the pkg-config path
                  buildInputs = (replace [ pkgs.angle ] [ self'.packages.patched-angle ] old.buildInputs) ++ (with pkgs; [
                    mimalloc      # Add mimalloc
                    apple-sdk_15  # Add apple-sdk
                  ]);

                  # Fetch the hsts preload data cache
                  # Side note: wish I didn't have to fetch the 1.2GB chromium
                  # source, might just manually fetchget
                  preConfigure = old.preConfigure + ''
                    mkdir -p build/Caches/HSTSPreload
                    cp ${transport_security_static_static_json} build/Caches/HSTSPreload/transport_security_state_static.json
                  '';

                  env.NIX_LDFLAGS = (lib.removePrefix "-lGL " old.env.NIX_LDFLAGS) # Remove -lGl
                                    + " -framework CoreText"; # Add -framework CoreText to make lagom-gfx compile

                  # Hopefull fix the angle issues. This /might/ remove the need
                  # for all of the other angle patches
                  patches = [
                    ./fix_egl_define.patch
                  ];

                  # Mark darwin as no longer broken
                  meta.broken = false;
                });
          };
        };
    };
}
