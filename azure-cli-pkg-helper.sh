#!/bin/bash
#
# Simple Azure CLI for Python RPM packaging helper
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

    azure-cli-pkg-helper.sh [opt]

     -d             path to Azure CLI for Python (required)
     -f             fetch source package from PyPI
     -h             show this help message
     -H             include HISTORY.rst file in %doc section
     -i             print package information
     -l             generate LICENSE files for RPM
     -n             include namespace files instead using of nspkg packages
     -p             specify package to work with
     -q             specify directory with additional patches
     -r             relax version dependencies (== -> >=)
     -s             generate spec files for RPM
     -v             verbose
     -z             generate ZIP source archives

EOF
  exit 0;
}

OPT_FETCHSOURCE=0
OPT_LICENSEGEN=0
OPT_HISTORYFILE=0
OPT_INFO=0
OPT_NAMESPACEFILES=1
OPT_PACKAGE="azure*"
OPT_PATCHDIR=""
OPT_RELAX=0
OPT_SPECGEN=0
OPT_VERBOSE=0
OPT_ZIPGEN=0

PIPY_HOSTING_SRC=https://files.pythonhosted.org/packages/source

REMOVE_ARGS=0
while getopts "d:fhHilnp:q:rsvz" opt ; do
    case "$opt" in
	d) OPT_AZURE_DIR="$OPTARG" ; REMOVE_ARGS="$((REMOVE_ARGS + 2))" ;;
	f) OPT_FETCHSOURCE="1" ; REMOVE_ARGS="$((REMOVE_ARGS + 1))" ;;
	h) usage ;;
	H) OPT_HISTORYFILE="1" ; REMOVE_ARGS="$((REMOVE_ARGS + 1))" ;;
	i) OPT_INFO="1" ; REMOVE_ARGS="$((REMOVE_ARGS + 1))" ;;
	l) OPT_LICENSEGEN="1" ; REMOVE_ARGS="$((REMOVE_ARGS + 1))" ;;
	n) OPT_NAMESPACEFILES="0" ; REMOVE_ARGS="$((REMOVE_ARGS + 1))" ;; 
	p) OPT_PACKAGE="$OPTARG" ; REMOVE_ARGS="$((REMOVE_ARGS + 2))" ;;
	q) OPT_PATCHDIR="$OPTARG" ; REMOVE_ARGS="$((REMOVE_ARGS + 2))" ;;
	r) OPT_RELAX="1" ; REMOVE_ARGS="$((REMOVE_ARGS + 1))" ;;
	s) OPT_SPECGEN="1" ; REMOVE_ARGS="$((REMOVE_ARGS + 1))" ;;
	v) OPT_VERBOSE="1" ; REMOVE_ARGS="$((REMOVE_ARGS + 1))" ;;
	z) OPT_ZIPGEN="1" ; REMOVE_ARGS="$((REMOVE_ARGS + 1))" ;;
    esac
done
shift "$REMOVE_ARGS"

