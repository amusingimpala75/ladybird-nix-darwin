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

            # Waiting on #533430 to be merged
            patched-libtommath = pkgs.libtommath.overrideAttrs (old: {
              env.NIX_CFLAGS_COMPILE = ''
                -D__STDC_IEC_559__=1
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

                  # Add apple-sdk_15 since that is the baseline for Ladybird now (NSCursor-something missing error)
                  buildInputs = old.buildInputs ++ (lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
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
