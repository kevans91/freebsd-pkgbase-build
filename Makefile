# pkgbase Build Script

PREFIX?=/usr/local
OBJTOP?=/usr/obj
SRCTOP?=/usr/src
PKGTOP?=${PREFIX}/pkgbase
CONFTOP?=${.CURDIR}/files
SRCCONF=${SRCTOP}
MAKE_ARGS+=NO_INSTALLEXTRAKERNELS=no
KERNCONF?=GENERIC

# Only pull files from ${CONFTOP} with this prefix
CONFPREFIX=conf-

MACHINE!=hostname | cut -d"." -f"1"
ARCH!=uname -p
NUMCPU!=sysctl -n hw.ncpu

BUILDARCH?=${ARCH}
BUILDTAG?=${ARCH}
MAKE_JOBS_NUMBER?=${NUMCPU}

TAGDATE!=date +'%Y%m%d-%H%M%S'
TAGNAME="build/${BUILDTAG}/${TAGDATE}"

CONFPATTERN=${CONFPREFIX}(.+)
CONFIGFILES!=find -E ${CONFTOP} -regex "${CONFTOP}/${CONFPATTERN}"
CONFIGS=${CONFIGFILES:C/${CONFTOP}\///:C/${CONFPATTERN}/\1/}
CONFDEST=${SRCTOP}/sys/${BUILDARCH}/conf

LN=ln
FIND=find
MKDIR=mkdir -p
SETENV=env

KERNCONF+=${CONFIGS}
MAKE_ARGS+=KERNCONF="${KERNCONF:C/^\w*(.*)/\\1/}"
MAKE_ARGS+=-j${MAKE_JOBS_NUMBER}

tag:
	@if [ "${NOTAG}" == "" ]; then \
		(cd ${SRCTOP} && git tag "${TAGNAME}") \
	fi

config:
	@for _cfg in ${CONFIGS}; do \
		if [ ! -e "${CONFDEST}/$${_cfg}" ]; then \
			${LN} -s "${CONFTOP}/${CONFPREFIX}$${_cfg}" "${CONFDEST}/$${_cfg}"; \
		fi; \
	done

build-world:	config
	(cd ${SRCTOP} && ${SETENV} ${MAKE_ENV} make ${MAKE_ARGS} buildworld)

build-kernel:	config
	(cd ${SRCTOP} && ${SETENV} ${MAKE_ENV} make ${MAKE_ARGS} buildkernel)

build:		tag config build-world build-kernel

packages:	build
	(cd ${SRCTOP} && ${SETENV} ${MAKE_ENV} make ${MAKE_ARGS} packages)
	@if [ ! -d ${PKGTOP} ]; then \
		${MKDIR} ${PKGTOP}; \
	fi;

	@if [ ! -e ${PKGTOP}/repo ]; then \
		${LN} -s ${OBJTOP}/${SRCTOP}/repo ${PKGTOP}/repo; \
	fi;
