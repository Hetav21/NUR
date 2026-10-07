{
  lib,
  callPackage,
  stdenvNoCC,
  makeBinaryWrapper,
  t3code-unwrapped ? callPackage ./unwrapped.nix { },
  providerPackages ? [ ],
}:

stdenvNoCC.mkDerivation {
  pname = "t3code";
  inherit (t3code-unwrapped) version;

  outputs = [
    "out"
    "desktop"
  ];

  dontUnpack = true;
  strictDeps = true;

  nativeBuildInputs = [ makeBinaryWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$desktop/bin"

    sslCertHook='if [ -z "''${SSL_CERT_FILE:-}" ]; then
      if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
        export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
      elif [ -f /etc/ssl/certs/ca-bundle.crt ]; then
        export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
      fi
    fi'

    makeWrapper ${t3code-unwrapped}/bin/t3 "$out/bin/t3" \
      ${
        lib.optionalString (
          providerPackages != [ ]
        ) "--prefix PATH : ${lib.escapeShellArg (lib.makeBinPath providerPackages)}"
      } \
      --run "$sslCertHook"
    ln -s ${t3code-unwrapped}/share "$out/share"

    makeWrapper ${t3code-unwrapped.desktop}/bin/t3code-desktop \
      "$desktop/bin/t3code-desktop" \
      ${
        lib.optionalString (
          providerPackages != [ ]
        ) "--prefix PATH : ${lib.escapeShellArg (lib.makeBinPath providerPackages)}"
      } \
      --run "$sslCertHook" \
      --inherit-argv0
    ln -s ${t3code-unwrapped.desktop}/share "$desktop/share"

    # Also install desktop entry and wrapper into $out for standard NUR package usage
    makeWrapper ${t3code-unwrapped.desktop}/bin/t3code-desktop \
      "$out/bin/t3code-desktop" \
      ${
        lib.optionalString (
          providerPackages != [ ]
        ) "--prefix PATH : ${lib.escapeShellArg (lib.makeBinPath providerPackages)}"
      } \
      --run "$sslCertHook" \
      --inherit-argv0
    ln -s t3code-desktop "$out/bin/t3code"

    mkdir -p "$out/share"
    cp -r ${t3code-unwrapped.desktop}/share/* "$out/share/" 2>/dev/null || true

    ${lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
      sourceApp=${lib.escapeShellArg "${t3code-unwrapped.desktop}/Applications/${t3code-unwrapped.appName}.app"}
      targetApp="$desktop/Applications/${t3code-unwrapped.appName}.app"
      mkdir -p "$targetApp/Contents/MacOS"
      ln -s "$sourceApp/Contents/Info.plist" "$targetApp/Contents/Info.plist"
      ln -s "$sourceApp/Contents/Resources" "$targetApp/Contents/Resources"
      ln -s ../../../../bin/t3code-desktop \
        "$targetApp/Contents/MacOS/${t3code-unwrapped.appName}"
    ''}

    runHook postInstall
  '';

  passthru = {
    category = "AI Coding Agents";
    inherit providerPackages;
    inherit (t3code-unwrapped) pnpmDeps resourceMonitor src;
    unwrapped = t3code-unwrapped;
    desktop = t3code-unwrapped.desktop;
  };

  meta = t3code-unwrapped.meta // {
    description = "Control surface for coding agents";
    mainProgram = "t3code";
  };
}
