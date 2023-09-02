#!/bin/sh

# This script wraps docker-php-ext-install, properly configuring the system.
#
# Copyright (c) Michele Locati, 2018-2021
#
# Source: https://github.com/mlocati/docker-php-extension-installer
#
# License: MIT - see https://github.com/mlocati/docker-php-extension-installer/blob/master/LICENSE

# Let's set a sane environment
set -o errexit
set -o nounset

if ! which docker-php-ext-configure >/dev/null || ! which docker-php-ext-enable >/dev/null || ! which docker-php-ext-install >/dev/null || ! which docker-php-source >/dev/null; then
	printf 'The script %s is meant to be used with official Docker PHP Images - https://hub.docker.com/_/php\n' "$0" >&2
	exit 1
fi

IPE_VERSION=1.5.51

StandWithUkraine() {
	if test -t 1 && ! grep -Eq '^VERSION=.*jessie' /etc/os-release; then
		printf '\e[37;44m#StandWith\e[30;43mUkraine\e[0m\n'
	else
		printf '#StandWithUkraine\n'
	fi
}

if test "$IPE_VERSION" = master && test "${CI:-}" != true; then
	cat <<EOF

#############################################################################################################
#                                                                                                           #
#                                            W A R N I N G ! ! !                                            #
#                                                                                                           #
# You are using an unsupported method to get install-php-extensions!                                        #
#                                                                                                           #
# Please update the way you fetch it. Read the instructions at                                              #
# https://github.com/mlocati/docker-php-extension-installer#usage                                           #
#                                                                                                           #
# For example, if you get this script by fetching                                                           #
# https://raw.githubusercontent.com/mlocati/docker-php-extension-installer/master/install-php-extensions    #
# replace it with                                                                                           #
# https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions #
#                                                                                                           #
# Sleeping for a while so you get bored of this and act ;)                                                  #
#                                                                                                           #
#############################################################################################################

EOF
	StandWithUkraine
	sleep 10 || true
else
	printf 'install-php-extensions v.%s\n' "$IPE_VERSION"
	StandWithUkraine
fi

# Reset the Internal Field Separator
resetIFS() {
	IFS='	 
'
}

# Set these variables:
# - DISTRO containing the distribution name (eg 'alpine', 'debian')
# - DISTRO_VERSION_NUMBER containing the distribution version (eg '3.14' for Alpine, 11 for Debian)
# - DISTRO_VERSION containing the distribution name and its version(eg 'alpine@3.14', 'debian@11')
# - DISTRO_MAJMIN_VERSION always containing a number representing the distribution version (eg 314 for Alpine, 1100 for Debian)
setDistro() {
	if ! test -r /etc/os-release; then
		printf 'The file /etc/os-release is not readable\n' >&2
		exit 1
	fi
	DISTRO="$(cat /etc/os-release | grep -E ^ID= | cut -d = -f 2)"
	DISTRO_VERSION_NUMBER="$(cat /etc/os-release | grep -E ^VERSION_ID= | cut -d = -f 2 | cut -d '"' -f 2 | cut -d . -f 1,2)"
	DISTRO_VERSION="$(printf '%s@%s' $DISTRO $DISTRO_VERSION_NUMBER)"
	DISTRO_MAJMIN_VERSION="$(echo "$DISTRO_VERSION_NUMBER" | awk -F. '{print $1*100+$2}')"
}

# Set:
# - PHP_MAJMIN_VERSION: Major-Minor version, format MMmm (example 800 for PHP 8.0.1)
# - PHP_MAJDOTMIN_VERSION: Major-Minor version, format M.m (example 8.0 for PHP 8.0.1)
# - PHP_MAJMINPAT_VERSION: Major-Minor-Patch version, format MMmmpp (example 80001 for PHP 8.0.1) variables containing integers value
# - PHP_MAJDOTMINDOTPAT_VERSION: Major-Minor-Patch version, format M.m.p (example 8.0.1 for PHP 8.0.1)
# - PHP_THREADSAFE: 1 if PHP is thread-safe (TS), 0 if not thread-safe (NTS)
# - PHP_DEBUGBUILD: 1 if PHP is debug build (configured with "--enable-debug"), 0 otherwise
# - PHP_BITS: 32 if PHP is compiled for 32-bit, 64 if 64-bit
# - PHP_EXTDIR: the absolute path where the PHP extensions reside
setPHPVersionVariables() {
	PHP_MAJDOTMINDOTPAT_VERSION="$(php-config --version)"
	PHP_MAJMIN_VERSION=$(printf '%s' "$PHP_MAJDOTMINDOTPAT_VERSION" | awk -F. '{print $1*100+$2}')
	PHP_MAJDOTMIN_VERSION=$(printf '%s' "$PHP_MAJDOTMINDOTPAT_VERSION" | cut -d. -f1-2)
	PHP_MAJMINPAT_VERSION=$(printf '%s' "$PHP_MAJDOTMINDOTPAT_VERSION" | awk -F. '{print $1*10000+$2*100+$3}')
	PHP_THREADSAFE=$(php -n -r 'echo ZEND_THREAD_SAFE ? 1 : 0;')
	PHP_DEBUGBUILD=$(php -n -r 'echo ZEND_DEBUG_BUILD ? 1 : 0;')
	PHP_BITS=$(php -n -r 'echo PHP_INT_SIZE * 8;')
	PHP_EXTDIR="$(php -d display_errors=stderr -r 'echo realpath(ini_get("extension_dir"));')"
}

# Fix apt-get being very slow on Debian Jessie
# See https://bugs.launchpad.net/ubuntu/+source/apt/+bug/1332440
fixMaxOpenFiles() {
	fixMaxOpenFiles_cur=$(ulimit -n 2>/dev/null || echo 0)
	if test "$fixMaxOpenFiles_cur" -gt 10000; then
		ulimit -n 10000
	fi
}

# Get the directory containing the compiled PHP extensions
#
# Output:
#   The absolute path of the extensions dir
getPHPExtensionsDir() {
	php -i | grep -E '^extension_dir' | head -n1 | tr -s '[:space:]*=>[:space:]*' '|' | cut -d'|' -f2
}

# Normalize the name of a PHP extension
#
# Arguments:
#   $1: the name of the module to be normalized
#
# Output:
#   The normalized module name
normalizePHPModuleName() {
	normalizePHPModuleName_name="$1"
	case "$normalizePHPModuleName_name" in
		*A* | *B* | *C* | *D* | *E* | *F* | *G* | *H* | *I* | *J* | *K* | *L* | *M* | *N* | *O* | *P* | *Q* | *R* | *S* | *T* | *U* | *V* | *W* | *X* | *Y* | *Z*)
			normalizePHPModuleName_name="$(LC_CTYPE=C printf '%s' "$normalizePHPModuleName_name" | tr '[:upper:]' '[:lower:]')"
			;;
	esac
	case "$normalizePHPModuleName_name" in
		datadog_trace)
			normalizePHPModuleName_name=ddtrace
			;;
		ioncube | ioncube\ loader)
			normalizePHPModuleName_name='ioncube_loader'
			;;
		pecl_http)
			normalizePHPModuleName_name='http'
			;;
		zend\ opcache)
			normalizePHPModuleName_name='opcache'
			;;
		libsodium)
			if test $PHP_MAJMIN_VERSION -ge 700; then
				normalizePHPModuleName_name='sodium'
			fi
			;;
		sodium)
			if test $PHP_MAJMIN_VERSION -lt 700; then
				normalizePHPModuleName_name='libsodium'
			fi
			;;
		*\ *)
			printf '### WARNING Unrecognized module name: %s ###\n' "$1" >&2
			;;
	esac
	printf '%s' "$normalizePHPModuleName_name"
}

# Get the PECL name of PHP extension
#
# Arguments:
#   $1: the name of the extension
#
# Output:
#   The PECL name of the extension
getPeclModuleName() {
	normalizePHPModuleName_name="$1"
	case "$normalizePHPModuleName_name" in
		ddtrace)
			normalizePHPModuleName_name=datadog_trace
			;;
		http)
			normalizePHPModuleName_name=pecl_http
			;;
		sodium)
			normalizePHPModuleName_name=libsodium
			;;
	esac
	printf '%s' "$normalizePHPModuleName_name"
}

# Parse a package.xml (or package2.xml) file and extract the module name and version
#
# Arguments:
#   $1: the patho to the XML file
#
# Set these variables:
# - EXTRACTPACKAGEVERSIONFROMXML_NAME
# - EXTRACTPACKAGEVERSIONFROMXML_VERSION
#
# Output:
#   Nothing
#
# Return:
#   0 (true): if the string is in the list
#   1 (false): if the string is not in the list
extractPackageVersionFromXML() {
	if ! test -f "$1"; then
		printf 'Unable to find the file\n%s\n' >&2
		return 1
	fi
	extractPackageVersionFromXML_code="$(
		cat <<'EOT'
$doc = new DOMDocument();
if (!$doc->load($argv[1])) {
	fwrite(STDERR, "Failed to load XML file\n");
	exit(1);
}
set_error_handler(
	static function($errno, $errstr) {
		fwrite(STDERR, trim((string) $errstr) . "\n");
		exit(1);
	},
	-1
);
$xpath = new DOMXpath($doc);
$xpath->registerNamespace('v20', 'http://pear.php.net/dtd/package-2.0');
$xpath->registerNamespace('v21', 'http://pear.php.net/dtd/package-2.1');
if ($xpath->query('/v20:package/v20:dependencies')->length === 1) {
	$ns = 'v20:';
} elseif ($xpath->query('/v21:package/v21:dependencies')->length === 1) {
	$ns = 'v21:';
} elseif ($xpath->query('/package')->length === 1) {
	$ns = '';
} else {
	fwrite(STDERR, "Unsupported namespace of the XML of package version details\n");
}
$nodes = $xpath->query("/{$ns}package/{$ns}name");
$name = trim((string) $nodes[0]->nodeValue);
if ($ns === '') {
	$nodes = $xpath->query("/{$ns}package/{$ns}version");
} else {
	$nodes = $xpath->query("/{$ns}package/{$ns}version/{$ns}release");
}
$version = trim((string) $nodes[0]->nodeValue);
echo "EXTRACTPACKAGEVERSIONFROMXML_NAME='{$name}'\n";
echo "EXTRACTPACKAGEVERSIONFROMXML_VERSION='{$version}'\n";
exit(0);
EOT
	)"
	extractPackageVersionFromXML_vars="$(php -n -d display_errors=stderr -r "$extractPackageVersionFromXML_code" "$1")"
	if test -z "$extractPackageVersionFromXML_vars"; then
		return 1
	fi
	eval "$extractPackageVersionFromXML_vars"
	return 0
}

# Parse a module name (and optionally version) as received via command arguments, extracting the version and normalizing it
# Examples:
#   xdebug-2.9.8
#   xdebug-^2
#   xdebug-^2.9
#
# Arguments:
#   $1: the name of the module to be normalized
#
# Set these variables:
# - PROCESSED_PHP_MODULE_ARGUMENT
#
# Optionally set these variables:
# - PHP_WANTEDMODULEVERSION_<...> (where <...> is the normalized module name)
# - PHP_MODULESOURCECODEPATH_<...> (where <...> is the normalized module name)
#
# Output:
#   Nothing
processPHPModuleArgument() {
	processPHPModuleArgument_arg="$1"
	# Convert GitHub short form to long url,
	# for example: from
	# php-memcached-dev/php-memcached@8f106564e6bb005ca6100b12ccc89000daafa9d8
	# to
	# https://codeload.github.com/php-memcached-dev/php-memcached/tar.gz/8f106564e6bb005ca6100b12ccc89000daafa9d8
	processPHPModuleArgument_arg="$(printf '%s' "$processPHPModuleArgument_arg" | sed -E 's/^([a-zA-Z0-9_.\-]+\/[a-zA-Z0-9_.\-]+)@(.+$)/https:\/\/codeload.github.com\/\1\/tar.gz\/\2/')"
	# Let's check if $processPHPModuleArgument_arg is an URL
	if printf '%s' "$processPHPModuleArgument_arg" | grep -Eq '^https?://[^ ]+/[^ ]+$'; then
		printf 'Downloading source from %s\n' "$processPHPModuleArgument_arg"
		processPHPModuleArgument_arg="$(getPackageSource "$processPHPModuleArgument_arg")"
	fi
	# Let's check if $processPHPModuleArgument_arg the absolute path of an existing directory
	if test "$processPHPModuleArgument_arg" != "${processPHPModuleArgument_arg#/}" && test -d "$processPHPModuleArgument_arg"; then
		if test -f "$processPHPModuleArgument_arg/package2.xml"; then
			printf 'Checking package2.xml of directory %s... ' "$processPHPModuleArgument_arg"
			if ! extractPackageVersionFromXML "$processPHPModuleArgument_arg/package2.xml"; then
				return 1
			fi
		elif test -f "$processPHPModuleArgument_arg/package.xml"; then
			printf 'Checking package.xml of directory %s... ' "$processPHPModuleArgument_arg"
			if ! extractPackageVersionFromXML "$processPHPModuleArgument_arg/package.xml"; then
				return 1
			fi
		else
			printf 'Unable to find the package.xml file in the directory\n%s\n' "$processPHPModuleArgument_arg"
			return 1
		fi
		printf 'good (name: %s, version: %s)\n' "$EXTRACTPACKAGEVERSIONFROMXML_NAME" "$EXTRACTPACKAGEVERSIONFROMXML_VERSION"
		PROCESSED_PHP_MODULE_ARGUMENT="$(normalizePHPModuleName "$EXTRACTPACKAGEVERSIONFROMXML_NAME")"
		processPHPModuleArgument_version="$EXTRACTPACKAGEVERSIONFROMXML_VERSION"
		if printf '%s' "$PROCESSED_PHP_MODULE_ARGUMENT" | grep -Eq '^[a-zA-Z0-9_]+$'; then
			eval PHP_MODULESOURCECODEPATH_$PROCESSED_PHP_MODULE_ARGUMENT="$processPHPModuleArgument_arg"
		else
			printf 'Unable to parse the following module name:\n%s\n' "$PROCESSED_PHP_MODULE_ARGUMENT" >&2
			exit 1
		fi
	else
		PROCESSED_PHP_MODULE_ARGUMENT="${processPHPModuleArgument_arg%%-*}"
		if test -n "$PROCESSED_PHP_MODULE_ARGUMENT" && test "$PROCESSED_PHP_MODULE_ARGUMENT" != "$processPHPModuleArgument_arg"; then
			processPHPModuleArgument_version="${processPHPModuleArgument_arg#*-}"
		else
			processPHPModuleArgument_version=''
		fi
		PROCESSED_PHP_MODULE_ARGUMENT="$(normalizePHPModuleName "$PROCESSED_PHP_MODULE_ARGUMENT")"
	fi
	if test -n "$processPHPModuleArgument_version"; then
		if printf '%s' "$PROCESSED_PHP_MODULE_ARGUMENT" | grep -Eq '^[a-zA-Z0-9_]+$'; then
			eval PHP_WANTEDMODULEVERSION_$PROCESSED_PHP_MODULE_ARGUMENT="$processPHPModuleArgument_version"
		elif printf '%s' "$PROCESSED_PHP_MODULE_ARGUMENT" | grep -Eq '^@[a-zA-Z0-9_]+$'; then
			eval PHP_WANTEDMODULEVERSION__${PROCESSED_PHP_MODULE_ARGUMENT#@}="$processPHPModuleArgument_version"
		else
			printf 'Unable to parse the following module name:\n%s\n' "$PROCESSED_PHP_MODULE_ARGUMENT" >&2
		fi
	fi
}

# Get the wanted PHP module version, as specified in the command line arguments.
#
# Arguments:
#   $1: the name of the module to be normalized
#
# Output:
#   The wanted version (if any)
getWantedPHPModuleVersion() {
	if printf '%s' "$1" | grep -Eq '^[a-zA-Z0-9_]+$'; then
		eval printf '%s' "\${PHP_WANTEDMODULEVERSION_$1:-}"
	elif printf '%s' "$1" | grep -Eq '^@[a-zA-Z0-9_]+$'; then
		eval printf '%s' "\${PHP_WANTEDMODULEVERSION__${1#@}:-}"
	fi
}

# Get source code path of a PHP module version, as specified in the command line arguments.
#
# Arguments:
#   $1: the name of the module to be normalized
#
# Output:
#   The wanted version (if any)
getModuleSourceCodePath() {
	if printf '%s' "$1" | grep -Eq '^[a-zA-Z0-9_]+$'; then
		eval printf '%s' "\${PHP_MODULESOURCECODEPATH_$1:-}"
	fi
}

# Get the wanted PHP module version, resolving it if it starts with '^'
#
# Arguments:
#   $1: the name of the module to be normalized
#
# Output:
#   The version to be used
resolveWantedPHPModuleVersion() {
	resolveWantedPHPModuleVersion_raw="$(getWantedPHPModuleVersion "$1")"
	resolveWantedPHPModuleVersion_afterCaret="${resolveWantedPHPModuleVersion_raw#^}"
	if test "$resolveWantedPHPModuleVersion_raw" = "$resolveWantedPHPModuleVersion_afterCaret"; then
		printf '%s' "$resolveWantedPHPModuleVersion_raw"
		return
	fi
	resolveWantedPHPModuleVersion_xml="$(curl -sSLf "http://pecl.php.net/rest/r/$1/allreleases.xml")"
	resolveWantedPHPModuleVersion_versions="$(printf '%s' "$resolveWantedPHPModuleVersion_xml" | tr -s ' \t\r\n' ' ' | sed -r 's# *<#\n<#g' | grep '<v>' | sed 's#<v>##g' | sed 's# ##g')"
	resetIFS
	for resolveWantedPHPModuleVersion_version in $resolveWantedPHPModuleVersion_versions; do
		resolveWantedPHPModuleVersion_suffix="${resolveWantedPHPModuleVersion_version#$resolveWantedPHPModuleVersion_afterCaret}"
		if test "$resolveWantedPHPModuleVersion_version" != "${resolveWantedPHPModuleVersion_version#$resolveWantedPHPModuleVersion_afterCaret.}"; then
			# Example: looking for 1.0, found 1.0.1
			printf '%s' "$resolveWantedPHPModuleVersion_version"
			return
		fi
	done
	for resolveWantedPHPModuleVersion_version in $resolveWantedPHPModuleVersion_versions; do
		resolveWantedPHPModuleVersion_suffix="${resolveWantedPHPModuleVersion_version#$resolveWantedPHPModuleVersion_afterCaret}"
		if test "$resolveWantedPHPModuleVersion_version" = "$resolveWantedPHPModuleVersion_suffix"; then
			continue
		fi
		if test -z "$resolveWantedPHPModuleVersion_suffix"; then
			# Example: looking for 1.0, found exactly it
			printf '%s' "$resolveWantedPHPModuleVersion_version"
			return
		fi
		case "$resolveWantedPHPModuleVersion_suffix" in
			[0-9])
				# Example: looking for 1.1, but this is 1.10
				;;
			*)
				# Example: looking for 1.1, this is 1.1rc1
				printf '%s' "$resolveWantedPHPModuleVersion_version"
				return
				;;
		esac
	done
	printf 'Unable to find a version of "%s" compatible with "%s"\nAvailable versions are:\n%s\n' "$1" "$resolveWantedPHPModuleVersion_raw" "$resolveWantedPHPModuleVersion_versions" >&2
	exit 1
}

