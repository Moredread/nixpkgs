{ lib, stdenv, fetchurl

# for update script
, writeShellScript, curl, nix-update
}:

stdenv.mkDerivation rec {

  pname = "steam-runtime";
  # from https://repo.steampowered.com/steamrt-images-scout/snapshots/
  version = "0.20210527.0";

  src = fetchurl {
    url = "https://repo.steampowered.com/steamrt-images-scout/snapshots/${version}/steam-runtime.tar.xz";
    sha256 = "1880d1byn265w0vy5p98d8w8virnbywj707ydybj7rixhid2gzdc";
    name = "scout-runtime-${version}.tar.gz";
  };

  buildCommand = ''
    mkdir -p $out
    tar -C $out --strip=1 -x -f $src
  '';

  passthru = {
    updateScript = writeShellScript "update.sh" ''
      version=$(${curl}/bin/curl https://repo.steampowered.com/steamrt-images-scout/snapshots/latest-steam-client-general-availability/VERSION.txt)
      ${nix-update}/bin/nix-update --version "$version" steamPackages.steam-runtime
    '';
  };

  meta = with lib; {
    description = "The official runtime used by Steam";
    homepage = "https://github.com/ValveSoftware/steam-runtime";
    license = licenses.unfreeRedistributable; # Includes NVIDIA CG toolkit
    maintainers = with maintainers; [ hrdinka abbradar ];
  };
}