if [ "$OPT_AZURE_DIR" ] && [ -d "$OPT_AZURE_DIR" ] ; then

    cd "$OPT_AZURE_DIR"

    if [ $OPT_ZIPGEN == "1" ] || [ $OPT_SPECGEN == "1" ] ; then
	TARGET=$(mktemp -d)
    fi

    for PACKAGE in $OPT_PACKAGE ; do
	if [ -d $PACKAGE ] ; then
	    # VERSIONFILE=$(find $PACKAGE -name version.py | sort | tail -n1)
	    SETUPFILE=$PACKAGE/setup.py
	    if [ $VERSIONFILE ] ; then
		VERSION=$(grep -w 'VERSION\s*\=\|version\s*\=' $VERSIONFILE | sed -e 's/.*[VERSION,version]\s*\=\s*\"\([A-Z,a-z,0-9,\.]*\)\(\+dev\)*\"/\1/g')
	    else
		VERSIONFILE=$SETUPFILE
		VERSION=$(grep -w 'VERSION\s*\=\|version\s*\=' $VERSIONFILE | sed -e 's/.*[VERSION,version]\s*\=\s*\"\([A-Z,a-z,0-9,\.]*\)\(\+dev\)*\"/\1/g')
	    fi
	    LICENSE=$(grep license= $SETUPFILE |sed -e "s/.*license\='\(.*\)',/\1/g")

	    case $LICENSE in
		MIT*)
		    LICENSE="MIT"
		    ;;
		Apache*2.0*)
		    LICENSE="Apache-2.0"
		    ;;
		*)
		    echo "Error: Unknown license. Exiting."
		    ;;
	    esac

	    DESCRIPTION=$(sed -n -r -e '/^Microsoft\sAzure\s/,/^\+.*/p' $PACKAGE/README.rst | grep -ve '^[\+,\=]')
	    SUMMARY=$(echo "$DESCRIPTION" | head -n1 | sed -e 's/.*\(Microsoft.*\)\./\1/g')
	    REQUIRES=$(sed -n -r -e '/.*DEPENDENCIES\s*=.*/,/.*\]$/p' $PACKAGE/setup.py | sed -n -r -e "s/.*[\x22,\x27]([A-Z,a-z,x0-9,-]*)(\[[A-Z,a-z]*\])?(>=|==|~=)?([A-Z,a-z,0-9,\.]*)?[\x22,\x27](\x2c|$)/\1 \3 \4/pg" | sed -e 's/[ \t]*$//')

	    if [ $OPT_NAMESPACEFILES == "1" ] ; then
		EXCLUDEPATH="$(echo $PACKAGE | sed -e 's/\-/\//g')"
		NAMESPACEFILES=$(cd $PACKAGE ; find -path ./$EXCLUDEPATH -prune -false -o -name __init__.py -print0 | xargs -0 grep -l namespace | sed -e "s/^\.\///g")
		NAMESPACEPKGS=$(echo "$NAMESPACEFILES" | sed -e 's/\(^.*\)\/__init__.py/\1-nspkg/g' | sed -e 's/[\/,_]/-/g')
	    fi

	    if [ $OPT_RELAX == "1" ] ; then
		REQUIRES=$(echo "$REQUIRES" | sed -e 's/==/>=/g')
	    fi

	    if curl --output /dev/null --silent --head --fail $PIPY_HOSTING_SRC/${PACKAGE:0:1}/$PACKAGE/$PACKAGE-$VERSION.zip ; then
		SOURCEURL="$PIPY_HOSTING_SRC/${PACKAGE:0:1}/$PACKAGE/$PACKAGE-%{version}.zip"
		FETCHURL="$PIPY_HOSTING_SRC/${PACKAGE:0:1}/$PACKAGE/$PACKAGE-$VERSION.zip"
	    elif curl --output /dev/null --silent --head --fail $PIPY_HOSTING_SRC/${PACKAGE:0:1}/$PACKAGE/$PACKAGE-$VERSION.tar.gz ; then
		SOURCEURL="$PIPY_HOSTING_SRC/${PACKAGE:0:1}/$PACKAGE/$PACKAGE-%{version}.tar.gz"
		FETCHURL="$PIPY_HOSTING_SRC/${PACKAGE:0:1}/$PACKAGE/$PACKAGE-$VERSION.tar.gz"
	    else
		echo "Error: Package $PACKAGE-$VERSION doesn't seem to exist on PyPI."
	    fi

	    if [ $OPT_INFO == "1" ] ; then
		echo -e "Package:\t"$PACKAGE
		echo -e "Source:\t\t"$PACKAGE-$VERSION.zip
		echo -e "Version:\t"$VERSION
		echo -e "License:\t"$LICENSE
		echo -e "Summary:\t"$SUMMARY
		echo -e "Description:\t"
		echo "$(echo "$DESCRIPTION" | sed -e 's/\(.*\)/\t\t\1/g')"
		echo -e "Dependencies:"

		echo -e "$(echo "$REQUIRES" | sed -e 's/\(.*\)/\t\t\1/g')\n"
	    fi

	    if [ $OPT_ZIPGEN == "1" ] || [ $OPT_SPECGEN == "1" ] || [ $OPT_FETCHSOURCE == "1" ] ; then
		mkdir $TARGET/$PACKAGE
	    fi

	    if [ $OPT_FETCHSOURCE == "1" ] ; then
		echo "Downloading source package from PyPI ..."
		cd $TARGET/$PACKAGE
		curl --silent -L -O $FETCHURL
		cd $OLDPWD
	    fi

	    if [ $OPT_SPECGEN == "1" ] ; then
		echo "Writing $PACKAGE.spec ..."
		cat > $TARGET/$PACKAGE/$PACKAGE.spec <<EOF