# Set these variables:
# - PHP_PREINSTALLED_MODULES the normalized list of PHP modules installed before running this script
setPHPPreinstalledModules() {
	PHP_PREINSTALLED_MODULES=''
	IFS='
'
	for getPHPInstalledModules_module in $(php -m); do
		getPHPInstalledModules_moduleNormalized=''
		case "$getPHPInstalledModules_module" in
			\[PHP\ Modules\]) ;;
			\[Zend\ Modules\])
				break
				;;
			*)
				getPHPInstalledModules_moduleNormalized="$(normalizePHPModuleName "$getPHPInstalledModules_module")"
				if ! stringInList "$getPHPInstalledModules_moduleNormalized" "$PHP_PREINSTALLED_MODULES"; then
					PHP_PREINSTALLED_MODULES="$PHP_PREINSTALLED_MODULES $getPHPInstalledModules_moduleNormalized"
				fi
				;;
		esac
	done
	if command -v composer >/dev/null; then
		PHP_PREINSTALLED_MODULES="$PHP_PREINSTALLED_MODULES @composer"
	fi
	resetIFS
	PHP_PREINSTALLED_MODULES="${PHP_PREINSTALLED_MODULES# }"
}

# Get the handles of the modules to be installed
#
# Arguments:
#   $@: all module handles
#
# Set:
#   PHP_MODULES_TO_INSTALL
#
# Output:
#   Nothing
processCommandArguments() {
	processCommandArguments_endArgs=0
	PHP_MODULES_TO_INSTALL=''
	# Support deprecated flag IPE_FIX_CACERTS
	case "${IPE_FIX_CACERTS:-}" in
		1 | y* | Y*)
			PHP_MODULES_TO_INSTALL="$PHP_MODULES_TO_INSTALL @fix_letsencrypt"
			;;
	esac
	while :; do
		if test $# -lt 1; then
			break
		fi
		processCommandArguments_skip=0
		if test $processCommandArguments_endArgs -eq 0; then
			case "$1" in
				--cleanup)
					printf '### WARNING the %s option is deprecated (we always cleanup everything) ###\n' "$1" >&2
					processCommandArguments_skip=1
					;;
				--)
					processCommandArguments_skip=1
					processCommandArguments_endArgs=1
					;;
				-*)
					printf 'Unrecognized option: %s\n' "$1" >&2
					exit 1
					;;
			esac
		fi
		if test $processCommandArguments_skip -eq 0; then
			processPHPModuleArgument "$1"
			processCommandArguments_name="$PROCESSED_PHP_MODULE_ARGUMENT"
			if stringInList "$processCommandArguments_name" "$PHP_MODULES_TO_INSTALL"; then
				printf '### WARNING Duplicated module name specified: %s ###\n' "$processCommandArguments_name" >&2
			elif stringInList "$processCommandArguments_name" "$PHP_PREINSTALLED_MODULES"; then
				printf '### WARNING Module already installed: %s ###\n' "$processCommandArguments_name" >&2
			else
				PHP_MODULES_TO_INSTALL="$PHP_MODULES_TO_INSTALL $processCommandArguments_name"
			fi
		fi
		shift
	done
	PHP_MODULES_TO_INSTALL="${PHP_MODULES_TO_INSTALL# }"
}

# Add a module that's required by another module
#
# Arguments:
#   $1: module that requires another module
#   $2: the required module
#
# Update:
#   PHP_MODULES_TO_INSTALL
#
# Output:
#   Nothing
checkRequiredModule() {
	if ! stringInList "$1" "$PHP_MODULES_TO_INSTALL"; then
		return
	fi
	if stringInList "$2" "$PHP_PREINSTALLED_MODULES"; then
		return
	fi
	PHP_MODULES_TO_INSTALL="$(removeStringFromList "$1" "$PHP_MODULES_TO_INSTALL")"
	if ! stringInList "$2" "$PHP_MODULES_TO_INSTALL"; then
		PHP_MODULES_TO_INSTALL="$PHP_MODULES_TO_INSTALL $2"
		PHP_MODULES_TO_INSTALL="${PHP_MODULES_TO_INSTALL# }"
	fi
	PHP_MODULES_TO_INSTALL="$PHP_MODULES_TO_INSTALL $1"
}

# Sort the modules to be installed, in order to fix dependencies
#
# Update:
#   PHP_MODULES_TO_INSTALL
#
# Output:
#   Nothing
sortModulesToInstall() {
	# apcu_bc requires apcu
	checkRequiredModule 'apcu_bc' 'apcu'
	# http requires propro (for PHP < 8) and raphf
	if test $PHP_MAJMIN_VERSION -le 704; then
		checkRequiredModule 'http' 'propro'
	fi
	checkRequiredModule 'http' 'raphf'
	# event requires sockets (for PHP <= 5.6)
	if test $PHP_MAJMIN_VERSION -le 506; then
		checkRequiredModule event sockets
	fi
	# relay requires msgpack
	checkRequiredModule relay msgpack
	# relay requires igbinary
	checkRequiredModule relay igbinary
	# Some module installation may use sockets if available: move it before other modules
	if stringInList 'sockets' "$PHP_MODULES_TO_INSTALL"; then
		PHP_MODULES_TO_INSTALL="$(removeStringFromList 'sockets' "$PHP_MODULES_TO_INSTALL")"
		PHP_MODULES_TO_INSTALL="sockets $PHP_MODULES_TO_INSTALL"
		PHP_MODULES_TO_INSTALL="${PHP_MODULES_TO_INSTALL% }"
	fi
	# Some module installation may use igbinary if available: move it before other modules
	if stringInList 'igbinary' "$PHP_MODULES_TO_INSTALL"; then
		PHP_MODULES_TO_INSTALL="$(removeStringFromList 'igbinary' "$PHP_MODULES_TO_INSTALL")"
		PHP_MODULES_TO_INSTALL="igbinary $PHP_MODULES_TO_INSTALL"
		PHP_MODULES_TO_INSTALL="${PHP_MODULES_TO_INSTALL% }"
	fi
	# Some module installation may use msgpack if available: move it before other modules
	if stringInList 'msgpack' "$PHP_MODULES_TO_INSTALL"; then
		PHP_MODULES_TO_INSTALL="$(removeStringFromList 'msgpack' "$PHP_MODULES_TO_INSTALL")"
		PHP_MODULES_TO_INSTALL="msgpack $PHP_MODULES_TO_INSTALL"
		PHP_MODULES_TO_INSTALL="${PHP_MODULES_TO_INSTALL% }"
	fi
	# Some module installation may use socket if available: move it before other modules
	if stringInList 'socket' "$PHP_MODULES_TO_INSTALL"; then
		PHP_MODULES_TO_INSTALL="$(removeStringFromList 'socket' "$PHP_MODULES_TO_INSTALL")"
		PHP_MODULES_TO_INSTALL="socket $PHP_MODULES_TO_INSTALL"
		PHP_MODULES_TO_INSTALL="${PHP_MODULES_TO_INSTALL% }"
	fi
	# Some module installation may use apcu if available: move it before other modules
	if stringInList 'apcu' "$PHP_MODULES_TO_INSTALL"; then
		PHP_MODULES_TO_INSTALL="$(removeStringFromList 'apcu' "$PHP_MODULES_TO_INSTALL")"
		PHP_MODULES_TO_INSTALL="apcu $PHP_MODULES_TO_INSTALL"
		PHP_MODULES_TO_INSTALL="${PHP_MODULES_TO_INSTALL% }"
	fi
	# In any case, first of all, we need to install composer
	if stringInList '@composer' "$PHP_MODULES_TO_INSTALL"; then
		PHP_MODULES_TO_INSTALL="$(removeStringFromList '@composer' "$PHP_MODULES_TO_INSTALL")"
		PHP_MODULES_TO_INSTALL="@composer $PHP_MODULES_TO_INSTALL"
		PHP_MODULES_TO_INSTALL="${PHP_MODULES_TO_INSTALL% }"
	fi
}

# Expand the IPE_ASPELL_LANGUAGES environment variable into apk/apt package names
expandASpellDictionaries() {
	expandASpellDictionaries_languages="${IPE_ASPELL_LANGUAGES:-en}"
	expandASpellDictionaries_result=''
	resetIFS
	for expandASpellDictionaries_language in $expandASpellDictionaries_languages; do
		expandASpellDictionaries_result="$expandASpellDictionaries_result aspell-$expandASpellDictionaries_language"
	done
	printf '%s' "${expandASpellDictionaries_result# }"
}

