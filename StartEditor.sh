#!/bin/sh
exec sh "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/tools/launch.sh" editor "$@"
