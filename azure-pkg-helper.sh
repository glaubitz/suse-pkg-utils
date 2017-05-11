#!/bin/bash
#
# Simple Azure SDK for Python RPM packaging helper
#
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
# Author: John Paul Adrian Glaubitz <glaubitz@suse.com>

#set -x

function usage() {
  cat <<EOF

    azure-pkg-helper.sh [opt] <Path to Azure Python SDK>

     -h             show this help message
     -p		    print package information
     -s		    generate spec files for RPM
     -v             verbose
     -z		    generate ZIP source archives

EOF
  exit 0;
}

OPT_PRINT=0
OPT_SPECGEN=0
OPT_VERBOSE=0
OPT_ZIPGEN=0

REMOVE_ARGS=0
while getopts ":hpv:" opt ; do
    case "$opt" in
        h) usage ;;
	p) OPT_PRINT="1" ; REMOVE_ARGS="$((REMOVE_ARGS + 1))" ;;
	s) OPT_SPECGEN="1" ; REMOVE_ARGS="$((REMOVE_ARGS + 1))" ;;
        v) OPT_VERBOSE="1" ; REMOVE_ARGS="$((REMOVE_ARGS + 1))" ;;
	z) OPT_ZIPGEN="1" ; REMOVE_ARGS="$((REMOVE_ARGS + 1))" ;;
    esac
done
shift "$REMOVE_ARGS"

if [ $1 ] && [ -d $1 ] ; then

    cd $1

    if [ $OPT_ZIPGEN == "1" ] || [ $OPT_SPECGEN == "1" ] ; then
	TARGET=$(mktemp -d)
    fi

    for PACKAGE in azure* ; do
	if [ -d $PACKAGE ] ; then
	    VERSIONFILE=$(find $PACKAGE -name version.py | sort | tail -n1)
	    SETUPFILE=$PACKAGE/setup.py
	    if [ $VERSIONFILE ] ; then
		VERSION=$(grep VERSION $VERSIONFILE | sed -e 's/VERSION\s*\=\s*\"\([A-Z,a-z,0-9,\.]*\)\"/\1/g')
	    else
		VERSIONFILE=$SETUPFILE
		VERSION=$(grep version\= $SETUPFILE | sed -e "s/.*version\s*\=\s*'\([A-Z,a-z,0-9,\.]*\)'.*/\1/g")
	    fi
	    LICENSE=$(grep license= $SETUPFILE |sed -e "s/.*license\='\(.*\)',/\1/g")
	    DESCRIPTION=$(sed -n -r -e '/^This\sis\sthe/,/(^This\spackage\s\has\sbeen\stested|^All\spackages|^This\spackage\sprovides|^It\sprovides)/p' $PACKAGE/README.rst)
	    REQUIRES=$(sed -n -r -e '/.*install_requires=.*/,/.*\],.*/p' $PACKAGE/setup.py | sed -n -r -e "s/.*'([A-Z,a-z,0-9,-]*(=|~=)?.*)',/\1/pg")

	    if [ $OPT_PRINT == "1" ] ; then
		echo -e "Package:\t"$PACKAGE
		echo -e "Source:\t\t"$PACKAGE-$VERSION.zip
		echo -e "Version:\t"$VERSION
		echo -e "License:\t"$LICENSE
		echo -e "Summary:\t"$(echo "$DESCRIPTION" | head -n1 | sed -e 's/.*\(Microsoft.*\)\./\1/g')
		echo -e "Description:\t"
		echo "$(echo "$DESCRIPTION" | sed -e 's/\(.*\)/\t\t\1/g')"
		echo -e "Dependencies:"

		echo -e "$(echo "$REQUIRES" | sed -e 's/\(.*\)/\t\t\1/g')\n"
	    fi

	    if [ $OPT_SPECGEN == "1" ] ; then
		echo "Writing python-$PACKAGE.spec ..."
	    fi

	    if [ $OPT_ZIPGEN == "1" ] ; then
		echo "Generating $TARGET/$PACKAGE-$VERSION.zip ..."
		zip -q -r $TARGET/$PACKAGE-$VERSION.zip $PACKAGE
	    fi
	fi
    done

    if [ $OPT_ZIPGEN == "1" ] || [ $OPT_SPECGEN == "1" ] ; then
	echo "Result in :"$TARGET
    fi
else
    usage
fi