# Get the required APT/APK packages for a specific PHP version and for the list of module handles
#
# Arguments:
#   $@: the PHP module handles
#
# Set:
#   PACKAGES_PERSISTENT_NEW the list of packages required at runtume that must be installed
#   PACKAGES_PERSISTENT_PRE the list of packages required at runtume that are already installed
#   PACKAGES_VOLATILE the list of packages required at compile time that must be installed
#   PACKAGES_PREVIOUS the list of packages (with their version) that are installed right now (calculated only on Debian and only if PACKAGES_PERSISTENT_NEW or PACKAGES_VOLATILE are not empty)
buildRequiredPackageLists() {
	buildRequiredPackageLists_persistent=''
	buildRequiredPackageLists_volatile=''
	case "$DISTRO" in
		alpine)
			apk update
			;;
		debian)
			DEBIAN_FRONTEND=noninteractive apt-get update -q
			;;
	esac
	case "$DISTRO_VERSION" in
		alpine@*)
			if test $# -gt 1 || test "${1:-}" != '@composer'; then
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile $PHPIZE_DEPS"
			fi
			if test -z "$(apk info 2>/dev/null | grep -E ^libssl)"; then
				buildRequiredPackageLists_libssl='libssl1.0'
			elif test -z "$(apk info 2>/dev/null | grep -E '^libressl.*-libtls')" && test -z "$(apk info 2>/dev/null | grep -E '^libressl.*-libssl')" && test -z "$(apk info 2>/dev/null | grep -E '^libretls-')"; then
				buildRequiredPackageLists_libssl=$(apk search -q libressl*-libtls)
			else
				buildRequiredPackageLists_libssl=''
			fi
			if test $DISTRO_MAJMIN_VERSION -le 313; then
				buildRequiredPackageLists_libssldev='libressl-dev'
			else
				buildRequiredPackageLists_libssldev='libretls-dev'
			fi
			buildRequiredPackageLists_icuPersistent=''
			if test $DISTRO_MAJMIN_VERSION -ge 316; then
				case "${IPE_ICU_EN_ONLY:-}" in
					1 | y* | Y*) ;;
					*)
						buildRequiredPackageLists_icuPersistent='icu-data-full'
						;;
				esac
			fi
			;;
		debian@9)
			buildRequiredPackageLists_libssldev='libssl1.0-dev'
			;;
		debian@*)
			buildRequiredPackageLists_libssldev='^libssl([0-9]+(\.[0-9]+)*)?-dev$'
			;;
	esac
	if test $USE_PICKLE -gt 1; then
		buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile git"
	fi
	while :; do
		if test $# -lt 1; then
			break
		fi
		case "$1@$DISTRO" in
			@composer@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent unzip"
				;;
			amqp@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent rabbitmq-c"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile rabbitmq-c-dev"
				;;
			amqp@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^librabbitmq[0-9]*$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile librabbitmq-dev libssh-dev"
				;;
			bz2@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libbz2"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile bzip2-dev"
				;;
			bz2@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libbz2-dev"
				;;
			cmark@alpine)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile cmake"
				;;
			cmark@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile cmake"
				;;
			ddtrace@alpine)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile curl-dev"
				;;
			ddtrace@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent curl"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libcurl4-openssl-dev"
				;;
			dba@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent db"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile db-dev"
				;;
			dba@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile ^libdb5\.3-dev$"
				if test $PHP_MAJMIN_VERSION -le 505; then
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile patch"
				fi
				;;
			decimal@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libmpdec[0-9]*$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libmpdec-dev"
				;;
			enchant@alpine)
				if test $DISTRO_MAJMIN_VERSION -ge 312; then
					if test $PHP_MAJMIN_VERSION -ge 800; then
						buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent enchant2"
						buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile enchant2-dev"
					else
						# The system provides libenchant2, supported since PHP 8.0: we need to build libenchant1 on our own
						buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent glib aspell-libs libhunspell"
						buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile glib-dev aspell-dev hunspell-dev"
					fi
				else
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent enchant"
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile enchant-dev"
				fi
				;;
			enchant@debian)
				if test $DISTRO_VERSION_NUMBER -ge 11; then
					if test $PHP_MAJMIN_VERSION -ge 800; then
						buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libenchant-2-2"
						buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libenchant-2-dev"
					else
						# The system provides libenchant2, supported since PHP 8.0: we need to build libenchant1 on our own
						buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent aspell-en libhunspell-1.7-0"
						buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libglib2.0-dev libaspell-dev libhunspell-dev"
					fi
				else
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libenchant1c2a"
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libenchant-dev"
				fi
				;;
			event@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libevent $buildRequiredPackageLists_libssl"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libevent-dev $buildRequiredPackageLists_libssldev"
				;;
			event@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libevent[0-9\.\-]*$ ^libevent-openssl[0-9\.\-]*$ ^libevent-extra[0-9\.\-]*$ ^libevent-pthreads[0-9\.\-]*$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libevent-dev $buildRequiredPackageLists_libssldev"
				;;
			ffi@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libffi"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libffi-dev"
				;;
			ffi@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libffi-dev"
				;;
			gd@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent freetype libjpeg-turbo libpng libxpm"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile freetype-dev libjpeg-turbo-dev libpng-dev libxpm-dev"
				if test $PHP_MAJMIN_VERSION -le 506; then
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libvpx"
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libvpx-dev"
				else
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libwebp"
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libwebp-dev"
					if test $PHP_MAJMIN_VERSION -ge 801; then
						if test $DISTRO_MAJMIN_VERSION -ge 315; then
							buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libavif aom-libs libdav1d"
							buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libavif-dev aom-dev dav1d-dev"
						elif isLibaomInstalled && isLibdav1dInstalled && isLibyuvInstalled && isLibavifInstalled; then
							buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libstdc++"
						else
							case "${IPE_GD_WITHOUTAVIF:-}" in
								1 | y* | Y*) ;;
								*)
									buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libstdc++"
									buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile cmake nasm meson"
									;;
							esac
						fi
					fi
				fi
				;;
			gd@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libfreetype6 libjpeg62-turbo ^libpng[0-9]+-[0-9]+$ libxpm4"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libfreetype6-dev libjpeg62-turbo-dev libpng-dev libxpm-dev"
				if test $PHP_MAJMIN_VERSION -le 506; then
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libvpx[0-9]+$"
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libvpx-dev"
				else
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libwebp[0-9]+$"
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libwebp-dev"
					if test $PHP_MAJMIN_VERSION -ge 801; then
						if ! isLibaomInstalled || ! isLibdav1dInstalled || ! isLibyuvInstalled || ! isLibavifInstalled; then
							case "${IPE_GD_WITHOUTAVIF:-}" in
								1 | y* | Y*) ;;
								*)
									buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile cmake nasm meson"
									;;
							esac
						fi
					fi
				fi
				;;
			gearman@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libstdc++ libuuid"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile boost-dev gperf libmemcached-dev libevent-dev util-linux-dev"
				;;
			gearman@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libgearman[0-9]*$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libgearman-dev"
				;;
			geoip@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent geoip"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile geoip-dev"
				;;
			geoip@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libgeoip1[0-9]*$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libgeoip-dev"
				;;
			geos@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent geos-dev"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile geos"
				;;
			geos@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libgeos-c1(v[0-9]*)?$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libgeos-dev"
				;;
			gettext@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libintl"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile gettext-dev"
				;;
			gmagick@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent graphicsmagick libgomp"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile graphicsmagick-dev libtool"
				;;
			gmagick@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libgraphicsmagick(-q16-)?[0-9]*$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libgraphicsmagick1-dev"
				;;
			gmp@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent gmp"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile gmp-dev"
				;;
			gmp@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libgmp-dev"
				;;
			gnupg@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent gpgme"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile gpgme-dev"
				;;
			gnupg@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libgpgme[0-9]*$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile ^libgpgme[0-9]*-dev$"
				;;
			grpc@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libstdc++"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile zlib-dev linux-headers"
				;;
			grpc@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile zlib1g-dev"
				;;
			http@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libevent"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile zlib-dev curl-dev libevent-dev"
				if test $PHP_MAJMIN_VERSION -le 506; then
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libidn"
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libidn-dev"
				else
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent icu-libs $buildRequiredPackageLists_icuPersistent libidn"
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile icu-dev libidn-dev"
				fi
				;;
			http@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libcurl3-gnutls ^libevent[0-9\.\-]*$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile zlib1g-dev libgnutls28-dev libcurl4-gnutls-dev libevent-dev"
				if test $PHP_MAJMIN_VERSION -le 506; then
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile ^libidn1[0-9+]-dev$"
				else
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libicu[0-9]+$ ^libidn2-[0-9+]$"
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libicu-dev ^libidn2-[0-9+]-dev$"
				fi
				;;
			imagick@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent imagemagick libgomp"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile imagemagick-dev"
				;;
			imagick@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libmagickwand-6.q16-[0-9]+$ ^libmagickcore-6.q16-[0-9]+-extra$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libmagickwand-dev"
				;;
			imap@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent c-client $buildRequiredPackageLists_libssl"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile krb5-dev imap-dev $buildRequiredPackageLists_libssldev"
				;;
			imap@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libc-client2007e"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libkrb5-dev"
				case "$DISTRO_VERSION" in
					debian@9)
						buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile $buildRequiredPackageLists_libssldev comerr-dev krb5-multidev libc-client2007e libgssrpc4 libkadm5clnt-mit11 libkadm5srv-mit11 libkdb5-8 libpam0g-dev libssl-doc mlock"
						;;
					*)
						buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libc-client-dev"
						;;
				esac
				;;
			interbase@alpine)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile icu-dev ncurses-dev"
				;;
			interbase@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libfbclient2"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile firebird-dev libib-util"
				;;
			intl@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent icu-libs $buildRequiredPackageLists_icuPersistent"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile icu-dev"
				;;
			intl@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libicu[0-9]+$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libicu-dev"
				;;
			ion@alpine)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile cmake git"
				;;
			ion@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile cmake git"
				;;
			ldap@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libldap"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile openldap-dev"
				;;
			ldap@debian)
				if test $DISTRO_VERSION_NUMBER -ge 9; then
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libldap-common"
				fi
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libldap2-dev"
				;;
			luasandbox@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent lua5.1-libs"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile lua5.1-dev"
				;;
			luasandbox@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent liblua5.1-0"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile liblua5.1-0-dev"
				;;
			lz4@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent lz4-libs"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile lz4-dev"
				;;
			lz4@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent liblz4-1"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile liblz4-dev"
				;;
			maxminddb@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libmaxminddb"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libmaxminddb-dev"
				;;
			maxminddb@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libmaxminddb[0-9]*$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libmaxminddb-dev"
				;;
			memprof@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent judy"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile judy-dev bsd-compat-headers"
				;;
			memprof@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libjudydebian1"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libjudy-dev"
				;;
			mcrypt@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libmcrypt"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libmcrypt-dev"
				;;
			mcrypt@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libmcrypt4"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libmcrypt-dev"
				;;
			memcache@alpine)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile zlib-dev"
				;;
			memcache@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile zlib1g-dev"
				;;
			memcached@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libmemcached-libs"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libmemcached-dev zlib-dev"
				;;
			memcached@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libmemcachedutil2"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libmemcached-dev zlib1g-dev"
				;;
			mongo@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libsasl $buildRequiredPackageLists_libssl"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile $buildRequiredPackageLists_libssldev cyrus-sasl-dev"
				;;
			mongo@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile $buildRequiredPackageLists_libssldev libsasl2-dev"
				;;
			mongodb@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent icu-libs $buildRequiredPackageLists_icuPersistent libsasl $buildRequiredPackageLists_libssl snappy"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile icu-dev cyrus-sasl-dev snappy-dev $buildRequiredPackageLists_libssldev zlib-dev"
				;;
			mongodb@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libsnappy[0-9]+(v[0-9]+)?$ ^libicu[0-9]+$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libicu-dev libsasl2-dev libsnappy-dev $buildRequiredPackageLists_libssldev zlib1g-dev"
				;;
			mosquitto@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent mosquitto-libs"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile mosquitto-dev"
				;;
			mosquitto@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libmosquitto1"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libmosquitto-dev"
				;;
			mssql@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent freetds"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile freetds-dev"
				;;
			mssql@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libsybdb5"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile freetds-dev"
				;;
			oauth@alpine)
				if test $PHP_MAJMIN_VERSION -ge 700; then
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile pcre-dev"
				fi
				;;
			oauth@debian)
				if test $PHP_MAJMIN_VERSION -ge 700; then
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libpcre3-dev"
				fi
				;;
			oci8@alpine | pdo_oci@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libaio libc6-compat libnsl"
				if test $DISTRO_MAJMIN_VERSION -le 307; then
					# The unzip tool of Alpine 3.7 can't extract symlinks from ZIP archives: let's use bsdtar instead
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libarchive-tools"
				fi
				;;
			oci8@debian | pdo_oci@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libaio[0-9]*$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile unzip"
				;;
			odbc@alpine | pdo_odbc@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent unixodbc"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile unixodbc-dev"
				;;
			odbc@debian | pdo_odbc@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libodbc1"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile unixodbc-dev"
				;;
			openswoole@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent postgresql-libs libstdc++ $buildRequiredPackageLists_libssl"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile curl-dev postgresql-dev linux-headers $buildRequiredPackageLists_libssldev"
				;;
			openswoole@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libcurl3-gnutls libpq5"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile $buildRequiredPackageLists_libssldev libcurl4-gnutls-dev libpq-dev"
				;;
			parle@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libstdc++"
				;;
			pdo_dblib@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent freetds"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile freetds-dev"
				;;
			pdo_dblib@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libsybdb5"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile freetds-dev"
				;;
			pdo_firebird@alpine)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile icu-dev ncurses-dev"
				;;
			pdo_firebird@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libfbclient2"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile firebird-dev libib-util"
				;;
			pgsql@alpine | pdo_pgsql@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent postgresql-libs"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile postgresql-dev"
				;;
			pgsql@debian | pdo_pgsql@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libpq5"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libpq-dev"
				;;
			php_trie@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libstdc++"
				;;
			pspell@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent aspell-libs $(expandASpellDictionaries)"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile aspell-dev"
				;;
			pspell@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libaspell15 $(expandASpellDictionaries)"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libpspell-dev"
				;;
			rdkafka@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent librdkafka"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile librdkafka-dev"
				;;
			rdkafka@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^librdkafka\+*[0-9]*$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile librdkafka-dev"
				;;
			recode@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent recode"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile recode-dev"
				;;
			recode@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent librecode0"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile librecode-dev"
				;;
			redis@alpine)
				if test $PHP_MAJMIN_VERSION -ge 700; then
					case "$DISTRO_VERSION" in
						alpine@3.7)
							buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent zstd"
							;;
						*)
							buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent zstd-libs"
							;;
					esac
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile zstd-dev"
				fi
				;;
			redis@debian)
				if test $PHP_MAJMIN_VERSION -ge 700; then
					case "$DISTRO_VERSION" in
						debian@8)
							## There's no APT package for libzstd
							;;
						debian@9)
							## libzstd is too old (available: 1.1.2, required: 1.3.0+)
							;;
						*)
							buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libzstd[0-9]*$"
							buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libzstd-dev"
							;;
					esac
				fi
				;;
			relay@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent lz4-libs zstd-libs"
				;;
			simdjson@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libstdc++"
				;;
			smbclient@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libsmbclient"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile samba-dev"
				;;
			smbclient@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libsmbclient"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libsmbclient-dev"
				;;
			snappy@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent snappy"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile snappy-dev"
				;;
			snappy@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libsnappy1(v[0-9]+)?$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libsnappy-dev"
				;;
			snmp@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent net-snmp-libs"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile net-snmp-dev"
				;;
			snmp@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent snmp"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libsnmp-dev"
				;;
			snuffleupagus@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent pcre"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile pcre-dev"
				;;
			snuffleupagus@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libpcre3-dev"
				;;
			soap@alpine)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libxml2-dev"
				;;
			soap@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libxml2-dev"
				;;
			sockets@alpine)
				if test $PHP_MAJMIN_VERSION -ge 802; then
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile linux-headers"
				fi
				;;
			sodium@alpine | libsodium@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libsodium"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libsodium-dev"
				;;
			sodium@debian | libsodium@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libsodium[0-9]*$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libsodium-dev"
				;;
			solr@alpine)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile curl-dev libxml2-dev"
				;;
			solr@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libcurl3-gnutls"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libcurl4-gnutls-dev libxml2-dev"
				;;
			spx@alpine)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile zlib-dev"
				;;
			spx@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile zlib1g-dev"
				;;
			sqlsrv@alpine | pdo_sqlsrv@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libstdc++ unixodbc"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile unixodbc-dev"
				;;
			sqlsrv@debian | pdo_sqlsrv@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent unixodbc"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile unixodbc-dev"
				if ! isMicrosoftSqlServerODBCInstalled; then
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile gnupg apt-transport-https"
				fi
				;;
			ssh2@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libssh2"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libssh2-dev"
				;;
			ssh2@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libssh2-1-dev"
				;;
			stomp@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent $buildRequiredPackageLists_libssl"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile $buildRequiredPackageLists_libssldev"
				;;
			stomp@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile $buildRequiredPackageLists_libssldev"
				;;
			swoole@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent postgresql-libs libstdc++ $buildRequiredPackageLists_libssl"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile curl-dev postgresql-dev linux-headers $buildRequiredPackageLists_libssldev"
				if test $PHP_MAJMIN_VERSION -ge 702; then
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent c-ares"
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile c-ares-dev"
				fi
				;;
			swoole@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libcurl3-gnutls libpq5"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile $buildRequiredPackageLists_libssldev libcurl4-gnutls-dev libpq-dev"
				if test $PHP_MAJMIN_VERSION -ge 702; then
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libc-ares2"
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libc-ares-dev"
				fi
				if test $PHP_MAJMIN_VERSION -ge 800; then
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile zlib1g-dev"
				fi
				;;
			sybase_ct@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent freetds"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile freetds-dev"
				;;
			sybase_ct@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libct4"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile freetds-dev"
				;;
			tdlib@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libstdc++ $buildRequiredPackageLists_libssl"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile git cmake gperf zlib-dev $buildRequiredPackageLists_libssldev linux-headers readline-dev"
				;;
			tdlib@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile git cmake gperf zlib1g-dev $buildRequiredPackageLists_libssldev"
				;;
			tensor@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent lapack libexecinfo openblas"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile lapack-dev libexecinfo-dev openblas-dev"
				if test $DISTRO_MAJMIN_VERSION -le 310; then
					if ! stringInList --force-overwrite "$IPE_APK_FLAGS"; then
						IPE_APK_FLAGS="$IPE_APK_FLAGS --force-overwrite"
					fi
				fi
				;;
			tensor@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent liblapacke libopenblas-base"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile liblapack-dev libopenblas-dev liblapacke-dev"
				if test $DISTRO_VERSION_NUMBER -ge 11; then
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent gfortran-10"
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libgfortran-10-dev"
				elif test $DISTRO_VERSION_NUMBER -ge 10; then
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent gfortran-8"
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libgfortran-8-dev"
				fi
				;;
			tidy@alpine)
				if test $DISTRO_MAJMIN_VERSION -ge 315; then
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent tidyhtml"
				else
					buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent tidyhtml-libs"
				fi
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile tidyhtml-dev"
				;;
			tidy@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libtidy-?[0-9][0-9.\-]*(deb[0-9])?$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libtidy-dev"
				;;
			uuid@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libuuid"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile util-linux-dev"
				;;
			uuid@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile uuid-dev"
				;;
			vips@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent vips"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile vips-dev"
				;;
			vips@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libvips"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libvips-dev"
				;;
			wddx@alpine)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libxml2-dev"
				;;
			wddx@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libxml2-dev"
				;;
			xdebug@alpine)
				if test $PHP_MAJMIN_VERSION -ge 800; then
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile linux-headers"
				fi
				;;
			xlswriter@alpine)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile zlib-dev"
				;;
			xlswriter@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile zlib1g-dev"
				;;
			xmldiff@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libstdc++"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libxml2-dev"
				;;
			xmldiff@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libxml2-dev"
				;;
			xmlrpc@alpine)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libxml2-dev"
				;;
			xmlrpc@debian)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libxml2-dev"
				;;
			xsl@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libxslt"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libxslt-dev libgcrypt-dev"
				;;
			xsl@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libxslt1\.1$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libxslt-dev"
				;;
			yaml@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent yaml"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile yaml-dev"
				;;
			yaml@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libyaml-0-2"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libyaml-dev"
				;;
			yar@alpine)
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile curl-dev"
				;;
			yar@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libcurl3-gnutls"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libcurl4-gnutls-dev"
				;;
			zip@alpine)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libzip"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile cmake gnutls-dev libzip-dev $buildRequiredPackageLists_libssldev zlib-dev"
				;;
			zip@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libzip[0-9]$"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile cmake gnutls-dev $buildRequiredPackageLists_libssldev libzip-dev libbz2-dev zlib1g-dev"
				case "$DISTRO_VERSION" in
					debian@8)
						# Debian Jessie doesn't seem to provide libmbedtls
						;;
					*)
						buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent ^libmbedtls[0-9]*$"
						buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libmbedtls-dev"
						;;
				esac
				;;
			zookeeper@alpine)
				if ! test -f /usr/local/include/zookeeper/zookeeper.h; then
					buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile maven automake libtool openjdk8"
				fi
				;;
			zookeeper@debian)
				buildRequiredPackageLists_persistent="$buildRequiredPackageLists_persistent libzookeeper-mt2"
				buildRequiredPackageLists_volatile="$buildRequiredPackageLists_volatile libzookeeper-mt-dev"
				;;
		esac
		shift
	done
	PACKAGES_PERSISTENT_NEW=''
	PACKAGES_PERSISTENT_PRE=''
	PACKAGES_VOLATILE=''
	PACKAGES_PREVIOUS=''
	if test -z "$buildRequiredPackageLists_persistent$buildRequiredPackageLists_volatile"; then
		return
	fi
	if test -n "$buildRequiredPackageLists_persistent"; then
		PACKAGES_PERSISTENT_NEW="$(expandPackagesToBeInstalled $buildRequiredPackageLists_persistent)"
		if test -s "$IPE_ERRFLAG_FILE"; then
			exit 1
		fi
		resetIFS
		for buildRequiredPackageLists_package in $buildRequiredPackageLists_persistent; do
			buildRequiredPackageLists_package="$(expandInstalledSystemPackageName "$buildRequiredPackageLists_package")"
			if test -n "$buildRequiredPackageLists_package"; then
				PACKAGES_PERSISTENT_PRE="$PACKAGES_PERSISTENT_PRE $buildRequiredPackageLists_package"
			fi
		done
		PACKAGES_PERSISTENT_PRE="${PACKAGES_PERSISTENT_PRE# }"
	fi
	if test -n "$buildRequiredPackageLists_volatile"; then
		buildRequiredPackageLists_packages="$(expandPackagesToBeInstalled $buildRequiredPackageLists_volatile)"
		if test -s "$IPE_ERRFLAG_FILE"; then
			exit 1
		fi
		resetIFS
		for buildRequiredPackageLists_package in $buildRequiredPackageLists_packages; do
			if ! stringInList "$buildRequiredPackageLists_package" "$PACKAGES_PERSISTENT_NEW"; then
				if test "$buildRequiredPackageLists_package" != icu-data-en || ! stringInList icu-data-full "$PACKAGES_PERSISTENT_NEW"; then
					PACKAGES_VOLATILE="$PACKAGES_VOLATILE $buildRequiredPackageLists_package"
				fi
			fi
		done
		PACKAGES_VOLATILE="${PACKAGES_VOLATILE# }"
	fi
	if test -n "$PACKAGES_PERSISTENT_NEW$PACKAGES_VOLATILE"; then
		case "$DISTRO" in
			debian)
				PACKAGES_PREVIOUS="$(dpkg --get-selections | grep -E '\sinstall$' | awk '{ print $1 }')"
				;;
		esac
	fi
}

# Get the full list of APT/APK packages that will be installed, given the required packages
#
# Arguments:
#   $1: the list of required APT/APK packages
#
# Output:
#   Space-separated list of every APT/APK packages that will be installed
expandPackagesToBeInstalled() {
	expandPackagesToBeInstalled_result=''
	case "$DISTRO" in
		alpine)
			expandPackagesToBeInstalled_log="$(apk add --simulate $@ 2>&1 || printf '\nERROR: apk failed\n')"
			if test -n "$(printf '%s' "$expandPackagesToBeInstalled_log" | grep -E '^ERROR:')"; then
				printf 'FAILED TO LIST THE WHOLE PACKAGE LIST FOR\n' >&2
				printf '%s ' "$@" >&2
				printf '\n\nCOMMAND OUTPUT:\n%s\n' "$expandPackagesToBeInstalled_log" >&2
				echo 'y' >"$IPE_ERRFLAG_FILE"
				exit 1
			fi
			IFS='
'
			for expandPackagesToBeInstalled_line in $expandPackagesToBeInstalled_log; do
				if test -n "$(printf '%s' "$expandPackagesToBeInstalled_line" | grep -E '^\([0-9]*/[0-9]*) Installing ')"; then
					expandPackagesToBeInstalled_result="$expandPackagesToBeInstalled_result $(printf '%s' "$expandPackagesToBeInstalled_line" | cut -d ' ' -f 3)"
				fi
			done
			resetIFS
			;;
		debian)
			expandPackagesToBeInstalled_log="$(DEBIAN_FRONTEND=noninteractive apt-get install -sy --no-install-recommends $@ 2>&1 || printf '\nE: apt-get failed\n')"
			if test -n "$(printf '%s' "$expandPackagesToBeInstalled_log" | grep -E '^E:')"; then
				printf 'FAILED TO LIST THE WHOLE PACKAGE LIST FOR\n' >&2
				printf '%s ' "$@" >&2
				printf '\n\nCOMMAND OUTPUT:\n%s\n' "$expandPackagesToBeInstalled_log" >&2
				echo 'y' >"$IPE_ERRFLAG_FILE"
				exit 1
			fi
			expandPackagesToBeInstalled_inNewPackages=0
			IFS='
'
			for expandPackagesToBeInstalled_line in $expandPackagesToBeInstalled_log; do
				if test $expandPackagesToBeInstalled_inNewPackages -eq 0; then
					if test "$expandPackagesToBeInstalled_line" = 'The following NEW packages will be installed:'; then
						expandPackagesToBeInstalled_inNewPackages=1
					fi
				elif test "$expandPackagesToBeInstalled_line" = "${expandPackagesToBeInstalled_line# }"; then
					break
				else
					resetIFS
					for expandPackagesToBeInstalled_newPackage in $expandPackagesToBeInstalled_line; do
						expandPackagesToBeInstalled_result="$expandPackagesToBeInstalled_result $expandPackagesToBeInstalled_newPackage"
					done
					IFS='
'
				fi
			done
			resetIFS
			;;
	esac
	printf '%s' "${expandPackagesToBeInstalled_result# }"
}

# Check if a system package is installed; if so we prints its name.
#
# Arguments:
#   $1: the name of the package to be checked (regular expressions accepted: they must start with a ^)
expandInstalledSystemPackageName() {
	if test "$1" = "${1#^}"; then
		expandInstalledSystemPackageName_grepflags='-Fx'
	else
		expandInstalledSystemPackageName_grepflags='-E'
	fi
	case "$DISTRO" in
		alpine)
			apk info | grep $expandInstalledSystemPackageName_grepflags -- "$1" || test $? -eq 1
			;;
		debian)
			dpkg --get-selections | grep -E '\sinstall$' | awk '{ print $1 }' | cut -d: -f1 | grep $expandInstalledSystemPackageName_grepflags -- "$1" || test $? -eq 1
			;;
	esac
}

