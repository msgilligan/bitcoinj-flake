{
inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
};
outputs = {self, nixpkgs, ...}:
  let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forEachSystem = f: builtins.listToAttrs (map (system: {
        name = system;
        value = f system;
      }) systems);
  in {
  packages = forEachSystem (system:
    let
      pkgs = import nixpkgs {
          inherit system;
      };
      protobuf = pkgs.protobuf;
      jdk = pkgs.openjdk17_headless;
      gradle = pkgs.gradle_8.override {
        java = jdk;         # Run Gradle with this JDK
      };
      version = "0.17.1";
      src = pkgs.fetchFromGitHub {
        owner = "bitcoinj";
        repo = "bitcoinj";
        rev = "v${version}";
        sha256 = "sha256-OAO7uLxO5dcVwRl+PPseSqderVSyw6QSHH0fLDIbvIE=";
      };
    in {
      bitcoinj-core =
        let
          pname = "bitcoinj-core";
          self = pkgs.stdenv.mkDerivation (_finalAttrs: {
            inherit version src pname;

            nativeBuildInputs = [gradle protobuf];

            mitmCache = gradle.fetchDeps {
              pkg = self;
              # update or regenerate this by running
              #  $(nix build .#bitcoinj-core.mitmCache.updateScript --print-out-paths)
              data = ./deps.json;
            };

            gradleBuildTask = ":bitcoinj-core:publishToMavenLocal";
            gradleFlags = [ "--no-build-cache --no-daemon --no-parallel --info --stacktrace" ];
            doCheck = false;

            postPatch = ''
              substituteInPlace core/build.gradle \
                --replace-fail "artifact = 'com.google.protobuf:protoc:4.29.3'" \
                               "path = System.getenv('PROTOC') ?: 'protoc'"
             substituteInPlace settings.gradle \
                --replace-fail "include 'wallettemplate'" "" \
                --replace-fail "project(':wallettemplate').name = 'bitcoinj-wallettemplate'" ""
            '';

            preBuild = ''
              export PROTOC=${protobuf}/bin/protoc
              gradleFlagsArray+=("-Dmaven.repo.local=$NIX_BUILD_TOP/$sourceRoot/repo")
              echo "gradleFlagsArray: ''${gradleFlagsArray[@]}"
            '';

            installPhase = ''
              mkdir -p $out/share/${pname} $out/share/java
              cp repo/org/bitcoinj/bitcoinj-core/${version}/bitcoinj-core-${version}* $out/share/${pname}
              ln -s $out/share/${pname}/bitcoinj-core-${version}.jar $out/share/java
            '';
          });
        in
          self;
      bitcoinj-core-deps =
        let
          pname = "bitcoinj-core-deps";
          self = pkgs.stdenv.mkDerivation (_finalAttrs: {
            inherit version src pname;

            nativeBuildInputs = [gradle protobuf];

            mitmCache = gradle.fetchDeps {
              pkg = self;
              # update or regenerate this by running
              #  $(nix build .#bitcoinj-core.mitmCache.updateScript --print-out-paths)
              data = ./deps.json;
            };

            gradleBuildTask = ":bitcoinj-wallettool:installDist";
            gradleFlags = [ "--no-build-cache --no-daemon --no-parallel --info --stacktrace" ];
            doCheck = false;

            postPatch = ''
              substituteInPlace core/build.gradle \
                --replace-fail "artifact = 'com.google.protobuf:protoc:4.29.3'" \
                               "path = System.getenv('PROTOC') ?: 'protoc'"
             substituteInPlace settings.gradle \
                --replace-fail "include 'wallettemplate'" "" \
                --replace-fail "project(':wallettemplate').name = 'bitcoinj-wallettemplate'" ""
            '';

            preBuild = ''
              export PROTOC=${protobuf}/bin/protoc
              gradleFlagsArray+=("-Dmaven.repo.local=$NIX_BUILD_TOP/$sourceRoot/repo")
              echo "gradleFlagsArray: ''${gradleFlagsArray[@]}"
            '';

            installPhase = ''
              mkdir -p $out/share/java
              cp wallettool/build/install/wallet-tool/lib/* $out/share/java
              rm $out/share/java/bitcoinj-*
              rm $out/share/java/bcprov-jdk15to18-*
            '';
          });
        in
          self;
    });
  };
}