#
# spec file for package $PACKAGE
#
# Copyright (c) 2019 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#

Name:           $PACKAGE
Version:        $VERSION
Release:        0
Summary:        $SUMMARY
License:        $LICENSE
Group:          System/Management
Url:            https://github.com/Azure/azure-cli
Source:         $SOURCEURL
Source1:        LICENSE.txt
EOF
		PATCHCOUNT=0
		if [ -n "$OPT_PATCHDIR" ] ; then
		    for i in $OPT_PATCHDIR/*.patch ; do
			[ -f $i ] || continue
			PATCHCOUNT=$[PATCHCOUNT+1]
			echo -e "Patch$PATCHCOUNT:         "$(basename $i) >> $TARGET/$PACKAGE/$PACKAGE.spec
		    done
		fi
		cat >> $TARGET/$PACKAGE/$PACKAGE.spec <<EOF
BuildRequires:  fdupes
BuildRequires:  python3-setuptools
EOF
		IFS=$'\n'
		for i in $NAMESPACEPKGS ; do
		    if [ -n "$(echo "$i" | grep -e 'azure-cli-')" ] ; then
			unset PKG_PREFIX
		    else
			PKG_PREFIX="python3-"
		    fi
		    if [ -n "$(echo "$i" |grep -e '.*~=.*')" ] ; then
			UPPER_REQUIRES_VERSION=$[$(echo $i | sed -e 's/.*~=\s\([0-9]*\)\..*/\1/g') + 1].0.0
			echo -e "BuildRequires:  $PKG_PREFIX$i" | sed -e 's/~=/>=/g' >> $TARGET/$PACKAGE/$PACKAGE.spec
			echo -e "BuildRequires:  $PKG_PREFIX$i" | sed -r -e "s/~=\ [0-9,\.]*/< $UPPER_REQUIRES_VERSION/g" >> $TARGET/$PACKAGE/$PACKAGE.spec
		    else
			echo -e "BuildRequires:  $PKG_PREFIX$i" >> $TARGET/$PACKAGE/$PACKAGE.spec
		    fi
		done
		for i in $NAMESPACEPKGS $REQUIRES ; do
		    if [ -n "$(echo "$i" | grep -e 'azure-cli-')" ] ; then
			unset PKG_PREFIX
		    else
			PKG_PREFIX="python3-"
		    fi
		    if [ -n "$(echo "$i" |grep -e '.*~=.*')" ] ; then
			UPPER_REQUIRES_VERSION=$[$(echo $i | sed -e 's/.*~=\s\([0-9]*\)\..*/\1/g') + 1].0.0
			echo -e "Requires:       $PKG_PREFIX$i" | sed -e 's/~=/>=/g' >> $TARGET/$PACKAGE/$PACKAGE.spec
			echo -e "Requires:       $PKG_PREFIX$i" | sed -r -e "s/~=\ [0-9,\.]*/< $UPPER_REQUIRES_VERSION/g" >> $TARGET/$PACKAGE/$PACKAGE.spec
		    else
			echo -e "Requires:       $PKG_PREFIX$i" >> $TARGET/$PACKAGE/$PACKAGE.spec
		    fi
		done
		cat >> $TARGET/$PACKAGE/$PACKAGE.spec <<EOF
Conflicts:      azure-cli < 2.0.0

