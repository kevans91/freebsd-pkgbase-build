# What is this?
This is my Makefile for assembling pkgbase packages for my five other machines. I formalized this process into a Makefile to consolidate all of my different build scripts that I previously had on each machine, and then further developed it into a monster (emphasis on monster) that builds all of my kernel configurations on the one machine.

# How to use this
Currently,  the steps to get a build going are as follows:

1. Ensure you have a copy of the src tree at /usr/src (configurable: see `SRCTOP` in the "Configurables" section). This is assumed to be a git working directory for the purposes of tagging when a build is made.
2. Place the kernel configuration(s) that you would like to build in a ${CONFTOP}/${TARGET}.${TARGET_ARCH} (common examples: `arm.armv6`, `amd64.amd64) directory. By default, kernel configurations use a 'conf-' prefix to distinguish them from any notes or miscellaneous scripts you may want to throw in there. For every configuration, conf-$CONFNAME, in the files/ directory, this makefile will create a symlink @ src/sys/$ARCH/conf/$CONFNAME -> files/conf-$CONFNAME.
3. ??
4. Profit, or `make packages`. `make packages` will run the buildworld, buildkernel, and packages targets from the source tree. Additionally, it will put a symlink to the pkgbase repo @ $PREFIX/pkgbase/repo (also configurable: see `PKGTOP` in the "Configurables" section)

# What does this not support?
Cross-architecture building. Right now, it will only build targets on the same architecture as the host. This could be expanded later to separate the configs out by architecture, but for the time being that is out of the scope of this project. Mostly because other projects, such as crochet and freebsd-wifi-build, do these things better for a lot of use cases.

# Configurables
All of these names are subject to change in the future, because they seem like a poor choice the more I think about it. These are all configurable either in `/etc/make.conf`, a `Makefile.local` in this directory, or as environment variables.

* `PREFIX`: (Default: `/usr/local`) Same as $PREFIX elsewhere
* `OBJTOP`: (Default: `/usr/obj`) Where build output goes -- this would correspond to MAKEOBJDIRPREFIX
* `SRCTOP`: (Default: `/usr/src`) Where the src repo exists
* `CONFTOP`: (Default: `files/`) Where to find configuration files
* `PKGTOP`: (Default: `$PREFIX/pkgbase`) Parent directory for the repo symlink
* `MAKE_ENV`: (Default: none) Environment to run make in
* `MAKE_ARGS`: (Default: `NO_INSTALLEXTRAKERNELS=no -j$hw.ncpu KERNCONF="$KERNCONF"`) Args to be passed to make
* `CONFPREFIX`: (Default: `conf-`) Prefix to be used for configuration files in $CONFTOP -- this prefix will be stripped from the files when symlinks are created in src/sys/$ARCH/conf
* `IGNOREEXPR`: (Default: none) Regex to use in discarding some config files from the build
* `NOTAG`: (Default: none) If set to anything other than "", don't attempt to `git tag` this build
* `BUILDARCHS`: (Default: all in `$CONFTOP`) Architectures to build/package for