# Retrieve the number of available cores (alternative to nproc if not available)
#
# Output:
#   The number of processor cores available
getProcessorCount() {
	if command -v nproc >/dev/null 2>&1; then
		nproc
	else
		getProcessorCount_tmp=$(cat /proc/cpuinfo | grep -E '^processor\s*:\s*\d+$' | wc -l)
		if test $getProcessorCount_tmp -ge 1; then
			echo $getProcessorCount_tmp
		else
			echo 1
		fi
	fi
}

# Set these variables:
# - TARGET_TRIPLET the build target tripled (eg 'x86_64-linux-gnu', 'x86_64-alpine-linux-musl')
setTargetTriplet() {
	TARGET_TRIPLET="$(gcc -print-multiarch 2>/dev/null || true)"
	if test -z "$TARGET_TRIPLET"; then
		TARGET_TRIPLET="$(gcc -dumpmachine)"
	fi
}

# Retrieve the number of processors to be used when compiling an extension
#
# Arguments:
#   $1: the handle of the PHP extension to be compiled
# Output:
#   The number of processors to be used
getCompilationProcessorCount() {
	case "$1" in
		'')
			# The above extensions don't support parallel compilation
			echo 1
			;;
		*)
			# All the other extensions support parallel compilation
			getProcessorCount
			;;
	esac
}

# Get the full path of a PHP extension given its name.
#
# Arguments:
#   $1: the name of the PHP extension
#
# Output:
#   The absolute path of the PHP extension file (or nothing if the file can't be found)
getModuleFullPath() {
	case "$1" in
		apcu_bc)
			getModuleFullPath_path="$PHP_EXTDIR/apc.so"
			;;
		*)
			getModuleFullPath_path="$PHP_EXTDIR/$1.so"
			;;
	esac
	if ! test -f "$getModuleFullPath_path"; then
		printf 'Unable to find the file of the PHP extension "%s"\n' "$1" >&2
		exit 1
	fi
	printf '%s' "$getModuleFullPath_path"
}

# Post-process a PHP module just compiled and installed in the PHP extension directory
#
# Arguments:
#   $1: the name of the PHP extension
#
# Return:
#   0 (true): if suceeded
#   non-zero (false): in case of errors
postProcessModule() {
	postProcessModule_file="$(getModuleFullPath "$1")"
	if test $PHP_DEBUGBUILD -ne 1; then
		printf 'Removing symbols from %s... ' "$postProcessModule_file"
		postProcessModule_preSize="$(stat -c %s "$postProcessModule_file")"
		strip --strip-all "$postProcessModule_file"
		postProcessModule_postSize="$(stat -c %s "$postProcessModule_file")"
		printf 'done (%s bytes saved).\n' "$((postProcessModule_preSize - postProcessModule_postSize))"
	fi
	return $?
}

# Get the type of the php.ini entry to be used for a PHP extension
#
# Arguments:
#   $1: the name of the PHP extension
#
# Output:
#   zend_extension or extension
getModuleIniEntryType() {
	case "$1" in
		ioncube_loader | sourceguardian)
			# On PHP 5.5, docker-php-ext-enable fails to detect that ionCube Loader and sourceguardian are Zend extensions
			if test $PHP_MAJMIN_VERSION -le 505; then
				printf 'zend_extension'
				return 0
			fi
			;;
	esac
	getModuleIniEntryType_file="$(getModuleFullPath "$1")"
	if readelf --wide --syms "$getModuleIniEntryType_file" | grep -Eq ' zend_extension_entry$'; then
		printf 'zend_extension'
	else
		printf 'extension'
	fi
}

# Create the contents of a PHP ini file that enables an extension
#
# Arguments:
#   $1: the name of the PHP extension
#   $2: additional php.ini configuration (optional)
#
# Output:
#   The contents of the ini file
buildPhpExtensionIniContent() {
	buildPhpExtensionIniContent_type="$(getModuleIniEntryType "$1")"
	buildPhpExtensionIniContent_soFile="$(getModuleFullPath "$1")"
	buildPhpExtensionIniContent_result="$(printf '%s=%s' "$buildPhpExtensionIniContent_type" "${buildPhpExtensionIniContent_soFile##$PHP_EXTDIR/}")"
	if test -n "${2:-}"; then
		buildPhpExtensionIniContent_result="$(printf '%s\n%s' "$buildPhpExtensionIniContent_result" "$2")"
	fi
	printf '%s' "$buildPhpExtensionIniContent_result"
}

# Check that a PHP module actually works (better to run this check before enabling the extension)
#
# Arguments:
#   $1: the name of the PHP extension
#   $2: base name (without path and extension) of additional php.ini configuration (optional)
#   $3: additional php.ini configuration (optional)
#
# Return:
#   0 (true): if the string is in the list
#   1 (false): if the string is not in the list
checkModuleWorking() {
	if test -n "${2:-}"; then
		checkModuleWorking_iniFile="$PHP_INI_DIR/conf.d/$2--temp.ini"
	else
		checkModuleWorking_iniFile="$PHP_INI_DIR/conf.d/docker-php-ext-$1--temp.ini"
	fi
	checkModuleWorking_iniContent="$(buildPhpExtensionIniContent "$1" "${3:-}")"
	printf 'Check if the %s module can be loaded... ' "$1"
	checkModuleWorking_errBefore="$(php -r 'return;' 2>&1 || true)"
	printf '%s' "$checkModuleWorking_iniContent" >"$checkModuleWorking_iniFile"
	checkModuleWorking_errAfter="$(php -r 'return;' 2>&1 || true)"
	rm "$checkModuleWorking_iniFile"
	if test "$checkModuleWorking_errAfter" != "$checkModuleWorking_errBefore"; then
		printf 'Error loading the "%s" extension:\n%s\n' "$1" "$checkModuleWorking_errAfter" >&2
		return 1
	fi
	printf 'ok.\n'
	return 0
}

# Enable a PHP extension
#
# Arguments:
#   $1: the name of the PHP extension to be enabled
#   $2: base name (without path and extension) of additional php.ini configuration (optional)
#   $3: additional php.ini configuration (optional)
enablePhpExtension() {
	if test -n "${2:-}"; then
		enablePhpExtension_iniFile="$PHP_INI_DIR/conf.d/$2.ini"
	else
		enablePhpExtension_iniFile="$PHP_INI_DIR/conf.d/docker-php-ext-$1.ini"
	fi
	enablePhpExtension_iniContent="$(buildPhpExtensionIniContent "$1" "${3:-}")"
	case "${IPE_DONT_ENABLE:-}" in
		1 | y* | Y*)
			enablePhpExtension_enableCommand="/usr/local/bin/docker-php-ext-enable-$1"
			printf '%s' "$enablePhpExtension_iniContent" >"$enablePhpExtension_iniFile-disabled"
			printf '\n' >>"$enablePhpExtension_iniFile-disabled"
			cat <<EOT >"$enablePhpExtension_enableCommand"
#!/bin/sh

if test -f '$enablePhpExtension_iniFile-disabled'; then
	echo 'Enabling extension $1'
	mv '$enablePhpExtension_iniFile-disabled' '$enablePhpExtension_iniFile'
else
	echo 'The extension $1 has already been enabled'
fi
EOT
			chmod +x "$enablePhpExtension_enableCommand"
			printf '## Extension %s not enabled.\nYou can enable it by running the following command:\n%s\n\n' "$1" "$(basename "$enablePhpExtension_enableCommand")"
			;;
		*)
			printf '%s' "$enablePhpExtension_iniContent" >"$enablePhpExtension_iniFile"
			printf '\n' >>"$enablePhpExtension_iniFile"
			;;
	esac
}

# Mark the pre-installed APT/APK packages as used
# that way they won't be uninstalled by accident
markPreinstalledPackagesAsUsed() {
	printf '### MARKING PRE-INSTALLED PACKAGES AS IN-USE ###\n'
	case "$DISTRO" in
		alpine)
			printf '# Packages: %s\n' "$PACKAGES_PERSISTENT_PRE"
			apk add $PACKAGES_PERSISTENT_PRE
			;;
		debian)
			DEBIAN_FRONTEND=noninteractive apt-mark manual $PACKAGES_PERSISTENT_PRE
			;;
	esac
}

# Install the required APT/APK packages
#
# Arguments:
#   $@: the list of APT/APK packages to be installed
installRequiredPackages() {
	printf '### INSTALLING REQUIRED PACKAGES ###\n'
	printf '# Packages to be kept after installation: %s\n' "$PACKAGES_PERSISTENT_NEW"
	printf '# Packages to be used only for installation: %s\n' "$PACKAGES_VOLATILE"
	case "$DISTRO" in
		alpine)
			apk add $IPE_APK_FLAGS $PACKAGES_PERSISTENT_NEW $PACKAGES_VOLATILE
			# https://gitlab.alpinelinux.org/alpine/aports/-/issues/12763#note_172090
			# https://github.com/mlocati/docker-php-extension-installer/issues/385
			# https://github.com/mlocati/docker-php-extension-installer/issues/537#issuecomment-1078748882
			for installRequiredPackages_item in wget; do
				if test -n "$(expandInstalledSystemPackageName "$installRequiredPackages_item")"; then
					apk add --upgrade "$installRequiredPackages_item"
				fi
			done
			;;
		debian)
			DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -qq -y $PACKAGES_PERSISTENT_NEW $PACKAGES_VOLATILE
			;;
	esac
}

# Get the version of an installed APT/APK package
#
# Arguments:
#   $1: the name of the installed package
#
# Output:
#   The numeric part of the package version, with from 1 to 3 numbers
#
# Example:
#   1
#   1.2
#   1.2.3
getInstalledPackageVersion() {
	case "$DISTRO" in
		alpine)
			apk info "$1" | head -n1 | cut -c $((${#1} + 2))- | grep -o -E '^[0-9]+(\.[0-9]+){0,2}'
			;;
		debian)
			dpkg-query --showformat='${Version}' --show "$1" 2>/dev/null | grep -o -E '^[0-9]+(\.[0-9]+){0,2}'
			;;
	esac
}

# Compare two versions
#
# Arguments:
#   $1: the first version
#   $2: the second version
#
# Output
#  -1 if $1 is less than $2
#  0 if $1 is the same as $2
#  1 if $1 is greater than $2
compareVersions() {
	compareVersions_v1="$1.0.0"
	compareVersions_v2="$2.0.0"
	compareVersions_vMin="$(printf '%s\n%s' "$compareVersions_v1" "$compareVersions_v2" | sort -t '.' -n -k1,1 -k2,2 -k3,3 | head -n 1)"
	if test "$compareVersions_vMin" != "$compareVersions_v1"; then
		echo '1'
	elif test "$compareVersions_vMin" = "$compareVersions_v2"; then
		echo '0'
	else
		echo '-1'
	fi
}

# Install Oracle Instant Client & SDK
#
# Set:
#   ORACLE_INSTANTCLIENT_LIBPATH
installOracleInstantClient() {
	case "${IPE_INSTANTCLIENT_BASIC:-}" in
		1 | y* | Y*)
			installOracleInstantClient_handle=basic
			;;
		*)
			installOracleInstantClient_handle=basiclite
			;;
	esac
	case $PHP_BITS in
		32)
			installOracleInstantClient_client=client
			installOracleInstantClient_version='19.9'
			installOracleInstantClient_ic=https://download.oracle.com/otn_software/linux/instantclient/199000/instantclient-$installOracleInstantClient_handle-linux-$installOracleInstantClient_version.0.0.0dbru.zip
			installOracleInstantClient_sdk=https://download.oracle.com/otn_software/linux/instantclient/199000/instantclient-sdk-linux-$installOracleInstantClient_version.0.0.0dbru.zip
			;;
		*)
			case $(uname -m) in
				aarch64*)
					installOracleInstantClient_client=client64
					installOracleInstantClient_version='19.10'
					installOracleInstantClient_ic=https://download.oracle.com/otn_software/linux/instantclient/191000/instantclient-$installOracleInstantClient_handle-linux.arm64-$installOracleInstantClient_version.0.0.0dbru.zip
					installOracleInstantClient_sdk=https://download.oracle.com/otn_software/linux/instantclient/191000/instantclient-sdk-linux.arm64-$installOracleInstantClient_version.0.0.0dbru.zip
					;;
				*)
					installOracleInstantClient_client=client64
					installOracleInstantClient_version='21.1'
					installOracleInstantClient_ic=https://download.oracle.com/otn_software/linux/instantclient/211000/instantclient-$installOracleInstantClient_handle-linux.x64-$installOracleInstantClient_version.0.0.0.zip
					installOracleInstantClient_sdk=https://download.oracle.com/otn_software/linux/instantclient/211000/instantclient-sdk-linux.x64-$installOracleInstantClient_version.0.0.0.zip
					;;
			esac
			;;
	esac
	ORACLE_INSTANTCLIENT_LIBPATH=/usr/lib/oracle/$installOracleInstantClient_version/$installOracleInstantClient_client/lib
	if ! test -e "$ORACLE_INSTANTCLIENT_LIBPATH"; then
		printf 'Downloading Oracle Instant Client v%s (%s)... ' "$installOracleInstantClient_version" "$installOracleInstantClient_handle"
		installOracleInstantClient_src="$(getPackageSource $installOracleInstantClient_ic)"
		mkdir -p "/usr/lib/oracle/$installOracleInstantClient_version/$installOracleInstantClient_client"
		mv "$installOracleInstantClient_src" "$ORACLE_INSTANTCLIENT_LIBPATH"
		echo 'done.'
	fi
	if ! test -e "$ORACLE_INSTANTCLIENT_LIBPATH/sdk"; then
		printf 'Downloading Oracle Instant SDK v%s... ' "$installOracleInstantClient_version"
		installOracleInstantClient_src="$(getPackageSource $installOracleInstantClient_sdk)"
		ln -sf "$installOracleInstantClient_src/sdk" "$ORACLE_INSTANTCLIENT_LIBPATH/sdk"
		UNNEEDED_PACKAGE_LINKS="$UNNEEDED_PACKAGE_LINKS '$ORACLE_INSTANTCLIENT_LIBPATH/sdk'"
		echo 'done.'
	fi
	case "$DISTRO" in
		alpine)
			if ! test -e /usr/lib/libresolv.so.2 && test -e /lib/libc.so.6; then
				ln -s /lib/libc.so.6 /usr/lib/libresolv.so.2
			fi
			installOracleInstantClient_ldconf=/etc/ld-musl-${TARGET_TRIPLET%-alpine-linux-musl}.path
			if test -e "$installOracleInstantClient_ldconf"; then
				if ! cat "$installOracleInstantClient_ldconf" | grep -q "$ORACLE_INSTANTCLIENT_LIBPATH"; then
					cat "$ORACLE_INSTANTCLIENT_LIBPATH" | awk -v suffix=":$ORACLE_INSTANTCLIENT_LIBPATH" '{print NR==1 ? $0suffix : $0}' >"$ORACLE_INSTANTCLIENT_LIBPATH"
				fi
			else
				case $PHP_BITS in
					32)
						echo "/lib:/usr/local/lib:/usr/lib:$ORACLE_INSTANTCLIENT_LIBPATH" >"$installOracleInstantClient_ldconf"
						;;
					*)
						echo "/lib64:/lib:/usr/local/lib:/usr/lib:$ORACLE_INSTANTCLIENT_LIBPATH" >"$installOracleInstantClient_ldconf"
						;;
				esac
			fi
			;;
		debian)
			if ! test -e /etc/ld.so.conf.d/oracle-instantclient.conf; then
				echo "$ORACLE_INSTANTCLIENT_LIBPATH" >/etc/ld.so.conf.d/oracle-instantclient.conf
				ldconfig
			fi
			;;
	esac
}

# Check if the Microsoft SQL Server ODBC Driver is installed
#
# Return:
#   0 (true): if the string is in the list
#   1 (false): if the string is not in the list
isMicrosoftSqlServerODBCInstalled() {
	test -d /opt/microsoft/msodbcsql*/
}

# Install the Microsoft SQL Server ODBC Driver
installMicrosoftSqlServerODBC() {
	printf 'Installing the Microsoft SQL Server ODBC Driver\n'
	case "$DISTRO" in
		alpine)
			# https://docs.microsoft.com/en-us/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server#alpine17
			rm -rf /tmp/src/msodbcsql.apk
			if test $PHP_MAJMIN_VERSION -le 703; then
				curl -sSLf -o /tmp/src/msodbcsql.apk https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/msodbcsql17_17.9.1.1-1_amd64.apk
			else
				curl -sSLf -o /tmp/src/msodbcsql.apk https://download.microsoft.com/download/b/9/f/b9f3cce4-3925-46d4-9f46-da08869c6486/msodbcsql18_18.0.1.1-1_amd64.apk
			fi
			printf '\n' | apk add --allow-untrusted /tmp/src/msodbcsql.apk
			rm -rf /tmp/src/msodbcsql.apk
			;;
		debian)
			# https://docs.microsoft.com/en-us/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server#debian17
			printf -- '- installing the Microsoft APT key\n'
			if test $DISTRO_VERSION_NUMBER -ge 11; then
				# apt-key is deprecated
				curl -sSLf -o /etc/apt/trusted.gpg.d/microsoft.asc https://packages.microsoft.com/keys/microsoft.asc
			else
				curl -sSLf https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
			fi
			if ! test -f /etc/apt/sources.list.d/mssql-release.list; then
				printf -- '- adding the Microsoft APT source list\n'
				curl -sSLf https://packages.microsoft.com/config/debian/$DISTRO_VERSION_NUMBER/prod.list >/etc/apt/sources.list.d/mssql-release.list
				DEBIAN_FRONTEND=noninteractive apt-get -q update
			fi
			printf -- '- installing the APT package\n'
			if test $PHP_MAJMIN_VERSION -le 703; then
				DEBIAN_FRONTEND=noninteractive ACCEPT_EULA=Y apt-get -qy --no-install-recommends install msodbcsql17
			elif test $DISTRO_VERSION_NUMBER -ge 9 && $DISTRO_VERSION_NUMBER -le 11; then
				# On Debian 9 and 11 we have both msodbcsql17 and msodbcsql18: let's install just one
				DEBIAN_FRONTEND=noninteractive ACCEPT_EULA=Y apt-get -qy --no-install-recommends install msodbcsql18
			else
				DEBIAN_FRONTEND=noninteractive ACCEPT_EULA=Y apt-get -qy --no-install-recommends install '^msodbcsql[0-9]+$'
			fi
			;;
	esac
}

