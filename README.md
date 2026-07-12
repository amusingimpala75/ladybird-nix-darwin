# Ladybird Nix Darwin Flake PoC

The current in-tree build of Ladybird is marked as broken on Darwin. This flake produces a
patched version that does build correctly.

I was quite certain that someone must have done this before but I cannot find anything
on GitHub at least.

Be warned: since this is patching not only Ladybird but also libtommath, this may
very will take close on an hour to build. While this can be used for building the browser,
it mainly serves as a PoC while I clean it up prior to PRing it into nixpkgs.

Note: AI was used for consulation, but I understand and made the changes with
a high degree of understanding of what was occuring there.

Licensed under the MIT License
