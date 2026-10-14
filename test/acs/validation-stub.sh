#!/bin/sh
set -eu

case "${0##*/}" in
    id) printf '%s\n' "${STUB_UID:-0}" ;;
    uname)
        case "${1:-}" in
            -s) printf '%s\n' "${STUB_OS:-Linux}" ;;
            -m) printf '%s\n' "${STUB_ARCH:-x86_64}" ;;
            *) exit 98 ;;
        esac
        ;;
    getconf)
        [ "${1:-}" = GNU_LIBC_VERSION ] || exit 98
        [ "${STUB_LIBC:-glibc 2.39}" != musl ] || exit 1
        printf '%s\n' "${STUB_LIBC:-glibc 2.39}"
        ;;
    *)
        printf '%s\n' "${0##*/}" >> "$STUB_EFFECT_LOG"
        printf 'Blocked unexpected command: %s\n' "${0##*/}" >&2
        exit 99
        ;;
esac