# Check if libaom is installed
#
# Return:
#   0 (true)
#   1 (false)
isLibaomInstalled() {
	if ! test -f /usr/local/lib/libaom.so && ! test -f /usr/lib/libaom.so; then
		return 1
	fi
	if ! test -f /usr/local/include/aom/aom_codec.h && ! test -f /usr/include/aom/aom_codec.h; then
		return 1
	fi
	return 0
}

# Install libaom
installLibaom() {
	printf 'Installing libaom\n'
	installLibaom_dir="$(getPackageSource https://aomedia.googlesource.com/aom/+archive/v3.3.0.tar.gz)"
	mkdir -- "$installLibaom_dir/my.build"
	cd -- "$installLibaom_dir/my.build"
	cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=1 -DENABLE_DOCS=0 -DENABLE_EXAMPLES=0 -DENABLE_TESTDATA=0 -DENABLE_TESTS=0 -DENABLE_TOOLS=0 -DCMAKE_INSTALL_LIBDIR:PATH=lib ..
	ninja -j $(getProcessorCount) install
	cd - >/dev/null
	ldconfig || true
}

# Check if libdav1d is installed
#
# Return:
#   0 (true)
#   1 (false)
isLibdav1dInstalled() {
	if ! test -f /usr/local/lib/libdav1d.so && ! test -f /usr/lib/libdav1d.so && ! test -f /usr/lib/x86_64*/libdav1d.so; then
		return 1
	fi
	if ! test -f /usr/local/include/dav1d/dav1d.h && ! test -f /usr/include/dav1d/dav1d.h; then
		return 1
	fi
	return 0
}

# Install libdav1d
installLibdav1d() {
	printf 'Installing libdav1d\n'
	installLibdav1d_dir="$(getPackageSource https://code.videolan.org/videolan/dav1d/-/archive/0.9.2/dav1d-0.9.2.tar.gz)"
	mkdir -- "$installLibdav1d_dir/build"
	cd -- "$installLibdav1d_dir/build"
	meson --buildtype release -Dprefix=/usr ..
	ninja -j $(getProcessorCount) install
	cd - >/dev/null
	if test -f /usr/lib/$TARGET_TRIPLET/libdav1d.so && ! test -f /usr/lib/libdav1d.so; then
		ln -s /usr/lib/$TARGET_TRIPLET/libdav1d.so /usr/lib/
	fi
	ldconfig || true
}

# Check if libyuv is installed
#
# Return:
#   0 (true)
#   1 (false)
isLibyuvInstalled() {
	if ! test -f /usr/local/lib/libyuv.so && ! test -f /usr/lib/libyuv.so && ! test -f /usr/lib/x86_64*/libyuv.so; then
		return 1
	fi
	if ! test -f /usr/local/include/libyuv.h && ! test -f /usr/include/libyuv.h; then
		return 1
	fi
	return 0
}

# Install libyuv
installLibyuv() {
	printf 'Installing libyuv\n'
	installLibyuv_dir="$(getPackageSource https://chromium.googlesource.com/libyuv/libyuv/+archive/25d0a5110be796eef47004412baf43333d9ecf26.tar.gz)"
	mkdir -- "$installLibyuv_dir/build"
	cd -- "$installLibyuv_dir/build"
	cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -B. ..
	make -j$(getProcessorCount) install
	cd - >/dev/null
}

# Check if libavif is installed
#
# Return:
#   0 (true)
#   1 (false)
isLibavifInstalled() {
	if ! test -f /usr/local/lib/libavif.so && ! test -f /usr/lib/libavif.so && ! test -f /usr/lib/x86_64*/libavif.so; then
		return 1
	fi
	if ! test -f /usr/local/include/avif/avif.h && ! test -f /usr/include/avif/avif.h; then
		return 1
	fi
	return 0
}

# Install libavif
installLibavif() {
	printf 'Installing libavif\n'
	installLibavif_dir="$(getPackageSource https://codeload.github.com/AOMediaCodec/libavif/tar.gz/refs/tags/v0.9.3)"
	mkdir -- "$installLibavif_dir/build"
	cd -- "$installLibavif_dir/build"
	cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DAVIF_CODEC_AOM=ON -DCMAKE_INSTALL_LIBDIR:PATH=lib
	make -j$(getProcessorCount) install
	cd - >/dev/null
}

# Install Composer
installComposer() {
	installComposer_version="$(getWantedPHPModuleVersion @composer)"
	installComposer_version="${installComposer_version#^}"
	if test -z "$installComposer_version"; then
		installComposer_fullname=composer
		installComposer_flags=''
	else
		installComposer_fullname="$(printf 'composer v%s' "$installComposer_version")"
		if printf '%s' "$installComposer_version" | grep -Eq '^[0-9]+$'; then
			installComposer_flags="--$installComposer_version"
		else
			installComposer_flags="--version=$installComposer_version"
		fi
	fi
	printf '### INSTALLING %s ###\n' "$installComposer_fullname"
	actuallyInstallComposer /usr/local/bin composer "$installComposer_flags"
}

# Actually install composer
#
# Arguments:
#   $1: the directory where composer should be installed (required)
#   $2: the composer filename (optional, default: composer)
#   $3. additional flags for the composer installed (optional)
actuallyInstallComposer() {
	actuallyInstallComposer_installer="$(mktemp -p /tmp/src)"
	curl -sSLf -o "$actuallyInstallComposer_installer" https://getcomposer.org/installer
	actuallyInstallComposer_expectedSignature="$(curl -sSLf https://composer.github.io/installer.sig)"
	actuallyInstallComposer_actualSignature="$(php -n -r "echo hash_file('sha384', '$actuallyInstallComposer_installer');")"
	if test "$actuallyInstallComposer_expectedSignature" != "$actuallyInstallComposer_actualSignature"; then
		printf 'Verification of composer installer failed!\nExpected signature: %s\nActual signature: %s\n' "$actuallyInstallComposer_expectedSignature" "$actuallyInstallComposer_actualSignature" >&2
		exit 1
	fi
	actuallyInstallComposer_flags="--install-dir=$1"
	if test -n "${2:-}"; then
		actuallyInstallComposer_flags="$actuallyInstallComposer_flags --filename=$2"
	else
		actuallyInstallComposer_flags="$actuallyInstallComposer_flags --filename=composer"
	fi
	if test -n "${3:-}"; then
		actuallyInstallComposer_flags="$actuallyInstallComposer_flags $3"
	fi
	php "$actuallyInstallComposer_installer" $actuallyInstallComposer_flags
	rm -- "$actuallyInstallComposer_installer"
}

# Install ionCube Loader
installIonCubeLoader() {
	# See https://www.ioncube.com/loaders.php
	case $PHP_BITS in
		32)
			case $(uname -m) in
				aarch* | arm*)
					installIonCubeLoader_url="https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_armv7l.tar.gz"
					;;
				*)
					installIonCubeLoader_url="https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86.tar.gz"
					;;
			esac
			;;
		*)
			case $(uname -m) in
				aarch64 | arm64 | armv8)
					installIonCubeLoader_url="https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_aarch64.tar.gz"
					;;
				*)
					installIonCubeLoader_url="https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz"
					;;
			esac
			;;
	esac
	printf 'Downloading ionCube Loader... '
	installIonCubeLoader_dir="$(getPackageSource $installIonCubeLoader_url)"
	echo 'done.'
	installIonCubeLoader_so=$(php -r "printf('ioncube_loader_lin_%s.%s%s.so', PHP_MAJOR_VERSION, PHP_MINOR_VERSION, ZEND_THREAD_SAFE ? '_ts' : '');")
	cp "$installIonCubeLoader_dir/$installIonCubeLoader_so" "$(getPHPExtensionsDir)/ioncube_loader.so"
}

# Install SourceGuardian Loader
installSourceGuardian() {
	# See https://www.sourceguardian.com/loaders.html
	case $PHP_BITS in
		32)
			installSourceGuardian_url=https://www.sourceguardian.com/loaders/download/loaders.linux-i386.tar.gz
			;;
		*)
			case $(uname -m) in
				aarch64 | arm64 | armv8)
					installSourceGuardian_url=https://www.sourceguardian.com/loaders/download/loaders.linux-aarch64.tar.gz
					;;
				*)
					installSourceGuardian_url=https://www.sourceguardian.com/loaders/download/loaders.linux-x86_64.tar.gz
					;;
			esac
			;;
	esac
	printf 'Downloading SourceGuardian... '
	installSourceGuardian_dir="$(getPackageSource $installSourceGuardian_url)"
	printf 'done (version: %s)\n' "$(cat "$installSourceGuardian_dir/version")"
	for installSourceGuardian_phpv in $PHP_MAJDOTMINDOTPAT_VERSION $PHP_MAJDOTMIN_VERSION; do
		installSourceGuardian_file="$installSourceGuardian_dir/ixed.$PHP_MAJDOTMIN_VERSION"
		if test $PHP_THREADSAFE -eq 1; then
			installSourceGuardian_file="${installSourceGuardian_file}ts"
		fi
		installSourceGuardian_file="${installSourceGuardian_file}.lin"
		if test -f "$installSourceGuardian_file"; then
			mv "$installSourceGuardian_file" "$(getPHPExtensionsDir)/sourceguardian.so"
			return
		fi
	done
	printf 'Unable to find a SourceGuardian compatible with PHP %s or PHP %s.\nAvailable SourceGuardian versions:\n' "$PHP_MAJDOTMINDOTPAT_VERSION" "$PHP_MAJDOTMIN_VERSION" >&2
	ls -1 "$installSourceGuardian_dir" | grep -E '^ixed\..*\.lin$' | sed -E 's/^[^0-9]+([0-9]+(\.[0-9]+)*).*$/\1/' | sort | uniq >&2
	exit 1
}

# Install a bundled PHP module given its handle
#
# Arguments:
#   $1: the handle of the PHP module
#
# Set:
#   UNNEEDED_PACKAGE_LINKS
#
# Output:
#   Nothing
installBundledModule() {
	printf '### INSTALLING BUNDLED MODULE %s ###\n' "$1"
	if test -n "$(getWantedPHPModuleVersion "$1")"; then
		printf '### WARNING the module "%s" is bundled with PHP, you can NOT specify a version for it\n' "$1" >&2
	fi
	if test -n "$(getModuleSourceCodePath "$1")"; then
		printf '### WARNING the module "%s" is bundled with PHP, you can NOT specify a source code path for it\n' "$1" >&2
	fi
	case "$1" in
		dba)
			if test -e /usr/lib/$TARGET_TRIPLET/libdb-5.3.so && ! test -e /usr/lib/libdb-5.3.so; then
				ln -s /usr/lib/$TARGET_TRIPLET/libdb-5.3.so /usr/lib/
			fi
			if test $PHP_MAJMIN_VERSION -le 505; then
				docker-php-source extract
				patch /usr/src/php/ext/dba/config.m4 <<EOF
@@ -362,7 +362,7 @@
       break
     fi
   done
-  PHP_DBA_DB_CHECK(4, db-5.1 db-5.0 db-4.8 db-4.7 db-4.6 db-4.5 db-4.4 db-4.3 db-4.2 db-4.1 db-4.0 db-4 db4 db, [(void)db_create((DB**)0, (DB_ENV*)0, 0)])
+  PHP_DBA_DB_CHECK(4, db-5.3 db-5.1 db-5.0 db-4.8 db-4.7 db-4.6 db-4.5 db-4.4 db-4.3 db-4.2 db-4.1 db-4.0 db-4 db4 db, [(void)db_create((DB**)0, (DB_ENV*)0, 0)])
 fi
 PHP_DBA_STD_RESULT(db4,Berkeley DB4)
 
EOF
			fi
			docker-php-ext-configure dba --with-db4
			;;
		enchant)
			installBundledModule_tmp=0
			if test $PHP_MAJMIN_VERSION -lt 800; then
				case "$DISTRO" in
					alpine)
						if test $DISTRO_MAJMIN_VERSION -ge 312; then
							installBundledModule_tmp=1
						fi
						;;
					debian)
						if test $DISTRO_VERSION_NUMBER -ge 11; then
							installBundledModule_tmp=1
						fi
						;;
				esac
			fi
			if test $installBundledModule_tmp -eq 1 && ! test -f /usr/lib/libenchant.so && ! test -f /usr/local/lib/libenchant.so; then
				# We need to install libenchant1 from source
				installBundledModule_src="$(getPackageSource https://github.com/AbiWord/enchant/releases/download/enchant-1-6-1/enchant-1.6.1.tar.gz)"
				cd -- "$installBundledModule_src"
				./configure
				make -j$(getProcessorCount)
				make install
				cd - >/dev/null
			fi
			;;
		gd)
			if test $PHP_MAJMIN_VERSION -le 506; then
				docker-php-ext-configure gd --with-gd --with-jpeg-dir --with-png-dir --with-zlib-dir --with-xpm-dir --with-freetype-dir --enable-gd-native-ttf --with-vpx-dir
			elif test $PHP_MAJMIN_VERSION -le 701; then
				docker-php-ext-configure gd --with-gd --with-jpeg-dir --with-png-dir --with-zlib-dir --with-xpm-dir --with-freetype-dir --enable-gd-native-ttf --with-webp-dir
			elif test $PHP_MAJMIN_VERSION -le 703; then
				docker-php-ext-configure gd --with-gd --with-jpeg-dir --with-png-dir --with-zlib-dir --with-xpm-dir --with-freetype-dir --with-webp-dir
			elif test $PHP_MAJMIN_VERSION -le 800; then
				docker-php-ext-configure gd --enable-gd --with-webp --with-jpeg --with-xpm --with-freetype
			else
				installBundledModule_tmp=0
				case "$DISTRO" in
					alpine)
						if test $DISTRO_MAJMIN_VERSION -ge 315; then
							installBundledModule_tmp=1
						fi
						;;
				esac
				if test $installBundledModule_tmp -eq 0; then
					case "${IPE_GD_WITHOUTAVIF:-}" in
						1 | y* | Y*) ;;
						*)
							if ! isLibaomInstalled; then
								installLibaom
							fi
							if ! isLibdav1dInstalled; then
								installLibdav1d
							fi
							if ! isLibyuvInstalled; then
								installLibyuv
							fi
							if ! isLibavifInstalled; then
								installLibavif
							fi
							;;
					esac
					if isLibaomInstalled && isLibdav1dInstalled && isLibyuvInstalled && isLibavifInstalled; then
						installBundledModule_tmp=1
					fi
				fi
				if test $installBundledModule_tmp -eq 1; then
					docker-php-ext-configure gd --enable-gd --with-webp --with-jpeg --with-xpm --with-freetype --with-avif
				else
					docker-php-ext-configure gd --enable-gd --with-webp --with-jpeg --with-xpm --with-freetype
				fi
			fi
			;;
		gmp)
			if test $PHP_MAJMIN_VERSION -le 506; then
				if ! test -f /usr/include/gmp.h; then
					ln -s /usr/include/$TARGET_TRIPLET/gmp.h /usr/include/gmp.h
					UNNEEDED_PACKAGE_LINKS="$UNNEEDED_PACKAGE_LINKS /usr/include/gmp.h"
				fi
			fi
			;;
		imap)
			case "$DISTRO_VERSION" in
				debian@9)
					installBundledModule_tmp="$(pwd)"
					cd /tmp
					apt-get download libc-client2007e-dev
					dpkg -i --ignore-depends=libssl-dev libc-client2007e-dev*
					rm libc-client2007e-dev*
					cd "$installBundledModule_tmp"
					;;
			esac
			PHP_OPENSSL=yes docker-php-ext-configure imap --with-kerberos --with-imap-ssl
			;;
		interbase | pdo_firebird)
			case "$DISTRO" in
				alpine)
					if ! test -d /tmp/src/firebird; then
						mv "$(getPackageSource https://github.com/FirebirdSQL/firebird/releases/download/R2_5_9/Firebird-2.5.9.27139-0.tar.bz2)" /tmp/src/firebird
						cd /tmp/src/firebird
						# Patch rwlock.h (this has been fixed in later release of firebird 3.x)
						sed -i '194s/.*/#if 0/' src/common/classes/rwlock.h
						./configure --with-system-icu
						# -j option can't be used: make targets must be compiled sequentially
						make -s btyacc_binary gpre_boot libfbstatic libfbclient
						cp gen/firebird/lib/libfbclient.so /usr/lib/
						ln -s /usr/lib/libfbclient.so /usr/lib/libfbclient.so.2
						cd - >/dev/null
					fi
					CFLAGS='-I/tmp/src/firebird/src/jrd -I/tmp/src/firebird/src/include -I/tmp/src/firebird/src/include/gen' docker-php-ext-configure $1
					;;
			esac
			;;
		ldap)
			case "$DISTRO" in
				debian)
					docker-php-ext-configure ldap --with-libdir=lib/$TARGET_TRIPLET
					;;
			esac
			;;
		mssql | pdo_dblib)
			if ! test -f /usr/lib/libsybdb.so; then
				ln -s /usr/lib/$TARGET_TRIPLET/libsybdb.so /usr/lib/libsybdb.so
				UNNEEDED_PACKAGE_LINKS="$UNNEEDED_PACKAGE_LINKS /usr/lib/libsybdb.so"
			fi
			;;
		odbc)
			docker-php-source extract
			cd /usr/src/php/ext/odbc
			phpize
			sed -ri 's@^ *test +"\$PHP_.*" *= *"no" *&& *PHP_.*=yes *$@#&@g' configure
			./configure --with-unixODBC=shared,/usr
			cd - >/dev/null
			;;
		oci8 | pdo_oci)
			installOracleInstantClient
			if test "$1" = oci8; then
				docker-php-ext-configure "$1" "--with-oci8=instantclient,$ORACLE_INSTANTCLIENT_LIBPATH"
			elif test "$1" = pdo_oci; then
				docker-php-ext-configure "$1" "--with-pdo-oci=instantclient,$ORACLE_INSTANTCLIENT_LIBPATH"
			fi
			;;
		pdo_odbc)
			docker-php-ext-configure pdo_odbc --with-pdo-odbc=unixODBC,/usr
			;;
		snmp)
			case "$DISTRO" in
				alpine)
					mkdir -p -m 0755 /var/lib/net-snmp/mib_indexes
					;;
			esac
			;;
		sockets)
			case "$PHP_MAJDOTMINDOTPAT_VERSION" in
				8.0.15 | 8.1.2)
					sed -i '70 i #ifndef _GNU_SOURCE' /usr/src/php/ext/sockets/config.m4
					sed -i '71 i #define _GNU_SOURCE' /usr/src/php/ext/sockets/config.m4
					sed -i '72 i #endif' /usr/src/php/ext/sockets/config.m4
					;;
			esac
			;;
		sybase_ct)
			docker-php-ext-configure sybase_ct --with-sybase-ct=/usr
			;;
		tidy)
			case "$DISTRO" in
				alpine)
					if ! test -f /usr/include/buffio.h; then
						ln -s /usr/include/tidybuffio.h /usr/include/buffio.h
						UNNEEDED_PACKAGE_LINKS="$UNNEEDED_PACKAGE_LINKS /usr/include/buffio.h"
					fi
					;;
			esac
			;;
		zip)
			if test $PHP_MAJMIN_VERSION -le 505; then
				docker-php-ext-configure zip
			elif test $PHP_MAJMIN_VERSION -le 703; then
				docker-php-ext-configure zip --with-libzip
			else
				docker-php-ext-configure zip --with-zip
			fi
			;;
	esac
	installBundledModule_errBefore="$(php -r 'return;' 2>&1 || true)"
	docker-php-ext-install -j$(getProcessorCount) "$1"
	case "$1" in
		imap)
			case "$DISTRO_VERSION" in
				debian@9)
					dpkg -r libc-client2007e-dev
					;;
			esac
			;;
	esac
	php -r 'return;' >/dev/null 2>/dev/null || true
	installBundledModule_errAfter="$(php -r 'return;' 2>&1 || true)"
	if test "$installBundledModule_errAfter" != "$installBundledModule_errBefore"; then
		printf 'PHP has problems after installing the "%s" extension:\n%s\n' "$1" "$installBundledModule_errAfter" >&2
		rm "$PHP_INI_DIR/conf.d/docker-php-ext-$1.ini" || true
		return 1
	fi
}

