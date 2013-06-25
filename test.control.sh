#!/bin/sh


case "$@" in

PKG_NAME) echo "firefox" ;;

PKG_VERSION) echo "20.1" ;;

PKG_DEP) echo "gtk3" ;;

BIN_PATH) echo "/usr/bin/" ;; #path for binary

LIB_PATH) echo "usr/lib/firefox" ;; #path for libraries, or config ;;

SHARE_PATH) echo "/usr/share/firefox" ;;



esac


