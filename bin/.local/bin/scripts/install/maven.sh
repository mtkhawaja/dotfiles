#!/usr/bin/env bash

MAVEN_VERSION=${MAVEN_VERSION:-"3.9.6"}
DOWNLOAD_URL="https://dlcdn.apache.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz"
MAVEN_HOME=${MAVEN_HOME:-"$HOME/.local/bin/tools/apache-maven"}

if [ -z "$MAVEN_HOME" ] || [ -z "$DOWNLOAD_URL" ] || [ -z "$MAVEN_HOME" ]; then
  echo "Error: MAVEN_HOME ($MAVEN_HOME), MAVEN_VERSION ($MAVEN_VERSION), and DOWNLOAD_URL ($DOWNLOAD_URL) must not be empty"
  exit 1
fi

echo "Installing Maven $MAVEN_VERSION to $MAVEN_HOME"

rm -rf "$MAVEN_HOME"
mkdir -p "$MAVEN_HOME"
pushd "$MAVEN_HOME" >/dev/null || {
  echo "Error: $MAVEN_HOME does not exist"
  exit 1
}
curl -L "$DOWNLOAD_URL" -o maven.zip
tar xvf maven.zip --strip-components=1
rm maven.zip

popd >/dev/null || {
  echo "Failed to change directory to previous directory"
  exit 1
}