# Fetch a tar.gz file, extract it and returns the path of the extracted folder.
#
# Arguments:
#   $1: the URL of the file to be downloaded
#
# Output:
#   The path of the extracted directory
getPackageSource() {
	mkdir -p /tmp/src
	getPackageSource_tempFile=$(mktemp -p /tmp/src)
	curl -sSLf -o "$getPackageSource_tempFile" "$1"
	getPackageSource_tempDir=$(mktemp -p /tmp/src -d)
	cd "$getPackageSource_tempDir"
	tar -xzf "$getPackageSource_tempFile" 2>/dev/null || tar -xf "$getPackageSource_tempFile" 2>/dev/null || (
		if command -v bsdtar >/dev/null; then
			bsdtar -xf "$getPackageSource_tempFile"
		else
			unzip -q "$getPackageSource_tempFile"
		fi
	)
	cd - >/dev/null
	unlink "$getPackageSource_tempFile"
	getPackageSource_outDir=''
	for getPackageSource_i in $(ls "$getPackageSource_tempDir"); do
		if test -n "$getPackageSource_outDir" || test -f "$getPackageSource_tempDir/$getPackageSource_i"; then
			getPackageSource_outDir=''
			break
		fi
		getPackageSource_outDir="$getPackageSource_tempDir/$getPackageSource_i"
	done
	if test -n "$getPackageSource_outDir"; then
		printf '%s' "$getPackageSource_outDir"
	else
		printf '%s' "$getPackageSource_tempDir"
	fi
}

