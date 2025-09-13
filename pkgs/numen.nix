{
  fetchFromSourcehut,
  stdenv,
  buildGoModule,
  makeWrapper,
  scdoc,
  dotool,
  vosk-bin,
  vosk-model-small-en-us,
  lib,
  alsa-utils,
  libxkbcommon,
  gnused,
  gawk,
  coreutils,
  libnotify,
  dmenu,
  procps,
  installShellFiles,
}:

buildGoModule rec {
  pname = "numen";
  version = "0.7";

  src = fetchFromSourcehut {
    owner = "~geb";
    repo = pname;
    rev = version;
    hash = "sha256-ia01lOP59RdoiO23b5Dv5/fX5CEI43tPHjmaKwxP+OM=";
  };
  vendorHash = "sha256-Y3CbAnIK+gEcUfll9IlEGZE/s3wxdhAmTJkj9zlAtoQ=";

  preBuild = ''
    export CGO_CFLAGS="-I${vosk-bin}/include"
    export CGO_LDFLAGS="-L${vosk-bin}/lib"
  '';

  nativeBuildInputs = [
    makeWrapper
    scdoc
    installShellFiles
  ];

  ldflags = [
    "-X main.Version=${version}"
    "-X main.DefaultModelPackage=vosk-model-small-en-us"
    "-X main.DefaultModelPaths=${vosk-model-small-en-us}/usr/share/vosk-models/small-en-us"
    "-X main.DefaultPhrasesDir=${placeholder "out"}/etc/numen/phrases"
  ];

  # This is necessary because while the scripts are copied relative to
  # the nix store, the hard-coded paths inside the scripts themselves
  # still point outside of the store.
  patchPhase = ''
    runHook prePatch

    substituteInPlace scripts/* \
      --replace-warn /etc/numen/scripts "$out/etc/numen/scripts"
    substituteInPlace phrases/* \
      --replace-warn /etc/numen/scripts "$out/etc/numen/scripts" \
      --replace-warn numenc "$out/bin/numenc"
    substituteInPlace numenc \
      --replace-warn /bin/echo echo

    runHook postPatch
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 $GOPATH/bin/numen -t $out/bin
    export NUMEN_SKIP_BINARY=yes
    export NUMEN_SKIP_CHECKS=yes
    export NUMEN_DEFAULT_PHRASES_DIR=/etc/numen/phrases
    export NUMEN_SCRIPTS_DIR=/etc/numen/scripts
    ./install-numen.sh $out /bin

    runHook postInstall
  '';

  postInstall = ''
    scdoc < doc/numen.1.scd > numen.1
    installManPage numen.1
  '';

  postFixup = ''
    wrapProgram $out/bin/numen \
      --prefix PATH : ${
        lib.makeBinPath [
          dotool
          alsa-utils
          coreutils
          procps
          gawk
          libnotify
          dmenu
          gnused
        ]
      } \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libxkbcommon
          stdenv.cc.cc.lib
        ]
      }
    wrapProgram $out/bin/numenc \
      --prefix PATH : ${lib.makeBinPath [ coreutils ]}
  '';
  meta = {
    homepage = "https://git.sr.ht/~geb/numen";
    description = "Voice control for handsfree computing";
    license = lib.licenses.agpl3Only;
    maintainers = [
      {
        name = "Lorenz Bischof";
        github = "LorenzBischof";
      }
    ];
    mainProgram = "numen";
    platforms = lib.platforms.linux;
  };
}
