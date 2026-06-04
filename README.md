# Ladybird Nix Darwin Flake PoC

The current in-tree build of Ladybird is marked as broken on Darwin. This flake produces a
patched version that does build correctly.

I was quite certain that someone must have done this before but I cannot find anything
on GitHub at least.

Be warned: since this is patching not only Ladybird but also ANGLE and libtommath, this may
very will take close on an hour to build. While this can be used for building the browser,
it mainly serves as a PoC while I clean it up prior to PRing it into nixpkgs.

Note: AI was used for consulation, but the only code that is largely from the AI is the
angle_egl patch, and I generally understand the issue there and what is being solved
(fixing the ldflags to use the rpath rather than local path, so that the fixup step can
rewrite it into an absolute path). Besides that, I understand and made the changes with
a high degree of understanding of what was occuring there.

Licensed under the MIT License