# Install a PECL/remote PHP module given its handle
#
# Arguments:
#   $1: the handle of the PHP module
installRemoteModule() {
	installRemoteModule_module="$1"
	printf '### INSTALLING REMOTE MODULE %s ###\n' "$installRemoteModule_module"
	installRemoteModule_version="$(resolveWantedPHPModuleVersion "$installRemoteModule_module")"
	installRemoteModule_path="$(getModuleSourceCodePath "$installRemoteModule_module")"
	rm -rf "$CONFIGURE_FILE"
	installRemoteModule_manuallyInstalled=0
	installRemoteModule_cppflags=''
	installRemoteModule_ini_basename=''
	installRemoteModule_ini_extra=''
	case "$installRemoteModule_module" in
		amqp)
			if test -z "$installRemoteModule_version"; then
				if test "$DISTRO_VERSION" = debian@8; then
					# in Debian Jessie we have librabbitmq version 0.5.2
					installRemoteModule_version=1.9.3
				elif test $PHP_MAJMIN_VERSION -le 505; then
					installRemoteModule_version=1.9.4
				fi
			fi
			;;
		apcu)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=4.0.11
				fi
			fi
			;;
		apcu_bc)
			# apcu_bc must be loaded after apcu
			installRemoteModule_ini_basename="xx-php-ext-$installRemoteModule_module"
			;;
		ast)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 701; then
					installRemoteModule_version=1.0.16
				fi
			fi
			;;
		blackfire)
			case $(uname -m) in
				i386 | i686 | x86)
					installRemoteModule_tmp1=i386
					;;
				aarch64 | arm64 | armv8)
					installRemoteModule_tmp1=arm64
					;;
				*)
					installRemoteModule_tmp1=amd64
					;;
			esac
			case $DISTRO in
				alpine)
					installRemoteModule_distro=alpine
					;;
				*)
					installRemoteModule_distro=linux
					;;
			esac
			installRemoteModule_tmp2=$(php -r 'echo PHP_MAJOR_VERSION . PHP_MINOR_VERSION;')
			installRemoteModule_tmp="$(mktemp -p /tmp/src -d)"
			cd "$installRemoteModule_tmp"
			curl -sSLf --user-agent Docker https://blackfire.io/api/v1/releases/probe/php/$installRemoteModule_distro/$installRemoteModule_tmp1/$installRemoteModule_tmp2 | tar xz
			mv blackfire-*.so $(getPHPExtensionsDir)/blackfire.so
			cd - >/dev/null
			installRemoteModule_manuallyInstalled=1
			installRemoteModule_ini_extra="$(printf '%sblackfire.agent_socket=tcp://blackfire:8307\n' "$installRemoteModule_ini_extra")"
			;;
		cmark)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 701; then
					installRemoteModule_version=1.1.0
				fi
			fi
			if ! test -e /usr/local/lib/libcmark.so && ! test -e /usr/local/lib64/libcmark.so && ! test -e /usr/lib/libcmark.so && ! test -e /usr/lib64/libcmark.so && ! test -e /lib/libcmark.so; then
				if test $(compareVersions "$(cmake --version | head -n1 | sed -E 's/^.* //')" '3.7') -lt 0; then
					installRemoteModule_tmp=0.29.0
				else
					installRemoteModule_tmp=0.30.2
				fi
				cd "$(getPackageSource https://github.com/commonmark/cmark/archive/$installRemoteModule_tmp.tar.gz)"
				make -s -j$(getProcessorCount) cmake_build
				make -s -j$(getProcessorCount) install
				cd - >/dev/null
				case "$DISTRO" in
					alpine)
						if test -e /usr/local/lib64/libcmark.so.$installRemoteModule_tmp && ! test -e /usr/local/lib/libcmark.so.$installRemoteModule_tmp; then
							ln -s /usr/local/lib64/libcmark.so.$installRemoteModule_tmp /usr/local/lib/
						fi
						;;
					*)
						ldconfig || true
						;;
				esac
			fi
			;;
		csv)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 704; then
					installRemoteModule_version=0.3.1
				fi
			fi
			;;
		ddtrace)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -lt 700; then
					installRemoteModule_version=0.75.0
				fi
			fi
			;;
		decimal)
			case "$DISTRO" in
				alpine)
					if ! test -f /usr/local/lib/libmpdec.so; then
						installRemoteModule_src="$(getPackageSource https://www.bytereef.org/software/mpdecimal/releases/mpdecimal-2.5.1.tar.gz)"
						cd -- "$installRemoteModule_src"
						./configure --disable-cxx
						make -j$(getProcessorCount)
						make install
						cd - >/dev/null
					fi
					;;
			esac
			;;
		ds)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 702; then
					installRemoteModule_version=1.3.0
				fi
			fi
			;;
		event)
			if test -z "$installRemoteModule_version" || test $(compareVersions "$installRemoteModule_version" 2.4.0) -ge 0; then
				# Enable internal debugging in Event
				addConfigureOption enable-event-debug no
				# Enable sockets support in Event
				if php --ri sockets >/dev/null 2>/dev/null; then
					addConfigureOption enable-event-sockets yes
				else
					addConfigureOption enable-event-sockets no
				fi
				# libevent installation prefix
				addConfigureOption with-event-libevent-dir /usr
				# Include libevent's pthreads library and enable thread safety support in Event
				addConfigureOption with-event-pthreads yes
				# Include libevent protocol-specific functionality support including HTTP, DNS, and RPC
				addConfigureOption with-event-extra yes
				# Include libevent OpenSSL support
				addConfigureOption with-event-openssl yes
				# PHP Namespace for all Event classes
				if test -n "${IPE_EVENT_NAMESPACE:-}"; then
					addConfigureOption with-event-ns "$IPE_EVENT_NAMESPACE"
				else
					addConfigureOption with-event-ns no
				fi
				# openssl installation prefix
				addConfigureOption with-openssl-dir yes
			elif test $(compareVersions "$installRemoteModule_version" 1.7.6) -ge 0; then
				# Enable internal debugging in Event
				addConfigureOption enable-event-debug no
				# Enable sockets support in Event
				if php --ri sockets >/dev/null 2>/dev/null; then
					addConfigureOption enable-event-sockets yes
				else
					addConfigureOption enable-event-sockets no
				fi
				# libevent installation prefix
				addConfigureOption with-event-libevent-dir /usr
				# Include libevent's pthreads library and enable thread safety support in Event
				addConfigureOption with-event-pthreads yes
				# Include libevent protocol-specific functionality support including HTTP, DNS, and RPC
				addConfigureOption with-event-extra yes
				# Include libevent OpenSSL support
				addConfigureOption with-event-openssl yes
				# openssl installation prefix
				addConfigureOption with-openssl-dir no
			elif test $(compareVersions "$installRemoteModule_version" 1.3.0) -ge 0; then
				# Enable internal debugging in event
				addConfigureOption enable-event-debug no
				# libevent installation prefix
				addConfigureOption with-event-libevent-dir /usr
				# Include libevent's pthreads library and enable thread safety support in event
				addConfigureOption with-event-pthreads yes
				# Include libevent protocol-specific functionality support including HTTP, DNS, and RPC
				addConfigureOption with-event-extra yes
				# Include libevent OpenSSL support
				addConfigureOption with-event-openssl yes
				# openssl installation prefix
				addConfigureOption with-openssl-dir no
			fi
			# event must be loaded after sockets
			installRemoteModule_ini_basename="xx-php-ext-$installRemoteModule_module"
			;;
		gearman)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=1.1.2
				fi
			fi
			case "$DISTRO" in
				alpine)
					if ! test -e /usr/local/include/libgearman/gearman.h || ! test -e /usr/local/lib/libgearman.so; then
						installRemoteModule_src="$(getPackageSource https://github.com/gearman/gearmand/releases/download/1.1.20/gearmand-1.1.20.tar.gz)"
						cd -- "$installRemoteModule_src"
						./configure
						make -j$(getProcessorCount) install-binPROGRAMS
						make -j$(getProcessorCount) install-nobase_includeHEADERS
						cd - >/dev/null
					fi
					;;
			esac
			;;
		geoip)
			if test -z "$installRemoteModule_version"; then
				installRemoteModule_version=beta
			fi
			;;
		geos)
			if test -z "$installRemoteModule_path"; then
				if test -z "$installRemoteModule_version"; then
					installRemoteModule_version=71b5f9001512e16d3cf4657b517e8a051d6ef36f
				fi
				installRemoteModule_src="$(getPackageSource https://git.osgeo.org/gitea/geos/php-geos/archive/$installRemoteModule_version.tar.gz)"
				cd "$installRemoteModule_src"
				./autogen.sh
				./configure
				make -j$(getProcessorCount) install
				cd - >/dev/null
				installRemoteModule_manuallyInstalled=1
			fi
			;;
		geospatial)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=0.2.1
				else
					installRemoteModule_version=beta
				fi
			fi
			;;
		gmagick)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=1.1.7RC3
				else
					installRemoteModule_version=beta
				fi
			fi
			;;
		grpc)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=1.33.1
				fi
			fi
			if test -z "$installRemoteModule_version" || test "$installRemoteModule_version" = 1.35.0; then
				case "$DISTRO_VERSION" in
					alpine@3.13)
						installRemoteModule_cppflags='-Wno-maybe-uninitialized'
						;;
				esac
			fi
			if test -z "$installRemoteModule_version"; then
				case "$DISTRO_VERSION" in
					debian@8)
						installRemoteModule_version=1.46.3
						;;
				esac
			fi
			;;
		http)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=2.6.0
				elif test $PHP_MAJMIN_VERSION -le 704; then
					installRemoteModule_version=3.2.4
				fi
			fi
			if test $PHP_MAJMIN_VERSION -ge 700; then
				if ! test -e /usr/local/lib/libidnkit.so; then
					installRemoteModule_src="$(getPackageSource https://jprs.co.jp/idn/idnkit-2.3.tar.bz2)"
					cd -- "$installRemoteModule_src"
					./configure
					make -j$(getProcessorCount) install
					cd - >/dev/null
				fi
			fi
			# http must be loaded after raphf and propro
			installRemoteModule_ini_basename="xx-php-ext-$installRemoteModule_module"
			;;
		igbinary)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=2.0.8
				fi
			fi
			;;
		inotify)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=0.1.6
				fi
			fi
			;;
		ion)
			if ! test -f /usr/local/lib/libionc.so || ! test -f /usr/local/include/ionc/ion.h; then
				echo 'Installing ion-c... '
				installRemoteModule_src="$(mktemp -p /tmp/src -d)"
				git clone -q -c advice.detachedHead=false --depth 1 --branch v1.1.0 https://github.com/amzn/ion-c.git "$installRemoteModule_src/ion"
				(
					cd "$installRemoteModule_src/ion"
					git submodule init -q
					git submodule update -q
					mkdir -p build
					cd build
					cmake -DCMAKE_BUILD_TYPE=Release .. -Wno-dev
					make clean
					make -j$(getProcessorCount) install
				)
				rm -rf "$installRemoteModule_src"
			fi
			addConfigureOption with-ion "shared,/usr/local"
			;;
		ioncube_loader)
			installIonCubeLoader
			installRemoteModule_manuallyInstalled=1
			;;
		jsmin)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -lt 700; then
					installRemoteModule_version=2.0.1
				fi
			fi
			;;
		luasandbox)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -lt 702; then
					installRemoteModule_version=3.0.3
				fi
			fi
			;;
		lz4)
			if test -z "$installRemoteModule_path"; then
				if test -z "$installRemoteModule_version"; then
					installRemoteModule_version=0.4.3
				fi
				installRemoteModule_src="$(getPackageSource https://github.com/kjdev/php-ext-lz4/archive/refs/tags/$installRemoteModule_version.tar.gz)"
				cd "$installRemoteModule_src"
				phpize
				./configure --with-lz4-includedir=/usr
				make -j$(getProcessorCount) install
				cd - >/dev/null
				installRemoteModule_manuallyInstalled=1
			fi
			;;
		lzf)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -lt 702; then
					installRemoteModule_version=1.6.8
				fi
			fi
			if test -z "$installRemoteModule_version" || test $(compareVersions "$installRemoteModule_version" '1.5.0') -ge 0; then
				# Sacrifice speed in favour of compression ratio?
				case "${IPE_LZF_BETTERCOMPRESSION:-}" in
					1 | y* | Y*)
						addConfigureOption 'enable-lzf-better-compression' 'yes'
						;;
					*)
						addConfigureOption 'enable-lzf-better-compression' 'no'
						;;
				esac
			fi
			;;
		mailparse)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=2.1.6
				elif test $PHP_MAJMIN_VERSION -le 702; then
					installRemoteModule_version=3.1.3
				fi
			fi
			;;
		memcache)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=2.2.7
				elif test $PHP_MAJMIN_VERSION -le 704; then
					installRemoteModule_version=4.0.5.2
				fi
			fi
			;;
		memcached)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=2.2.0
				fi
			fi
			# Set the path to libmemcached install prefix
			addConfigureOption 'with-libmemcached-dir' 'no'
			if test -z "$installRemoteModule_version" || test $(compareVersions "$installRemoteModule_version" '3.0.0') -ge 0; then
				# Set the path to ZLIB install prefix
				addConfigureOption 'with-zlib-dir' 'no'
				# Use system FastLZ library
				addConfigureOption 'with-system-fastlz' 'no'
				# Enable memcached igbinary serializer support
				if php --ri igbinary >/dev/null 2>/dev/null; then
					addConfigureOption 'enable-memcached-igbinary' 'yes'
				else
					addConfigureOption 'enable-memcached-igbinary' 'no'
				fi
				# Enable memcached msgpack serializer support
				if php --ri msgpack >/dev/null 2>/dev/null; then
					addConfigureOption 'enable-memcached-msgpack' 'yes'
				else
					addConfigureOption 'enable-memcached-msgpack' 'no'
				fi
				# Enable memcached json serializer support
				addConfigureOption 'enable-memcached-json' 'yes'
				# Enable memcached protocol support
				addConfigureOption 'enable-memcached-protocol' 'no' # https://github.com/php-memcached-dev/php-memcached/issues/418#issuecomment-449587972
				# Enable memcached sasl support
				addConfigureOption 'enable-memcached-sasl' 'yes'
				# Enable memcached session handler support
				addConfigureOption 'enable-memcached-session' 'yes'
			fi
			# memcached must be loaded after msgpack
			installRemoteModule_ini_basename="xx-php-ext-$installRemoteModule_module"
			;;
		memprof)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=1.0.0
				elif test $PHP_MAJMIN_VERSION -le 700; then
					installRemoteModule_version=2.1.0
				fi
			fi
			;;
		mongo)
			if test -z "$installRemoteModule_version" || test $(compareVersions "$installRemoteModule_version" '1.5.0') -ge 0; then
				# Build with Cyrus SASL (MongoDB Enterprise Authentication) support?
				addConfigureOption '-with-mongo-sasl' 'yes'
			fi
			;;
		mongodb)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 505; then
					installRemoteModule_version=1.5.5
				elif test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=1.7.5
				elif test $PHP_MAJMIN_VERSION -le 700; then
					installRemoteModule_version=1.9.2
				elif test $PHP_MAJMIN_VERSION -le 701; then
					installRemoteModule_version=1.11.1
				fi
			fi
			;;
		mosquitto)
			if test -z "$installRemoteModule_version"; then
				installRemoteModule_version=beta
			fi
			;;
		msgpack)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=0.5.7
				fi
			fi
			;;
		oauth)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=1.2.3
				fi
			fi
			;;
		opencensus)
			if test -z "$installRemoteModule_version"; then
				installRemoteModule_version=alpha
			fi
			;;
		openswoole)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -lt 704; then
					installRemoteModule_version=4.10.0
				fi
			fi
			if php --ri sockets >/dev/null 2>/dev/null; then
				installRemoteModule_sockets=yes
				installRemoteModule_ini_basename="xx-php-ext-$installRemoteModule_module"
			else
				installRemoteModule_sockets=no
			fi
			installRemoteModule_openssl=yes
			# enable sockets supports?
			addConfigureOption enable-sockets $installRemoteModule_sockets
			# enable openssl support?
			addConfigureOption enable-openssl $installRemoteModule_openssl
			# enable http2 support?
			addConfigureOption enable-http2 yes
			# enable mysqlnd support?
			addConfigureOption enable-mysqlnd yes
			# enable json support?
			addConfigureOption enable-swoole-json yes
			# enable curl support?
			addConfigureOption enable-swoole-curl yes
			if test -z "$installRemoteModule_version" || test $(compareVersions "$installRemoteModule_version" '4.8.0') -ge 0; then
				# enable postgres support?
				addConfigureOption with-postgres yes
			fi
			;;
		parallel)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 701; then
					installRemoteModule_version=0.8.3
				elif test $PHP_MAJMIN_VERSION -le 704; then
					installRemoteModule_version=1.1.4
				fi
			fi
			;;
		parle)
			if test -z "$installRemoteModule_version"; then
				installRemoteModule_version=beta
			fi
			;;
		pcov)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 700; then
					installRemoteModule_version=0.9.0
				fi
			fi
			;;
		php_trie)
			if ! test -f /usr/local/include/hat-trie/include/tsl/htrie_map.h; then
				installRemoteModule_src="$(getPackageSource https://codeload.github.com/Tessil/hat-trie/tar.gz/v0.6.0)"
				mkdir -p /usr/local/include/hat-trie
				mv "$installRemoteModule_src/include" /usr/local/include/hat-trie
			fi
			;;
		propro)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=1.0.2
				fi
			fi
			;;
		protobuf)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=3.12.4
				else
					# see https://github.com/protocolbuffers/protobuf/issues/10619
					installRemoteModule_version=3.21.6
				fi
			fi
			;;
		pthreads)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=2.0.10
				fi
			fi
			;;
		raphf)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=1.1.2
				fi
			fi
			;;
		rdkafka)
			if test -z "$installRemoteModule_version"; then
				installRemoteModule_version1=''
				if test $PHP_MAJMIN_VERSION -le 505; then
					installRemoteModule_version1=3.0.5
				elif test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version1=4.1.2
				fi
				installRemoteModule_version2=''
				case "$DISTRO" in
					alpine)
						installRemoteModule_tmp='librdkafka'
						;;
					debian)
						installRemoteModule_tmp='librdkafka*'
						;;
					*)
						installRemoteModule_tmp=''
						;;
				esac
				if test -n "$installRemoteModule_tmp"; then
					installRemoteModule_tmp="$(getInstalledPackageVersion "$installRemoteModule_tmp")"
					if test -n "$installRemoteModule_tmp" && test $(compareVersions "$installRemoteModule_tmp" '0.11.0') -lt 0; then
						installRemoteModule_version2=3.1.3
					fi
				fi
				if test -z "$installRemoteModule_version1" || test -z "$installRemoteModule_version2"; then
					installRemoteModule_version="$installRemoteModule_version1$installRemoteModule_version2"
				elif test $(compareVersions "$installRemoteModule_version1" "$installRemoteModule_version2") -le 0; then
					installRemoteModule_version="$installRemoteModule_version1"
				else
					installRemoteModule_version="$installRemoteModule_version2"
				fi
			fi
			;;
		redis)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=4.3.0
				fi
			fi
			# Enable igbinary serializer support?
			if php --ri igbinary >/dev/null 2>/dev/null; then
				addConfigureOption 'enable-redis-igbinary' 'yes'
			else
				addConfigureOption 'enable-redis-igbinary' 'no'
			fi
			# Enable lzf compression support?
			addConfigureOption 'enable-redis-lzf' 'yes'
			if test -z "$installRemoteModule_version" || test $(compareVersions "$installRemoteModule_version" '5.0.0') -ge 0; then
				if ! test -e /usr/include/zstd.h || ! test -e /usr/lib/libzstd.so -o -e "/usr/lib/$TARGET_TRIPLET/libzstd.so"; then
					installRemoteModule_zstdVersion=1.4.4
					installRemoteModule_zstdVersionMajor=$(echo $installRemoteModule_zstdVersion | cut -d. -f1)
					rm -rf /tmp/src/zstd
					mv "$(getPackageSource https://github.com/facebook/zstd/releases/download/v$installRemoteModule_zstdVersion/zstd-$installRemoteModule_zstdVersion.tar.gz)" /tmp/src/zstd
					cd /tmp/src/zstd
					make V=0 -j$(getProcessorCount) lib
					cp -f lib/libzstd.so "/usr/lib/$TARGET_TRIPLET/libzstd.so.$installRemoteModule_zstdVersion"
					ln -sf "/usr/lib/$TARGET_TRIPLET/libzstd.so.$installRemoteModule_zstdVersion" "/usr/lib/$TARGET_TRIPLET/libzstd.so.$installRemoteModule_zstdVersionMajor"
					ln -sf "/usr/lib/$TARGET_TRIPLET/libzstd.so.$installRemoteModule_zstdVersion" "/usr/lib/$TARGET_TRIPLET/libzstd.so"
					ln -sf /tmp/src/zstd/lib/zstd.h /usr/include/zstd.h
					UNNEEDED_PACKAGE_LINKS="$UNNEEDED_PACKAGE_LINKS /usr/include/zstd.h"
					cd - >/dev/null
				fi
				# Enable zstd compression support?
				addConfigureOption 'enable-redis-zstd' 'yes'
			fi
			;;
		relay)
			if test -z "$installRemoteModule_version"; then
				installRemoteModule_version="$(curl -sSLf https://cachewerk.s3.amazonaws.com/relay/LATEST)"
				installRemoteModule_version="${installRemoteModule_version#v}"
			fi
			case $(uname -m) in
				aarch64 | arm64 | armv8)
					installRemoteModule_hardware=aarch64
					;;
				*)
					installRemoteModule_hardware=x86-64
					;;
			esac
			printf 'Downloading relay v%s (%s)... ' "$installRemoteModule_version" "$installRemoteModule_hardware"
			installRemoteModule_url="https://cachewerk.s3.amazonaws.com/relay/v${installRemoteModule_version}/relay-v${installRemoteModule_version}-php${PHP_MAJDOTMIN_VERSION}-${DISTRO}-${installRemoteModule_hardware}.tar.gz"
			installRemoteModule_src="$(getPackageSource $installRemoteModule_url)"
			echo 'done.'
			cp -- "$installRemoteModule_src/relay-pkg.so" "$PHP_EXTDIR/relay.so"
			sed -i "s/00000000-0000-0000-0000-000000000000/$(cat /proc/sys/kernel/random/uuid)/" "$PHP_EXTDIR/relay.so"
			installRemoteModule_ini_extra="$(grep -vE '^[ \t]*extension[ \t]*=' $installRemoteModule_src/relay.ini)"
			installRemoteModule_manuallyInstalled=1
			;;
		snappy)
			if test -z "$installRemoteModule_path"; then
				if test -z "$installRemoteModule_version"; then
					installRemoteModule_version=0.2.1
				fi
				installRemoteModule_src="$(getPackageSource https://github.com/kjdev/php-ext-snappy/archive/refs/tags/$installRemoteModule_version.tar.gz)"
				cd "$installRemoteModule_src"
				phpize
				./configure --with-snappy-includedir=/usr
				make -j$(getProcessorCount) install
				cd - >/dev/null
				installRemoteModule_manuallyInstalled=1
			fi
			;;
		snuffleupagus)
			if test -z "$installRemoteModule_path"; then
				if test -z "$installRemoteModule_version"; then
					installRemoteModule_version=0.8.2
				fi
				installRemoteModule_src="$(getPackageSource https://codeload.github.com/jvoisin/snuffleupagus/tar.gz/v$installRemoteModule_version)"
				cd "$installRemoteModule_src/src"
				phpize
				./configure --enable-snuffleupagus
				make -j$(getProcessorCount) install
				cd - >/dev/null
				cp -a "$installRemoteModule_src/config/default.rules" "$PHP_INI_DIR/conf.d/snuffleupagus.rules"
				if test $(compareVersions "$installRemoteModule_version" 0.8.0) -ge 0; then
					printf '\n# Disable "PHP version is not officially maintained anymore" message\nsp.global.show_old_php_warning.disable();\n' >>"$PHP_INI_DIR/conf.d/snuffleupagus.rules"
				fi
			else
				if test -f "$installRemoteModule_path/config/default.rules"; then
					cp -a "$installRemoteModule_path/config/default.rules" "$PHP_INI_DIR/conf.d/snuffleupagus.rules"
				fi
			fi
			installRemoteModule_ini_extra="$(printf '%ssp.configuration_file=%s\n' "$installRemoteModule_ini_extra" "$PHP_INI_DIR/conf.d/snuffleupagus.rules")"
			installRemoteModule_manuallyInstalled=1
			;;
		sodium | libsodium)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -lt 700; then
					installRemoteModule_version=1.0.7
				fi
			fi
			;;
		solr)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=2.4.0
				fi
			fi
			;;
		sourceguardian)
			installSourceGuardian
			installRemoteModule_manuallyInstalled=1
			;;
		spx)
			if test -z "$installRemoteModule_path"; then
				if test -z "$installRemoteModule_version"; then
					installRemoteModule_version=v0.4.13
				fi
				if test "${installRemoteModule_version%.*}" = "$installRemoteModule_version"; then
					installRemoteModule_displayVersion="$installRemoteModule_version"
				else
					installRemoteModule_displayVersion="git--master-$installRemoteModule_version"
				fi
				installRemoteModule_src="$(getPackageSource https://codeload.github.com/NoiseByNorthwest/php-spx/tar.gz/$installRemoteModule_version)"
				cd -- "$installRemoteModule_src"
				phpize
				./configure
				make -j$(getProcessorCount) install
				cd - >/dev/null
				installRemoteModule_manuallyInstalled=1
			fi
			;;
		sqlsrv | pdo_sqlsrv)
			isMicrosoftSqlServerODBCInstalled || installMicrosoftSqlServerODBC
			if test -z "$installRemoteModule_version"; then
				# https://docs.microsoft.com/it-it/sql/connect/php/system-requirements-for-the-php-sql-driver?view=sql-server-2017
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=3.0.1
				elif test $PHP_MAJMIN_VERSION -le 700; then
					installRemoteModule_version=5.3.0
				elif test $PHP_MAJMIN_VERSION -le 701; then
					installRemoteModule_version=5.6.1
				elif test $PHP_MAJMIN_VERSION -le 702; then
					installRemoteModule_version=5.8.1
				elif test $PHP_MAJMIN_VERSION -le 703; then
					installRemoteModule_version=5.9.0
				fi
			fi
			;;
		ssh2)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=0.13
				else
					installRemoteModule_version=beta
				fi
			fi
			;;
		stomp)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=1.0.9
				fi
			fi
			if test "$DISTRO" = debian; then
				addConfigureOption with-openssl-dir yes
			else
				addConfigureOption with-openssl-dir /usr
			fi
			;;
		swoole)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 502; then
					installRemoteModule_version=1.6.10
				elif test $PHP_MAJMIN_VERSION -le 504; then
					installRemoteModule_version=2.0.4
				elif test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=2.0.11
				elif test $PHP_MAJMIN_VERSION -le 700; then
					installRemoteModule_version=4.3.6
				elif test $PHP_MAJMIN_VERSION -le 701; then
					installRemoteModule_version=4.5.10
				elif test $PHP_MAJMIN_VERSION -le 704; then
					installRemoteModule_version=4.8.11
				fi
			fi
			if php --ri sockets >/dev/null 2>/dev/null; then
				installRemoteModule_sockets=yes
			else
				installRemoteModule_sockets=no
			fi
			installRemoteModule_openssl=yes
			case "$DISTRO_VERSION" in
				alpine@3.7 | alpine@3.8)
					if test -n "$installRemoteModule_version" && test $(compareVersions "$installRemoteModule_version" 4.6.0) -lt 0; then
						# see https://github.com/swoole/swoole-src/issues/3934
						installRemoteModule_openssl=no
					fi
					;;
			esac
			if test -z "$installRemoteModule_version" || test $(compareVersions "$installRemoteModule_version" 5.0.0) -ge 0; then
				# enable sockets supports?
				addConfigureOption enable-sockets $installRemoteModule_sockets
				# enable openssl support?
				addConfigureOption enable-openssl $installRemoteModule_openssl
				# enable mysqlnd support?
				addConfigureOption enable-mysqlnd yes
				# enable curl support?
				addConfigureOption enable-swoole-curl yes
				# enable cares support?
				addConfigureOption enable-cares yes
			elif test $(compareVersions "$installRemoteModule_version" 4.6.1) -ge 0; then
				# enable sockets supports?
				addConfigureOption enable-sockets $installRemoteModule_sockets
				# enable openssl support?
				addConfigureOption enable-openssl $installRemoteModule_openssl
				# enable http2 support?
				addConfigureOption enable-http2 yes
				# enable mysqlnd support?
				addConfigureOption enable-mysqlnd yes
				# enable json support?
				addConfigureOption enable-swoole-json yes
				# enable curl support?
				if test $PHP_MAJMINPAT_VERSION -ne 80000 || test $(compareVersions "$installRemoteModule_version" 4.6.1) -ge 0; then
					addConfigureOption enable-swoole-curl yes
				else
					# https://github.com/swoole/swoole-src/issues/3977#issuecomment-754755521
					addConfigureOption enable-swoole-curl no
				fi
				if test $(compareVersions "$installRemoteModule_version" 4.8.11) -ge 0; then
					# enable cares support?
					addConfigureOption enable-cares yes
				fi
			elif test $(compareVersions "$installRemoteModule_version" 4.4.0) -ge 0; then
				# enable sockets supports?
				addConfigureOption enable-sockets $installRemoteModule_sockets
				# enable openssl support?
				addConfigureOption enable-openssl $installRemoteModule_openssl
				# enable http2 support?
				addConfigureOption enable-http2 yes
				# enable mysqlnd support?
				addConfigureOption enable-mysqlnd yes
			elif test $(compareVersions "$installRemoteModule_version" 4.2.11) -ge 0; then
				# enable sockets supports?
				addConfigureOption enable-sockets $installRemoteModule_sockets
				# enable openssl support?
				addConfigureOption enable-openssl $installRemoteModule_openssl
				# enable http2 support?
				addConfigureOption enable-http2 yes
				# enable mysqlnd support?
				addConfigureOption enable-mysqlnd yes
				# enable postgresql coroutine client support?
				addConfigureOption enable-coroutine-postgresql yes
			elif test $(compareVersions "$installRemoteModule_version" 4.2.7) -ge 0; then
				# enable sockets supports?
				addConfigureOption enable-sockets $installRemoteModule_sockets
				# enable openssl support?
				addConfigureOption enable-openssl $installRemoteModule_openssl
				# enable http2 support?
				addConfigureOption enable-http2 yes
				# enable mysqlnd support?
				addConfigureOption enable-mysqlnd yes
				# enable postgresql coroutine client support?
				addConfigureOption enable-coroutine-postgresql yes
				# enable kernel debug/trace log? (it will degrade performance)
				addConfigureOption enable-debug-log no
			elif test $(compareVersions "$installRemoteModule_version" 4.2.6) -ge 0; then
				# enable debug/trace log support?
				addConfigureOption enable-debug-log no
				# enable sockets supports?
				addConfigureOption enable-sockets $installRemoteModule_sockets
				# enable openssl support?
				addConfigureOption enable-openssl $installRemoteModule_openssl
				# enable http2 support?
				addConfigureOption enable-http2 yes
				# enable mysqlnd support?
				addConfigureOption enable-mysqlnd yes
				# enable postgresql coroutine client support?
				addConfigureOption enable-coroutine-postgresql yes
			elif test $(compareVersions "$installRemoteModule_version" 4.2.0) -ge 0; then
				# enable debug/trace log support?
				addConfigureOption enable-debug-log no
				# enable sockets supports?
				addConfigureOption enable-sockets $installRemoteModule_sockets
				# enable openssl support?
				addConfigureOption enable-openssl $installRemoteModule_openssl
				# enable http2 support?
				addConfigureOption enable-http2 yes
				# enable async-redis support?
				addConfigureOption enable-async-redis yes
				# enable mysqlnd support?
				addConfigureOption enable-mysqlnd yes
				# enable postgresql coroutine client support?
				addConfigureOption enable-coroutine-postgresql yes
			elif test $(compareVersions "$installRemoteModule_version" 2.1.2) -ge 0; then
				# enable debug/trace log support?
				addConfigureOption enable-swoole-debug no
				# enable sockets supports?
				addConfigureOption enable-sockets $installRemoteModule_sockets
				# enable openssl support?
				addConfigureOption enable-openssl $installRemoteModule_openssl
				# enable http2 support?
				addConfigureOption enable-http2 yes
				# enable async-redis support?
				addConfigureOption enable-async-redis yes
				# enable mysqlnd support?
				addConfigureOption enable-mysqlnd yes
				# enable postgresql coroutine client support?
				addConfigureOption enable-coroutine-postgresql yes
			elif test $(compareVersions "$installRemoteModule_version" 1.10.4) -ge 0 && test $(compareVersions "$installRemoteModule_version" 1.10.5) -le 0; then
				# enable debug/trace log support?
				addConfigureOption enable-swoole-debug no
				# enable sockets supports?
				addConfigureOption enable-sockets $installRemoteModule_sockets
				# enable openssl support?
				addConfigureOption enable-openssl $installRemoteModule_openssl
				# enable http2 support?
				addConfigureOption enable-http2 yes
				# enable async-redis support?
				addConfigureOption enable-async-redis yes
				# enable mysqlnd support?
				addConfigureOption enable-mysqlnd yes
			fi
			;;
		tdlib)
			if ! test -f /usr/lib/libphpcpp.so || ! test -f /usr/include/phpcpp.h; then
				if test $PHP_MAJMIN_VERSION -le 701; then
					cd "$(getPackageSource https://codeload.github.com/CopernicaMarketingSoftware/PHP-CPP/tar.gz/v2.1.4)"
				elif test $PHP_MAJMIN_VERSION -le 703; then
					cd "$(getPackageSource https://codeload.github.com/CopernicaMarketingSoftware/PHP-CPP/tar.gz/v2.2.0)"
				else
					cd "$(getPackageSource https://codeload.github.com/CopernicaMarketingSoftware/PHP-CPP/tar.gz/444d1f90cf6b7f3cb5178fa0d0b5ab441b0389d0)"
				fi
				make -j$(getProcessorCount)
				make install
				cd - >/dev/null
			fi
			if test -z "$installRemoteModule_path"; then
				installRemoteModule_tmp="$(mktemp -p /tmp/src -d)"
				git clone --depth=1 --recurse-submodules https://github.com/yaroslavche/phptdlib.git "$installRemoteModule_tmp"
				mkdir "$installRemoteModule_tmp/build"
				cd "$installRemoteModule_tmp/build"
				cmake -D USE_SHARED_PHPCPP:BOOL=ON ..
				make
				make install
				cd - >/dev/null
				rm "$PHP_INI_DIR/conf.d/tdlib.ini"
				installRemoteModule_manuallyInstalled=1
			fi
			;;
		tensor)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 703; then
					installRemoteModule_version=2.2.3
				fi
			fi
			;;
		uopz)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=2.0.7
				elif test $PHP_MAJMIN_VERSION -le 700; then
					installRemoteModule_version=5.0.2
				elif test $PHP_MAJMIN_VERSION -le 740; then
					installRemoteModule_version=6.1.2
				fi
			fi
			;;
		uploadprogress)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 701; then
					installRemoteModule_version=1.1.4
				fi
			fi
			;;
		uuid)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=1.0.5
				fi
			fi
			;;
		xdebug)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 500; then
					installRemoteModule_version=2.0.5
				elif test $PHP_MAJMIN_VERSION -le 503; then
					installRemoteModule_version=2.2.7
				elif test $PHP_MAJMIN_VERSION -le 504; then
					installRemoteModule_version=2.4.1
				elif test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=2.5.5
				elif test $PHP_MAJMIN_VERSION -le 700; then
					installRemoteModule_version=2.6.1
				elif test $PHP_MAJMIN_VERSION -le 701; then
					installRemoteModule_version=2.9.8
				elif test $PHP_MAJMIN_VERSION -le 704; then
					installRemoteModule_version=3.1.6
				fi
			fi
			;;
		xdiff)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=1.5.2
				fi
			fi
			if ! test -f /usr/local/lib/libxdiff.* && ! test -f /usr/lib/libxdiff.* && ! test -f /usr/lib/x86_64*/libxdiff.*; then
				installRemoteModule_src="$(getPackageSource https://raw.githubusercontent.com/mlocati/docker-php-extension-installer/assets/resources/libxdiff-0.23.tar.gz)"
				cd -- "$installRemoteModule_src"
				./configure --disable-shared --disable-dependency-tracking --with-pic
				make -j$(getProcessorCount)
				make install
				cd - >/dev/null
			fi
			;;
		xhprof)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=0.9.4
				fi
			fi
			;;
		xlswriter)
			if test -z "$installRemoteModule_version" || test $(compareVersions "$installRemoteModule_version" 1.2.7) -ge 0; then
				# enable reader supports?
				addConfigureOption enable-reader yes
			fi
			;;
		yac)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=0.9.2
				fi
			fi
			if test -z "$installRemoteModule_version" || test $(compareVersions "$installRemoteModule_version" 2.2.0) -ge 0; then
				# Enable igbinary serializer support
				if php --ri igbinary >/dev/null 2>/dev/null; then
					addConfigureOption enable-igbinary yes
				else
					addConfigureOption enable-igbinary no
				fi
				# Enable json serializer support
				if php --ri json >/dev/null 2>/dev/null; then
					addConfigureOption enable-json yes
				else
					addConfigureOption enable-json no
				fi
				# Enable msgpack serializer support
				if php --ri msgpack >/dev/null 2>/dev/null; then
					addConfigureOption enable-msgpack yes
				else
					addConfigureOption enable-msgpack no
				fi
			fi
			;;
		yaml)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=1.3.1
				elif test $PHP_MAJMIN_VERSION -le 700; then
					installRemoteModule_version=2.0.4
				fi
			fi
			;;
		yar)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=1.2.5
				fi
			fi
			if test -z "$installRemoteModule_version" || test $(compareVersions "$installRemoteModule_version" 1.2.4) -ge 0; then
				# Enable Msgpack Supports
				if php --ri msgpack >/dev/null 2>/dev/null; then
					addConfigureOption enable-msgpack yes
				else
					addConfigureOption enable-msgpack no
				fi
			fi
			;;
		zookeeper)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=0.5.0
				else
					installRemoteModule_version=1.0.0
				fi
			fi
			case "$DISTRO" in
				alpine)
					if ! test -f /usr/local/include/zookeeper/zookeeper.h; then
						if test $(compareVersions "$installRemoteModule_version" 1.0.0) -lt 0; then
							installRemoteModule_src="$(getPackageSource http://archive.apache.org/dist/zookeeper/zookeeper-3.5.9/apache-zookeeper-3.5.9.tar.gz)"
						else
							installRemoteModule_tmp="$(curl -sSLf https://downloads.apache.org/zookeeper/stable | sed -E 's/["<>]/\n/g' | grep -E '^(apache-)?zookeeper-[0-9]+\.[0-9]+\.[0-9]+\.(tar\.gz|tgz)$' | head -n1)"
							if test -z "$installRemoteModule_tmp"; then
								echo 'Failed to detect the zookeeper library URL' >&2
								exit 1
							fi
							installRemoteModule_src="$(getPackageSource https://downloads.apache.org/zookeeper/stable/$installRemoteModule_tmp)"
						fi
						cd -- "$installRemoteModule_src"
						if test -d ~/.m2; then
							installRemoteModule_delm2=n
						else
							installRemoteModule_delm2=y
						fi
						mvn -pl zookeeper-jute compile
						cd - >/dev/null
						cd -- "$installRemoteModule_src/zookeeper-client/zookeeper-client-c"
						autoreconf -if
						./configure --without-cppunit
						make -j$(getProcessorCount) CFLAGS='-Wno-stringop-truncation -Wno-format-overflow'
						make install
						cd - >/dev/null
						if test $installRemoteModule_delm2 = y; then
							rm -rf ~/.m2
						fi
					fi
					;;
			esac
			;;
		zstd)
			if test -z "$installRemoteModule_version"; then
				if test $PHP_MAJMIN_VERSION -le 506; then
					installRemoteModule_version=0.11.0
				fi
			fi
			;;
	esac
	if test $installRemoteModule_manuallyInstalled -eq 0; then
		if test -n "$installRemoteModule_path"; then
			printf '  (installing version %s from %s)\n' "$installRemoteModule_version" "$installRemoteModule_path"
		elif test -n "$installRemoteModule_version"; then
			printf '  (installing version %s)\n' "$installRemoteModule_version"
		fi
		installPeclPackage "$installRemoteModule_module" "$installRemoteModule_version" "$installRemoteModule_cppflags" "$installRemoteModule_path"
	fi
	postProcessModule "$installRemoteModule_module"
	checkModuleWorking "$installRemoteModule_module" "$installRemoteModule_ini_basename" "$installRemoteModule_ini_extra"
	enablePhpExtension "$installRemoteModule_module" "$installRemoteModule_ini_basename" "$installRemoteModule_ini_extra"
}

