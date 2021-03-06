{ stdenv, substituteAll, fetchFromGitHub, python3Packages, glfw, libunistring,
  harfbuzz, fontconfig, pkgconfig, ncurses, imagemagick, xsel,
  libstartup_notification, libX11, libXrandr, libXinerama, libXcursor,
  libxkbcommon, libXi, libXext, wayland-protocols, wayland,
  which, dbus, fetchpatch,
  Cocoa,
  CoreGraphics,
  Foundation,
  IOKit,
  Kernel,
  OpenGL,
  cf-private,
  libicns,
  libpng,
  librsvg,
  optipng,
  python3,
  zlib,
}:

with python3Packages;
buildPythonApplication rec {
  pname = "kitty";
  version = "0.14.0";
  format = "other";

  src = fetchFromGitHub {
    owner = "kovidgoyal";
    repo = "kitty";
    rev = "v${version}";
    sha256 = "122573l7xirs9dsi5p8gra47qpgxb3vahqp2r0c043pgz4i22v5z";
  };

  buildInputs = [
    ncurses harfbuzz
  ] ++ stdenv.lib.optionals stdenv.isDarwin [
    Cocoa
    CoreGraphics
    Foundation
    IOKit
    Kernel
    OpenGL
    cf-private
    libpng
    python3
    zlib
  ] ++ stdenv.lib.optionals stdenv.isLinux [
    fontconfig glfw libunistring libX11
    libXrandr libXinerama libXcursor libxkbcommon libXi libXext
    wayland-protocols wayland dbus
  ];

  nativeBuildInputs = [
    pkgconfig which sphinx ncurses
  ] ++ stdenv.lib.optionals stdenv.isDarwin [
    imagemagick
    libicns  # For the png2icns tool.
    librsvg
    optipng
  ];

  outputs = [ "out" "terminfo" ];

  patches = [
    (substituteAll {
      src = ./fix-paths.patch;
      libstartup_notification = "${libstartup_notification}/lib/libstartup-notification-1.so";
    })
  ] ++ stdenv.lib.optionals stdenv.isDarwin [
    ./no-lto.patch
    ./no-werror.patch
    ./png2icns.patch
  ];

  buildPhase = if stdenv.isDarwin then ''
    make app
  '' else ''
    ${python.interpreter} setup.py linux-package
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    ${if stdenv.isDarwin then ''
    mkdir "$out/bin"
    ln -s ../Applications/kitty.app/Contents/MacOS/kitty-deref-symlink "$out/bin/kitty"
    mkdir "$out/Applications"
    cp -r kitty.app "$out/Applications/kitty.app"
    '' else ''
    cp -r linux-package/{bin,share,lib} $out
    ''}
    wrapProgram "$out/bin/kitty" --prefix PATH : "$out/bin:${stdenv.lib.makeBinPath [ imagemagick xsel ]}"
    runHook postInstall

    # ZSH completions need to be invoked with `source`:
    # https://github.com/kovidgoyal/kitty/blob/8ceb941051b89b7c50850778634f0b6137aa5e6e/docs/index.rst#zsh
    mkdir -p "$out/share/"{bash-completion/completions,fish/vendor_completions.d,zsh/site-functions}
    "$out/bin/kitty" + complete setup fish > "$out/share/fish/vendor_completions.d/kitty.fish"
    "$out/bin/kitty" + complete setup bash > "$out/share/bash-completion/completions/kitty.bash"
  '';

  postInstall = ''
    terminfo_src=${if stdenv.isDarwin then
      ''"$out/Applications/kitty.app/Contents/Resources/terminfo"''
      else
      "$out/share/terminfo"}

    mkdir -p $terminfo/share
    mv "$terminfo_src" $terminfo/share/terminfo

    mkdir -p $out/nix-support
    echo "$terminfo" >> $out/nix-support/propagated-user-env-packages
  '';

  meta = with stdenv.lib; {
    homepage = https://github.com/kovidgoyal/kitty;
    description = "A modern, hackable, featureful, OpenGL based terminal emulator";
    license = licenses.gpl3;
    platforms = platforms.darwin ++ platforms.linux;
    maintainers = with maintainers; [ tex rvolosatovs ];
  };
}
