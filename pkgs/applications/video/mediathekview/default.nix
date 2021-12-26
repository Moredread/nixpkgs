{ lib, stdenv, fetchurl, makeWrapper, jre }:

stdenv.mkDerivation rec {
  version = "13.8.1";
  pname = "mediathekview";
  src = fetchurl {
    url = "https://download.mediathekview.de/stabil/MediathekView-${version}-linux.tar.gz";
    sha256 = "0vzl111n6jdmy950hsxyjny0s482kpv99bwccwz9b54g9l34q0k0";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib}

    install -m644 MediathekView.jar $out/lib

    makeWrapper ${jre}/bin/java $out/bin/mediathek \
      --add-flags "-jar $out/lib/MediathekView.jar"

    makeWrapper ${jre}/bin/java $out/bin/MediathekView \
      --add-flags "-jar $out/lib/MediathekView.jar"

    makeWrapper ${jre}/bin/java $out/bin/MediathekView_ipv4 \
      --add-flags "-Djava.net.preferIPv4Stack=true -jar $out/lib/MediathekView.jar"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Offers access to the Mediathek of different tv stations (ARD, ZDF, Arte, etc.)";
    homepage = "https://mediathekview.de/";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ moredread ];
    platforms = platforms.all;
  };
}