# Check if a module/helper may be installed using the pecl archive
#
# Arguments:
#   $1: the name of the module
#
# Return:
#   0: true
#   1: false
moduleMayUsePecl() {
	case "$1" in
		@composer | @fix_letsencrypt)
			return 1
			;;
		blackfire | geos | ioncube_loader | snuffleupagus | sourceguardian | spx | tdlib)
			return 1
			;;
	esac
	if test -n "$(getModuleSourceCodePath "$1")"; then
		return 1
	fi
	if stringInList "$1" "$BUNDLED_MODULES"; then
		return 1
	fi
	return 0
}

# Configure the PECL package installer
#
# Updates:
#   PHP_MODULES_TO_INSTALL
# Sets:
#   USE_PICKLE
configureInstaller() {
	USE_PICKLE=0
	for PHP_MODULE_TO_INSTALL in $PHP_MODULES_TO_INSTALL; do
		if moduleMayUsePecl "$PHP_MODULE_TO_INSTALL"; then
			if test $PHP_MAJMIN_VERSION -lt 800; then
				pecl channel-update pecl.php.net || true
				return
			fi
			if false && anyStringInList '' "$PHP_MODULES_TO_INSTALL"; then
				USE_PICKLE=2
			else
				curl -sSLf https://github.com/FriendsOfPHP/pickle/releases/latest/download/pickle.phar -o /tmp/pickle
				chmod +x /tmp/pickle
				USE_PICKLE=1
			fi
			return
		fi
	done
}

buildPickle() {
	printf '### BUILDING PICKLE ###\n'
	buildPickle_tempDir="$(mktemp -p /tmp/src -d)"
	cd -- "$buildPickle_tempDir"
	printf 'Downloading... '
	git clone --quiet --depth 1 https://github.com/FriendsOfPHP/pickle.git .
	git tag 0.7.0
	printf 'done.\n'
	printf 'Installing composer... '
	actuallyInstallComposer . composer '--1 --quiet'
	printf 'done.\n'
	printf 'Installing composer dependencies... '
	./composer install --no-dev --no-progress --no-suggest --optimize-autoloader --ignore-platform-reqs --quiet --no-cache
	printf 'done.\n'
	printf 'Building... '
	php -d phar.readonly=0 box.phar build
	mv pickle.phar /tmp/pickle
	printf 'done.\n'
	cd - >/dev/null
}

# Add a configure option for the pecl/pickle install command
#
# Arguments:
#   $1: the option name
#   $2: the option value
addConfigureOption() {
	if test $USE_PICKLE -eq 0; then
		printf -- '%s\n' "$2" >>"$CONFIGURE_FILE"
	else
		printf -- '--%s=%s\n' "$1" "$2" >>"$CONFIGURE_FILE"
	fi
}

# Actually installs a PECL package
#
# Arguments:
#   $1: the package to be installed
#   $2: the package version to be installed (optional)
#   $3: the value of the CPPFLAGS variable (optional)
#   $4: the path of the local package to be installed (optional, downloaded from PECL if omitted/empty)
installPeclPackage() {
	if ! test -f "$CONFIGURE_FILE"; then
		printf '\n' >"$CONFIGURE_FILE"
	fi
	installPeclPackage_name="$(getPeclModuleName "$1")"
	if test -z "${2:-}"; then
		installPeclPackage_fullname="$installPeclPackage_name"
	else
		installPeclPackage_fullname="$installPeclPackage_name-$2"
	fi
	installPeclPackage_path="${4:-}"
	if test -z "$installPeclPackage_path"; then
		installPeclPackage_path="$installPeclPackage_fullname"
	fi
	if test $USE_PICKLE -eq 0; then
		if test -n "${4:-}"; then
			if test -f "$installPeclPackage_path/package2.xml"; then
				installPeclPackage_path="$installPeclPackage_path/package2.xml"
			else
				installPeclPackage_path="$installPeclPackage_path/package.xml"
			fi
		fi
		cat "$CONFIGURE_FILE" | MAKE="make -j$(getCompilationProcessorCount $1)" CPPFLAGS="${3:-}" pecl install "$installPeclPackage_path"
	else
		MAKEFLAGS="-j$(getCompilationProcessorCount $1)" CPPFLAGS="${3:-}" /tmp/pickle install --tmp-dir=/tmp/pickle.tmp --no-interaction --version-override='' --with-configure-options "$CONFIGURE_FILE" -- "$installPeclPackage_path"
	fi
}

# Check if a string is in a list of space-separated string
#
# Arguments:
#   $1: the string to be checked
#   $2: the string list
#
# Return:
#   0 (true): if the string is in the list
#   1 (false): if the string is not in the list
stringInList() {
	for stringInList_listItem in $2; do
		if test "$1" = "$stringInList_listItem"; then
			return 0
		fi
	done
	return 1
}

# Check if at least one item in a list is in another list
#
# Arguments:
#   $1: the space-separated list of items to be searched
#   $2: the space-separated list of reference items
#
# Return:
#   0 (true): at least one of the items in $1 is in $2
#   1 (false): otherwise
anyStringInList() {
	for anyStringInList_item in $1; do
		if stringInList "$anyStringInList_item" "$2"; then
			return 0
		fi
	done
	return 1
}

# Remove a word from a space-separated list
#
# Arguments:
#   $1: the word to be removed
#   $2: the string list
#
# Output:
#   The list without the word
removeStringFromList() {
	removeStringFromList_result=''
	for removeStringFromList_listItem in $2; do
		if test "$1" != "$removeStringFromList_listItem"; then
			if test -z "$removeStringFromList_result"; then
				removeStringFromList_result="$removeStringFromList_listItem"
			else
				removeStringFromList_result="$removeStringFromList_result $removeStringFromList_listItem"
			fi
		fi
	done
	printf '%s' "$removeStringFromList_result"
}

# Fix the Let's Encrypt CA certificates on old distros
fixLetsEncrypt() {
	printf '### FIXING LETS ENCRYPT CA CERTIFICATES ###\n'
	case "$DISTRO_VERSION" in
		alpine@3.7 | alpine@3.8)
			printf -- '- old Alpine Linux detected: we should fix the certificates\n'
			;;
		debian@8 | debian@9)
			printf -- '- old Debian detected: we should fix the certificates\n'
			if ! grep -q 'mozilla/ISRG_Root_X1.crt' /etc/ca-certificates.conf && grep -q 'mozilla/DST_Root_CA_X3.crt' /etc/ca-certificates.conf; then
				printf -- '- old ca-certificates package detected\n'
				fixCACerts_mustUpdate=1
				if test -d /var/lib/apt/lists; then
					for fixCACerts_item in $(ls -1 /var/lib/apt/lists); do
						case "$fixCACerts_item" in
							partial | lock) ;;
							*)
								fixCACerts_mustUpdate=0
								break
								;;
						esac
					done
				fi
				if test $fixCACerts_mustUpdate -eq 1; then
					printf -- '- refreshing the APT package list\n'
					DEBIAN_FRONTEND=noninteractive apt-get update -qq
				fi
				printf -- '- installing newer ca-certificates package\n'
				DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends ca-certificates
			fi
			;;
		*)
			printf -- '- patch not required in this distro version\n'
			return
			;;
	esac
	if grep -Eq '^mozilla/ISRG_Root_X1\.crt$' /etc/ca-certificates.conf && grep -Eq '^mozilla/DST_Root_CA_X3\.crt$' /etc/ca-certificates.conf; then
		printf -- '- disabling the DST_Root_CA_X3 certificate\n'
		sed -i '/^mozilla\/DST_Root_CA_X3/s/^/!/' /etc/ca-certificates.conf
		printf -- '- refreshing the certificates\n'
		update-ca-certificates -f
	else
		printf -- '- DST_Root_CA_X3 certificate not found or already disabled\n'
	fi
}

# Cleanup everything at the end of the execution
cleanup() {
	if test -n "$UNNEEDED_PACKAGE_LINKS"; then
		printf '### REMOVING UNNEEDED PACKAGE LINKS ###\n'
		for cleanup_link in $UNNEEDED_PACKAGE_LINKS; do
			if test -L "$cleanup_link"; then
				rm -f "$cleanup_link"
			fi
		done
	fi
	if test -n "$PACKAGES_VOLATILE"; then
		printf '### REMOVING UNNEEDED PACKAGES ###\n'
		case "$DISTRO" in
			alpine)
				apk del --purge $PACKAGES_VOLATILE
				;;
			debian)
				DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y $PACKAGES_VOLATILE
				;;
		esac
	fi
	if test -n "$PACKAGES_PREVIOUS"; then
		case "$DISTRO" in
			debian)
				printf '### RESTORING PREVIOUSLY INSTALLED PACKAGES ###\n'
				DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-upgrade -qqy $PACKAGES_PREVIOUS
				;;
		esac
	fi
	docker-php-source delete
	rm -rf /tmp/src
	rm -rf /tmp/pickle
	rm -rf /tmp/pickle.tmp
	rm -rf "$CONFIGURE_FILE"
	case "${IPE_KEEP_SYSPKG_CACHE:-}" in
		1 | y* | Y*) ;;
		*)
			case "$DISTRO" in
				alpine)
					rm -rf /var/cache/apk/*
					;;
				debian)
					rm -rf /var/lib/apt/lists/*
					;;
			esac
			rm -rf /tmp/pear
			;;
	esac
}

resetIFS
mkdir -p /tmp/src
mkdir -p /tmp/pickle.tmp
IPE_ERRFLAG_FILE="$(mktemp -p /tmp/src)"
CONFIGURE_FILE=/tmp/configure-options
IPE_APK_FLAGS=''
setDistro
case "$DISTRO_VERSION" in
	debian@8)
		fixMaxOpenFiles || true
		;;
esac
setPHPVersionVariables
setPHPPreinstalledModules
case "$PHP_MAJMIN_VERSION" in
	505 | 506 | 700 | 701 | 702 | 703 | 704 | 800 | 801 | 802) ;;
	*)
		printf "### ERROR: Unsupported PHP version: %s.%s ###\n" $((PHP_MAJMIN_VERSION / 100)) $((PHP_MAJMIN_VERSION % 100))
		;;
esac
UNNEEDED_PACKAGE_LINKS=''
processCommandArguments "$@"

if test -z "$PHP_MODULES_TO_INSTALL"; then
	exit 0
fi

if stringInList @fix_letsencrypt "$PHP_MODULES_TO_INSTALL"; then
	# This must be the very first thing we do
	fixLetsEncrypt
fi

sortModulesToInstall

docker-php-source extract
BUNDLED_MODULES="$(find /usr/src/php/ext -mindepth 2 -maxdepth 2 -type f -name 'config.m4' | xargs -n1 dirname | xargs -n1 basename | xargs)"
configureInstaller

buildRequiredPackageLists $PHP_MODULES_TO_INSTALL
if test -n "$PACKAGES_PERSISTENT_PRE"; then
	markPreinstalledPackagesAsUsed
fi
if test -n "$PACKAGES_PERSISTENT_NEW$PACKAGES_VOLATILE"; then
	installRequiredPackages
fi
if test "$PHP_MODULES_TO_INSTALL" != '@composer'; then
	setTargetTriplet
fi
if test $USE_PICKLE -gt 1; then
	buildPickle
fi
for PHP_MODULE_TO_INSTALL in $PHP_MODULES_TO_INSTALL; do
	case "$PHP_MODULE_TO_INSTALL" in
		@fix_letsencrypt)
			# Already done: it must be the first thing we do
			;;
		@composer)
			installComposer
			;;
		*)
			if stringInList "$PHP_MODULE_TO_INSTALL" "$BUNDLED_MODULES"; then
				installBundledModule "$PHP_MODULE_TO_INSTALL"
			else
				installRemoteModule "$PHP_MODULE_TO_INSTALL"
			fi
			;;
	esac
done
cleanup
