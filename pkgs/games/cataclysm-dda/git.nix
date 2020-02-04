{ stdenv, callPackage, CoreFoundation
, tiles ? true, Cocoa
, debug ? false, cmake
}:

let
  inherit (stdenv.lib) substring;
  inherit (callPackage ./common.nix { inherit tiles CoreFoundation Cocoa debug; }) common utils;
  inherit (utils) fetchFromCleverRaven;
  rev = "b10296";
in

stdenv.mkDerivation (common // rec {
  version = rev;
  name = "cataclysm-dda-git-${version}";

#  src = fetchFromCleverRaven {
#    rev = "3e11834b57efa76cad25b0e598949bdb16faa81b";
#    sha256 = "1hkklm9dy4hhdcdjzvz82afrs9wvwhsjawyd8n0bwszb8ympim42";
#  };

  src = fetchTarball {
    url = "https://github.com/CleverRaven/Cataclysm-DDA/archive/cdda-jenkins-${rev}.tar.gz";
  };

  patches = [
    # Locale patch required for Darwin builds, see: https://github.com/NixOS/nixpkgs/pull/74064#issuecomment-560083970
  ];

  makeFlags = common.makeFlags ++ [
    "VERSION=git-${version}"
    "LTO=1"
    "RUNTESTS=0"
    "CMAKE_EXPORT_COMPILE_COMMANDS=ON"
  ];

  meta = with stdenv.lib.maintainers; common.meta // {
    maintainers = common.meta.maintainers ++ [ rardiol ];
  };
})
