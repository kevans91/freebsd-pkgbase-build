# Goal
My goal here is to allow multi-arch, multi-src builds. Ideally, one could:

1. Create pkgbase repos for all arch, all src
2. Create pkgbase repos for all arch, some src
3. Create pkgbase repos for some arch, all src
4. Create pkgbase repos for some arch, some src

Ideally, we could support everything without allowing any conflicts (read: multiple repos, duplicate ABI)

# Approach
My approach is looking like the following:

1. Specify, in SRCTOP, one or more src repos
2. Allow setting of archs to build for each SRCTOP, possibly through :tags? (/usr/src:amd64.amd64,arm64.aarch64 ...) If not specified, assume all provided ARCHs that may be built in that repo and that we have a config for
3. For each SRCTOP, document roughly ABI used (make -C ${SRCTOP}/release -V REVISION) -- decide if we have conflicting revision/arch
4. For each ARCH, for each SRCTOP it is enabled on, generate a build target to build world/kernel/packages for this combination
5. In the outer loop of #1, add build targets that we call from the top-level that recursively calls all the SRCTOP targets generated in #4
6. ??
7. Profit
