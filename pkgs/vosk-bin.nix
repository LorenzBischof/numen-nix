{
  stdenv,
  fetchzip,
  system,
}:
let
  getSource =
    system: version:
    let
      sources = {
        x86_64-linux = {
          systemString = "linux-x86_64";
          hash = "sha256-ToMDbD5ooFMHU0nNlfpLynF29kkfMknBluKO5PipLFY=";
        };
        aarch64-linux = {
          systemString = "linux-aarch64";
          hash = "sha256-ReldN3Vd6wdWjnlJfX/rqMA67lqeBx3ymWGqAj/ZRUE=";
        };
        i686-linux = {
          systemString = "linux-x86";
          hash = "sha256-tTnvwieAlIvZji7LnBuSygizxVKhh0T3ICq3hAW44fk=";
        };
      };
    in
    {
      url = "https://github.com/alphacep/vosk-api/releases/download/v${version}/vosk-${(builtins.getAttr system sources).systemString}-${version}.zip";
      hash = (builtins.getAttr system sources).hash;
    };
in
stdenv.mkDerivation rec {
  name = "vosk-bin";
  version = "0.3.45";
  src = fetchzip (getSource system version);

  installPhase = ''
    runHook preInstall

    install -Dm644 libvosk.so -t $out/lib
    install -Dm644 vosk_api.h -t $out/include

    runHook postInstall
  '';
}
