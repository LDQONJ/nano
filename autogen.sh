#!/bin/sh
set -e
# Generate configure & friends for GIT users.

gnulib_url="https://github.com/coreutils/gnulib.git"
gnulib_fallback_url="https://git.savannah.gnu.org/git/gnulib.git"
gnulib_hash="d89ea630c1318a1a595aa3aff169586f4e626274"

modules="
	canonicalize-lgpl
	futimens
	getdelim
	getline
	getopt-gnu
	glob
	isblank
	iswblank
	lstat
	mkstemps
	nl_langinfo
	regex
	rewinddir
	sigaction
	snprintf-posix
	stdarg-h
	strcase
	strcasestr-simple
	strnlen
	sys_wait
	vsnprintf-posix
	wchar-h
	wctype-h
	wcwidth
	windows-stat-timespec
"

# Make sure the local gnulib git repo is up-to-date.
if [ ! -d "gnulib" ]; then
	git clone --depth=2222 "${gnulib_url}" gnulib || git clone --depth=2222 "${gnulib_fallback_url}" gnulib
fi
cd gnulib >/dev/null || exit 1
curr_hash=$(git log -1 --format=%H)
if [ "${gnulib_hash}" != "${curr_hash}" ]; then
	echo "Checking out ${gnulib_hash}..."
	git checkout --force "${gnulib_hash}" 2>/dev/null || {
		git fetch --depth=2222 origin "${gnulib_hash}" 2>/dev/null || git pull
		git checkout --force "${gnulib_hash}"
	}
fi
cd .. >/dev/null || exit 1

rm -rf lib
echo "Gnulib-tool..."
./gnulib/gnulib-tool --import ${modules}
echo

echo "Autoreconf..."
autoreconf --install --force
echo "Done."
