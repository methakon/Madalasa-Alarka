#!/usr/bin/env bash
# Build the pinned C++ dependencies (jsoncpp, Drogon) from source into a prefix.
# Same script for developers and CI, so "works on my machine" and CI cannot drift.
#
#   PREFIX=$HOME/.cache/ma-deps backend/scripts/build_deps.sh
#   MA_DROGON_PG=ON   (default) build Drogon's PostgreSQL client; needs libpq headers (libpq-dev)
#   MA_DROGON_PG=OFF  build without a database client (enough for the HTTP skeleton tests)
#
# NOTE: Drogon only builds its PostgreSQL client when BUILD_ORM is ON (BUILD_POSTGRESQL depends on it). An earlier
# version of this script passed BUILD_ORM=OFF, which silently produced a Drogon with NO database support.
#
# Then configure the backend with:  cmake -S backend -B build -DCMAKE_PREFIX_PATH=$PREFIX
set -euo pipefail

JSONCPP_TAG="${JSONCPP_TAG:-1.9.5}"
DROGON_TAG="${DROGON_TAG:-v1.9.14}"
PREFIX="${PREFIX:?set PREFIX to an install directory}"
PG="${MA_DROGON_PG:-ON}"
JOBS="${JOBS:-$(nproc)}"
WORK="${WORK:-$(mktemp -d)}"

mkdir -p "$PREFIX" "$WORK"
if [ -f "$PREFIX/.ma-deps-$JSONCPP_TAG-$DROGON_TAG-orm-pg$PG" ]; then
  echo "dependencies already built in $PREFIX"; exit 0
fi

git clone --depth 1 --branch "$JSONCPP_TAG" https://github.com/open-source-parsers/jsoncpp "$WORK/jsoncpp"
cmake -S "$WORK/jsoncpp" -B "$WORK/jsoncpp/build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF \
  -DCMAKE_INSTALL_RPATH="$PREFIX/lib" -DJSONCPP_WITH_TESTS=OFF -DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON
cmake --build "$WORK/jsoncpp/build" -j "$JOBS" --target install

git clone --depth 1 --branch "$DROGON_TAG" --recurse-submodules --shallow-submodules \
  https://github.com/drogonframework/drogon "$WORK/drogon"
cmake -S "$WORK/drogon" -B "$WORK/drogon/build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DBUILD_CTL=OFF -DBUILD_EXAMPLES=OFF -DBUILD_ORM=ON -DBUILD_MYSQL=OFF -DBUILD_SQLITE=OFF \
  -DBUILD_REDIS=OFF -DBUILD_BROTLI=OFF -DBUILD_YAML_CONFIG=OFF -DBUILD_POSTGRESQL="$PG" \
  -DCMAKE_INSTALL_RPATH="$PREFIX/lib"
cmake --build "$WORK/drogon/build" -j "$JOBS" --target install

touch "$PREFIX/.ma-deps-$JSONCPP_TAG-$DROGON_TAG-orm-pg$PG"
echo "built jsoncpp $JSONCPP_TAG and Drogon $DROGON_TAG into $PREFIX (postgres=$PG)"
