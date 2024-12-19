#!/bin/sh

set -eu

UPSTREAM=https://github.com/ggerganov/llama.cpp.git
WORKDIR=llama/vendor
COMMIT=40c6d79fb52f995f47507fedfeaae2ac05d9b35c

usage() {
    echo "usage: [-n] $(basename $0) ACTION ..."
    echo
    echo "Actions:"
    echo "  all           Clone, checkout, apply patches, and sync"
    echo "  checkout      Checkout the upstream commit: $COMMIT"
    echo "  patch         Apply patches"
    echo "  format-patch  Format patches"
    echo "  sync          Sync local files"
    echo "  clean         Remove the vendor repository"
    echo
    echo "Flags:"
    echo "  -n            Dry run"
    echo "  -h            Show this help message"
    exit 1
}

error() { status "ERROR: $@"; exit 1; }
status() { echo ">>> $@"; }

DRYRUN=
while getopts "hn" OPTION; do
    case $OPTION in
        n) DRYRUN=echo ;;
        h) usage ;;
    esac
done

shift $(( OPTIND - 1 ))
[ $# -eq 0 ] && usage

checkout() {
    [ ! -d "$WORKDIR/.git" ] && $DRYRUN git clone "$UPSTREAM" "$WORKDIR"
    $DRYRUN git -C "$WORKDIR" checkout "$COMMIT"
}

patch() {
    for PATCH in llama/patches/*.patch; do
        if ! $DRYRUN git -C "$WORKDIR" am -3 "$(realpath $PATCH)"; then
            git -C "$WORKDIR" am --abort
            error "Failed to apply $PATCH"
        fi
    done
}

sync() {
    for SOURCE_TARGET in "$WORKDIR/ llama/llama.cpp/" "$WORKDIR/ggml/ ml/backend/ggml/ggml/"; do
        set -- $SOURCE_TARGET
        SOURCE=$1; TARGET=$2
        rsync ${DRYRUN:+-n} -arvzc --delete -f "merge $TARGET/.rsync-filter" $SOURCE $TARGET
        rsync ${DRYRUN:+-n} -arvzc --delete --include LICENSE --exclude '*' $WORKDIR $TARGET
    done
}

format_patch() {
    $DRYRUN rm llama/patches/*.patch
    $DRYRUN git -C "$WORKDIR" format-patch \
        --no-signature \
        --no-numbered \
        --zero-commit \
        -o $(realpath llama/patches) \
        "$COMMIT"
}

for ARG in "$@"; do
    case $ARG in
        all) checkout && patch && sync ;;
        checkout) checkout ;;
        patch) patch ;;
        sync) sync ;;
        format-patch) format_patch ;;
        clean) rm -rf "$WORKDIR" ;;
        *) usage ;;
    esac
done