BuildArch:      noarch

%description
$DESCRIPTION

%prep
%setup -q -n $PACKAGE-%{version}
EOF
		for ((i=1; i<=PATCHCOUNT; i++)); do
		    echo -e "%patch$i -p1" >> $TARGET/$PACKAGE/$PACKAGE.spec
		done
		cat >> $TARGET/$PACKAGE/$PACKAGE.spec <<EOF

%build
install -m 644 %{SOURCE1} %{_builddir}/$PACKAGE-%{version}
python3 setup.py build

%install
python3 setup.py install --root=%{buildroot} --prefix=%{_prefix} --install-lib=%{python3_sitelib}
%python_expand %fdupes %{buildroot}%{\$python_sitelib}
EOF
		if [ $OPT_NAMESPACEFILES == "1" ] ; then
		    for i in $NAMESPACEFILES ; do
			echo rm -rf %{buildroot}%{python3_sitelib}/$i | sed -e 's/\.py/\.\*/g' >> $TARGET/$PACKAGE/$PACKAGE.spec
			echo rm -rf %{buildroot}%{python3_sitelib}/$i | sed -e 's/__init__\.py/__pycache__/g' >> $TARGET/$PACKAGE/$PACKAGE.spec
		    done
		fi
		cat >> $TARGET/$PACKAGE/$PACKAGE.spec <<EOF

%files
%defattr(-,root,root,-)
EOF
		if [ $OPT_HISTORYFILE == "1" ] ; then
		    echo "%doc HISTORY.rst README.rst" >> $TARGET/$PACKAGE/$PACKAGE.spec
		else
		    echo "%doc README.rst" >> $TARGET/$PACKAGE/$PACKAGE.spec
		fi

		cat >> $TARGET/$PACKAGE/$PACKAGE.spec <<EOF
%license LICENSE.txt
EOF
		case $PACKAGE in
		    azure-cli|azure-cli-command-modules-nspkg|azure-cli-core|azure-cli-nspkg|azure-cli-testsdk)
			echo "%{python3_sitelib}/""$(echo $PACKAGE | sed -e 's/-/\//g')" >> $TARGET/$PACKAGE/$PACKAGE.spec
			;;
		    *)
			echo "%{python3_sitelib}/""$(echo $PACKAGE | sed -e 's/\(.*\)-\(.*\)-\(.*\)/\1-\2-command_modules-\3/g' | sed -e 's/-/\//g')" >> $TARGET/$PACKAGE/$PACKAGE.spec
			;;
		esac
		echo "%{python3_sitelib}/""$(echo $PACKAGE | sed -e 's/-/_/g')""-*.egg-info" >> $TARGET/$PACKAGE/$PACKAGE.spec

		cat >> $TARGET/$PACKAGE/$PACKAGE.spec <<EOF
%changelog
EOF
	    fi

	    if [ $OPT_LICENSEGEN == "1" ] ; then
		echo "Writing LICENSE.txt for file $PACKAGE ..."
		case $LICENSE in
		    MIT)
			cat > $TARGET/$PACKAGE/LICENSE.txt <<EOF
The MIT License (MIT)

Copyright (c) 2016 Microsoft Corporation. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
			;;
		    Apache-2.0)
			cat > $TARGET/$PACKAGE/LICENSE.txt <<EOF
Copyright (c) 2016 Microsoft Corporation. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
EOF
			;;
		    *)
			echo "Warning: Unknown license for package $PACKAGE."
		esac
	    fi

	    if [ $OPT_ZIPGEN == "1" ] ; then
		echo "Generating $PACKAGE-$VERSION.zip ..."
		ln -s $PACKAGE $PACKAGE-$VERSION
		zip -q -r $TARGET/$PACKAGE/$PACKAGE-$VERSION.zip $PACKAGE-$VERSION
	    fi
	fi
    done

    if [ $OPT_ZIPGEN == "1" ] || [ $OPT_SPECGEN == "1" ] ; then
	echo "Result in: "$TARGET
    fi
else
    usage
fi
