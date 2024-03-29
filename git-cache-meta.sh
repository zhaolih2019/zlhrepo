#!/bin/sh -e

#git-cache-meta -- simple file meta data caching and applying.
#Simpler than etckeeper, metastore, setgitperms, etc.
#from http://www.kerneltrap.org/mailarchive/git/2009/1/9/4654694
#modified by n1k
#modified by the-mars
#modified by bizonix
# - save all files metadata not only from other users
# - save numeric uid and gid
#2012-03-05 - added filetime, andris9
#2012-05-22 - added fix for non ASCII characters and list size, merge chgrp into chown command
#2014-03-18 - the-mars: store properties for dirs too
#2015-04-17 - time zone offset fallback; fix leading-dash-name error; avoid deeper find;
#              better quote file names; better directory listing; merge short opts; by Danny Lin
#2015-05-07 - for Mac OS X, `brew install findutils gawk coreutils`

: ${GIT_CACHE_META_FILE=.git_cache_meta}

if [[ "$OSTYPE" == "darwin"* ]]; then
    GNU='g'
fi
for bin in find touch awk ; do
    BIN=$( echo $bin | tr '[:lower:]' '[:upper:]')
    eval ': ${'$BIN':=$(which $GNU$bin)}'
    if [ "$GNU" == 'g' ] && ! [[ "${!BIN}" =~ /$GNU$bin ]]  ; then
        echo "gnu version of '$bin' file not found." >&2
        exit 1
    fi
done

: ${Tz:=$($FIND -prune -printf '%Tz')}
: ${Tz:=$(date +%z)}
if ! [ "$Tz" ]; then
    echo "%z not supported in 'strftime' in C library." >&2
    exit 1
fi

case $@ in
    --store|--stdout)
    case $1 in --store) exec > $GIT_CACHE_META_FILE; esac
    { git ls-tree --name-only -rdz $(git write-tree) | xargs -0 -I NAME $FIND ./NAME -maxdepth 0 \
        \( -printf 'chown -h %U:%G \0%p\n' \) , \
        \( \! -type l -printf 'chmod %#m \0%p\n' \) , \
        \( -printf $TOUCH' -hcmd "%TY-%Tm-%Td %TH:%TM:%TS '$Tz'" \0%p\n' \) , \
        \( -printf $TOUCH' -hcad "%AY-%Am-%Ad %AH:%AM:%AS '$Tz'" \0%p\n' \)
      git ls-files -z | xargs -0 -I NAME $FIND ./NAME -maxdepth 0 \
        \( -printf 'chown -h %U:%G \0%p\n' \) , \
        \( \! -type l -printf 'chmod %#m \0%p\n' \) , \
        \( -printf $TOUCH' -hcmd "%TY-%Tm-%Td %TH:%TM:%TS '$Tz'" \0%p\n' \) , \
        \( -printf $TOUCH' -hcad "%AY-%Am-%Ad %AH:%AM:%AS '$Tz'" \0%p\n' \)
    } | $AWK 'BEGIN {FS="\0"}; {print $1 "'\''" gensub(/'\''/, "'\''\\\\'\'''\''", "g", $2) "'\''" }' ;;
    --apply) sh -e $GIT_CACHE_META_FILE;;
    *) 1>&2 echo "Usage: $0 --store|--stdout|--apply"; exit 1;;
esac