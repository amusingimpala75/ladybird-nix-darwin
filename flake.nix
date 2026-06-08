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

            # I'm currently waiting to hear if this (or the previous version
            # should be PR'd into nixpkgs separately or be contained in the
            # package definition, like how skia is currently patched
            patched-libtommath = pkgs.libtommath.overrideAttrs (old: {
              env.NIX_CFLAGS_COMPILE = ''
                -D__STDC_IEC_559__=1
              '';
            });

            # [TODO] Can be removed once nixpkgs#528602 is merged
            patched-angle = pkgs.angle.overrideAttrs (old: {
              # Fix pkg-config path
              installPhase = builtins.replaceStrings [ "<<EOF" ] ["<<'EOF'"] old.installPhase;
              # Fix otool -L / otool -D paths on Darwin, applying it on NixOS does nothing
              nativeBuildInputs = old.nativeBuildInputs ++ (lib.optionals pkgs.stdenv.hostPlatform.isDarwin (with pkgs; [
                fixDarwinDylibNames
              ]));
              env.NIX_LDFLAGS = lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "-headerpad_max_install_names";
              postFixup = lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
                install_name_tool \
                    -change ./libGLESv2.dylib \
                    $out/lib/libGLESv2.dylib \
                    $out/lib/libGLESv1_CM.dylib
              '';
            });

            patched-ladybird =
              let
                replace = old: new: list: map (pkg:
                  let
                    maybeIndex = lib.lists.findFirstIndex (i: i == pkg) null old;
                  in
                    if maybeIndex != null then builtins.elemAt new maybeIndex else pkg
                ) list;
              in
                pkgs.ladybird.overrideAttrs (old: {
                  # Patch libtommath to include mp_set_double
                  nativeBuildInputs =
                    replace [ pkgs.libtommath ] [ self'.packages.patched-libtommath ] old.nativeBuildInputs;

                  buildInputs =
                    # Patch angle to fix the pkg-config path and dylib refs
                    (replace [ pkgs.angle ] [ self'.packages.patched-angle ] old.buildInputs)
                    ++ (lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
                      # Add apple-sdk_15 since that is the baseline for Ladybird now (NSCursor-something missing error)
                      pkgs.apple-sdk_15
                    ]);

                  env.NIX_LDFLAGS =
                    if pkgs.stdenv.isDarwin
                    # Remove -lGl
                    then (lib.removePrefix "-lGL " old.env.NIX_LDFLAGS)
                    else old.env.NIX_LDFLAGS;

                  # [TODO] waiting on upstream to accept this patch, issue ladybird#9917
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
