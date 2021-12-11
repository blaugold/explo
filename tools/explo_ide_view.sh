#!/usr/bin/env bash

set -e

exploIdeViewDir=packages/explo_ide_view
exploIdeViewBuildDir="$exploIdeViewDir/build/web"
exploCodeViewDir="explo-code/dist/explo_ide_view"

function build {
    cd "$exploIdeViewDir"
    rm -rf "$exploIdeViewBuildDir"
    flutter build web --pwa-strategy none
}

function copyToExploCode {
    rm -rf "$exploCodeViewDir"
    mkdir -p "$exploCodeViewDir"
    cp -a "$exploIdeViewBuildDir/"* "$exploCodeViewDir"
}

"$@"
