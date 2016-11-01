# pkgbase Build Script

PREFIX?=	/usr/local
OBJTOP?=	/usr/obj
SRCTOP?=	/usr/src
PKGTOP?=	${PREFIX}/pkgbase
CONFTOP?=	${.CURDIR}/files
WRKDIR?=	${.CURDIR}/work
MAKE_ARGS+=	NO_INSTALLEXTRAKERNELS=no
KERNCONF?=	GENERIC

# Only pull files from ${CONFTOP} with this prefix
CONFPREFIX?=	conf-
IGNOREEXPR?=

MACHINE!=	hostname | cut -d"." -f"1"
ARCH!=		uname -p
NUMCPU!=	sysctl -n hw.ncpu

#BUILDARCH?=		${ARCH}
BUILDARCH=		#
BUILDTAG?=		${ARCH}
MAKE_JOBS_NUMBER?=	${NUMCPU}

TAGDATE!=		date +'%Y%m%d-%H%M%S'
TAGNAME=		"build/${BUILDTAG}/${TAGDATE}"

ARCH_DIRS!=		find ${CONFTOP} -type d ! -path ${CONFTOP} | sed -e 's!${CONFTOP}/!!g' -e 's!${CONFTOP}!!g'

CONFPATTERN=${CONFPREFIX}(.+)
.for _arch in ${ARCH_DIRS}
BUILDARCH+=		${_arch}
ARCHTOP_${_arch}=	${CONFTOP}/${_arch}

.if ${IGNOREEXPR} != ""
CONFIGFILES_${_arch}!=	find -E ${ARCHTOP_${_arch}} -regex "${ARCHTOP_${_arch}}/${CONFPATTERN}" ! -regex ${IGNOREEXPR}
.else
CONFIGFILES_${_arch}!=	find -E ${ARCHTOP_${_arch}} -regex "${ARCHTOP_${_arch}}/${CONFPATTERN}"
.endif

CONFIGS_${_arch}=	${CONFIGFILES_${_arch}:C/${ARCHTOP_${_arch}}\///:C/${CONFPATTERN}/\1/}
CONFDEST_${_arch}=	${SRCTOP}/sys/${_arch:C/\..+//}/conf
.endfor


LN=				ln
FIND=			find
MKDIR=			mkdir -p
SETENV=			env
ECHO_CMD=		@echo
ECHO_TIME=		${ECHO_CMD} `date +"%s"`
WRKDIR_MAKE=	[ -e "${WRKDIR}" ] || ${MKDIR} "${WRKDIR}"

KERNCONF+=		${CONFIGS}
MAKE_ARGS+=		KERNCONF="${KERNCONF:C/^\w*(.*)/\\1/}"
MAKE_ARGS+=		-j${MAKE_JOBS_NUMBER}

tag:
	@if [ "${NOTAG}" == "" ]; then \
		(cd ${SRCTOP} && git tag "${TAGNAME}") \
	fi

config:
	${WRKDIR_MAKE}
	${ECHO_CMD} "== PHASE: Install Config =="
	${ECHO_TIME} > ${WRKDIR}/config.start
	@for _cfg in ${CONFIGS}; do \
		if [ ! -e "${CONFDEST}/$${_cfg}" ]; then \
			${LN} -s "${CONFTOP}/${CONFPREFIX}$${_cfg}" "${CONFDEST}/$${_cfg}"; \
		fi; \
	done
	${ECHO_TIME} > ${WRKDIR}/config.end
	${ECHO_CMD} "== END PHASE: Install Config (" $$((`cat ${WRKDIR}/config.end` - `cat ${WRKDIR}/config.start`)) "s) =="

build-world:	config
	${ECHO_CMD} "== PHASE: Build World =="
	${ECHO_TIME} > ${WRKDIR}/build-world.start
	@(cd ${SRCTOP} && ${SETENV} ${MAKE_ENV} make ${MAKE_ARGS} buildworld)
	${ECHO_TIME} > ${WRKDIR}/build-world.end
	${ECHO_CMD} "== END PHASE: Build World (" $$((`cat ${WRKDIR}/build-word.end` - `cat ${WRKDIR}/build-world.start`)) "s) =="

build-kernel:	config
	${ECHO_CMD} "== PHASE: Build Kernel =="
	${ECHO_TIME} > ${WRKDIR}/build-kernel.start
	@(cd ${SRCTOP} && ${SETENV} ${MAKE_ENV} make ${MAKE_ARGS} buildkernel)
	${ECHO_TIME} > ${WRKDIR}/build-kernel.end
	${ECHO_CMD} "== END PHASE: Build Kernel (" $$((`cat ${WRKDIR}/build-kernel.end` - `cat ${WRKDIR}/build-kernel.start`)) "s) =="

build:		tag config build-world build-kernel

packages:	build
	${ECHO_CMD} "== PHASE: Install Packages =="
	${ECHO_TIME} > ${WRKDIR}/packages.start
	@(cd ${SRCTOP} && ${SETENV} ${MAKE_ENV} make ${MAKE_ARGS} packages)
	@if [ ! -d ${PKGTOP} ]; then \
		${MKDIR} ${PKGTOP}; \
	fi;

	@if [ ! -e ${PKGTOP}/repo ]; then \
		${LN} -s ${OBJTOP}/${SRCTOP}/repo ${PKGTOP}/repo; \
	fi;

	${ECHO_TIME} > ${WRKDIR}/packages.end
	${ECHO_CMD} "== END PHASE: Install Packages (" $$((`cat ${WRKDIR}/packages.end` - `cat ${WRKDIR}/packages.start`)) "s) =="

clean:
	${RM} -r ${WRKDIR}
