{ stdenv, fetchzip }:
stdenv.mkDerivation {
  name = "vosk-model-small-en-us";
  version = "0.15";
  src = fetchzip {
    url =
      "https://alphacephei.com/kaldi/models/vosk-model-small-en-us-0.15.zip";
    hash = "sha256-CIoPZ/krX+UW2w7c84W3oc1n4zc9BBS/fc8rVYUthuY=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/usr/share/vosk-models
    cp -r . $out/usr/share/vosk-models/small-en-us

    runHook postInstall
  '';
}

