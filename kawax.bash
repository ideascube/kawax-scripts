#!/bin/bash

#
# configuration
#

DEBUGMODE=1

CATALOGS_CACHE=/var/kawax/catalogs

CATALOGS=(
    http://catalog.ideascube.org/kiwix.yml
    http://catalog.ideascube.org/static-sites.yml
    http://catalog.yohanboniface.me/catalog.yml
)

URLS_KIWIX=/var/kawax/kiwix.rsync
URLS_OTHER=/var/kawax/others.wget

PACKAGE_CACHE=/srv/kawax
PACKAGE_CACHE_KIWIX=${PACKAGE_CACHE}/download.kiwix.org/
PACKAGE_CACHE_OTHER=${PACKAGE_CACHE}/other/

SYNOLOGY_CACHE=/srv/synology

WGET_USERAGENT="Mirroring/catalog.ideascube.org"
WGET_OPTIONS="--continue --timestamping --recursive --mirror --user-agent='$WGET_USERAGENT'"

# long options translated from the kiwix mirroring one-liner
RSYNC_OPTIONS="--compress --recursive --links --perms --times --devices --specials --delete"

#
# functions
#

show_usage() {
    echo "Usage: $( basename $0 ) <action>

Actions:

    update_catalogs     Update the catalogs cache
    extract_urls        Extracts the URLs from catalogs to files
    rsync_kiwix         Downloads ZIMs from Kiwix
    wget_other          Downloads the other packages
    rsync_synology      Updates the Synology cache
    all                 All of the above
    help                This very help message
"
}

edebug() {
    [[ $DEBUGMODE -eq 1 ]] && echo "[+] $@" >&2
}

get_latest_zims_from_kiwix() {
    for ENTRY in `rsync --recursive --list-only download.kiwix.org::download.kiwix.org/portable/ | \
        grep ".zip" | grep -F -v '_nopic_' | tr -s ' ' | cut -d ' ' -f5 | sort -r` ; do
        RADICAL=`echo $ENTRY | sed 's/_20[0-9][0-9]-[0-9][0-9]\.zim//g'`
        if [[ $LAST != $RADICAL ]] ; then
            echo $ENTRY
            LAST=$RADICAL
        fi
    done
}

urls_from_catalog() {
    local CATALOG=$1
    awk -F'"' ' /url:/ { print $2 }' $CATALOG
}

radical_urls_from_catalog() {
    local CATALOG=$1
    urls_from_catalog $CATALOG | sed 's/_20[0-9][0-9]-[0-9][0-9]\.zip//'
}

update_catalogs() {
    for i in ${CATALOGS[@]} ; do
        edebug $i
        wget $i -q -x -P ${CATALOGS_CACHE}/
    done
}

rsync_kiwix() {
    sed -i -e 's@http://download.kiwix.org/portable/@@g' $URLS_KIWIX
    # FIXME: log somewhere
    rsync $RSYNC_OPTIONS --files-from=$URLS_KIWIX \
        download.kiwix.org::download.kiwix.org/portable/ ${PACKAGE_CACHE_KIWIX}
}

wget_other() {
    # FIXME: log somewhere
    wget --input-file=$URLS_OTHER $WGET_OPTIONS -P ${PACKAGE_CACHE}/other/
}

extract_urls() {
    rm -f $URLS_KIWIX $URLS_OTHER
    for thiscatalog in $( find $CATALOGS_CACHE -type f -name '*.yml' ) ; do
        edebug "Getting URLs from ${thiscatalog}..."
        while read thisline ; do
            thisurl=$( echo $thisline | awk ' /url:/ { print $2 }' | tr -d '"' )
            if [[ "$thisurl" =~ "http://download.kiwix.org" ]] ; then
                edebug "thisurl->kiwix-> $thisurl"
                echo $thisurl >> $URLS_KIWIX
            elif [ -n "$thisurl" ] ; then
                edebug "thisurl->others-> $thisurl"
                echo $thisurl >> $URLS_OTHER
            fi
        done < $thiscatalog
    done
}

rsync_synology() {
    # FIXME: test the link before
    rsync -av admin@10.10.8.9:'/volume1/Contenus-Educ/Gestion\ des\ contenus' ${SYNOLOGY_CACHE}/
}

# init
mkdir -p $CATALOGS_CACHE $PACKAGE_CACHE_KIWIX $PACKAGE_CACHE_OTHER $SYNOLOGY_CACHE


case "$1" in
    update_catalogs|extract_urls|rsync_kiwix|wget_other|rsync_synology)
        $1
        ;;
    all)
        update_catalogs
        extract_urls
        rsync_kiwix
        wget_other
        rsync_synology
        ;;
    help)
        show_usage
        ;;
    *)
        echo "Error: unknown action: $1" >&2
        show_usage
        exit 1
        ;;
esac

