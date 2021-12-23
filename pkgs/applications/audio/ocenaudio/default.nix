{ stdenv
, lib
, fetchurl
, autoPatchelfHook
, dpkg
, qt5
, libjack2
, alsa-lib
, bzip2
, libpulseaudio }:

stdenv.mkDerivation rec {
  pname = "ocenaudio";
  version = "3.11.1";

  src = fetchurl {
    url = "https://www.ocenaudio.com/downloads/index.php/ocenaudio_debian9_64.deb?version=${version}";
    sha256 = "sha256-m8sKu2QuEyCWQ975vDfLVWKgU7ydEp5/vRYRO3z1yio=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    qt5.qtbase
    qt5.wrapQtAppsHook
    libjack2
    libpulseaudio
    bzip2
    alsa-lib
  ];

  buildInputs = [ dpkg ];

  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    mkdir -p $out
    dpkg -x $src $out
    cp -av $out/opt/ocenaudio/* $out
    rm -rf $out/opt

    # Create symlink bzip2 library
    ln -s ${bzip2.out}/lib/libbz2.so.1 $out/libbz2.so.1.0
  '';

  meta = with lib; {
    description = "Cross-platform, easy to use, fast and functional audio editor";
    homepage = "https://www.ocenaudio.com";
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = with maintainers; [ onny ];
  };
}
