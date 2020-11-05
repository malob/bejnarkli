{ pkgs ? import <nixpkgs> { }, lint ? false, }:
pkgs.haskellPackages.callPackage ({ base64-bytestring, conduit, conduit-extra
  , hindent, hlint, lib, memory, mkDerivation, network, network-simple
  , network-uri, nixfmt, openssl, optparse-applicative, QuickCheck
  , quickcheck-instances, random, SHA, socat, stdenv, streaming-commons
  , temporary, utf8-string, }:
  mkDerivation {
    pname = "bejnarkli";
    version = "0.0.1.0";
    src = lib.cleanSource ./.;
    libraryHaskellDepends = [
      base64-bytestring
      conduit
      conduit-extra
      memory
      network
      network-simple
      network-uri
      optparse-applicative
      SHA
      streaming-commons
      random
      temporary
      utf8-string
    ];
    testHaskellDepends = [ openssl QuickCheck quickcheck-instances socat ]
      ++ lib.optionals lint [ hindent hlint nixfmt ];
    postCheck = lib.optionalString lint ''
      hlint *.hs
      hindent --validate *.hs
      nixfmt --check *.nix
    '';
    postInstall = ''
      patchShebangs test.sh
      ./test.sh $out/bin/bejnarkli
    '';
    license = lib.licenses.mit;
  }) { }
