# pkgbase Build Script

.sinclude "${.CURDIR}/Makefile.local"

PREFIX?=	/usr/local
OBJTOP?=	/usr/obj
SRCTOP?=	/usr/src
PKGTOP?=	${PREFIX}/pkgbase
CONFTOP?=	${.CURDIR}/files
WRKDIR?=	${.CURDIR}/work
MAKE_ARGS+=	${PKGBASE_MAKE_ARGS}
MAKE_ARGS+=	NO_INSTALLEXTRAKERNELS=no
KERNCONF?=	GENERIC

# Only pull files from ${CONFTOP} with this prefix
CONFPREFIX?=	conf-
IGNOREEXPR?=

ARCH_DIRS!=	find ${CONFTOP} -type d ! -path ${CONFTOP} | sed -e 's!${CONFTOP}/!!g' -e 's!${CONFTOP}!!g'

MACHINE!=	make -C ${SRCTOP} -V MACHINE
MACHINE_ARCH!=	make -C ${SRCTOP} -V MACHINE_ARCH
NUMCPU!=	sysctl -n hw.ncpu
NUMTHREADS!=	echo $$(( ${NUMCPU} + ${NUMCPU} ))

BUILDARCHS?=		${ARCH_DIRS}
MAKE_JOBS_NUMBER?=	${NUMTHREADS}
MAKE_ARGS+=		-j${MAKE_JOBS_NUMBER}

TAGDATE!=		date +'%Y%m%d-%H%M%S'

LN=			ln
FIND=			find
DIFF=			diff -q
MKDIR=			mkdir -p
RM=			rm -f
CHFLAGS=		chflags -R
SETENV=			env
ECHO_CMD=		@echo
ECHO_TIME=		${ECHO_CMD} `date +"%s"`
WRKDIR_MAKE=		[ -e "${WRKDIR}" ] || ${MKDIR} "${WRKDIR}"

ALL_REPOS+=		${OBJTOP}${SRCTOP}/repo

CONFPATTERN=${CONFPREFIX}(.+)

.for _arch in ${ARCH_DIRS}
.if ${BUILDARCHS:M${_arch}}
BUILDARCH+=		${_arch}
TARGET_${_arch}=	${_arch:C/\..+//}
TARGET_ARCH_${_arch}=	${_arch:C/.+\.//}
BUILDTAG_${_arch}=	${TARGET_ARCH_${_arch}}
ARCHTOP_${_arch}=	${CONFTOP}/${_arch}

.if ${IGNOREEXPR} != ""
CONFIGFILES_${_arch}!=	find -E ${ARCHTOP_${_arch}} -regex "${ARCHTOP_${_arch}}/${CONFPATTERN}" ! -regex ${IGNOREEXPR}
.else
CONFIGFILES_${_arch}!=	find -E ${ARCHTOP_${_arch}} -regex "${ARCHTOP_${_arch}}/${CONFPATTERN}"
.endif

CONFIGS_${_arch}=	${CONFIGFILES_${_arch}:C/${ARCHTOP_${_arch}}\///:C/${CONFPATTERN}/\1/}
CONFDEST_${_arch}=	${SRCTOP}/sys/${TARGET_${_arch}}/conf
MAKE_ARGS_${_arch}+=	${MAKE_ARGS} KERNCONF="${KERNCONF} ${CONFIGS_${_arch}:C/^\w*(.*)/\\1/}"

.if ${MACHINE} != ${TARGET_${_arch}} && ${MACHINE_ARCH} != ${TARGET_ARCH_${_arch}}
MAKE_ARGS_${_arch}+=	TARGET=${TARGET_${_arch}} TARGET_ARCH=${TARGET_ARCH_${_arch}}
OBJDIRPREFIX_${_arch}=	${OBJTOP}/${_arch}
.else
OBJDIRPREFIX_${_arch}=	${OBJTOP}
.endif

tag-${_arch}:
	@if [ "${NOTAG}" == "" ]; then \
		(cd ${SRCTOP} && git tag "build/${BUILDTAG_${_arch}}/${TAGDATE}"); \
	fi

config-${_arch}:
	for _cfgfile in `${FIND} "${CONFDEST_${_arch}}/" -lname "${CONFTOP}/*"`; do \
		if [ ! -e "$${_cfgfile}" ]; then \
			${RM} "$${_cfgfile}"; \
		fi; \
	done;
	@for _cfg in ${CONFIGS_${_arch}}; do \
		if [ -e "${CONFDEST_${_arch}}/$${_cfg}" ]; then \
			${DIFF} "${CONFDEST_${_arch}}/$${_cfg}" "${ARCHTOP_${_arch}}/${CONFPREFIX}$${_cfg}"; \
			if [ $$? -ne 0 ]; then \
				${RM} "${CONFDEST_${_arch}}/$${_cfg}"; \
			fi; \
		fi; \
		if [ ! -e "${CONFDEST_${_arch}}/$${_cfg}" ]; then \
			${LN} -s "${ARCHTOP_${_arch}}/${CONFPREFIX}$${_cfg}" "${CONFDEST_${_arch}}/$${_cfg}"; \
		fi; \
	done;

build-world-${_arch}:
	@(cd ${SRCTOP} && ${SETENV} ${MAKE_ENV} make ${MAKE_ARGS_${_arch}} buildworld)

build-kernel-${_arch}:
	@(cd ${SRCTOP} && ${SETENV} ${MAKE_ENV} make ${MAKE_ARGS_${_arch}} buildkernel)

packages-${_arch}:
	@(cd ${SRCTOP} && ${SETENV} ${MAKE_ENV} make ${MAKE_ARGS_${_arch}} packages)

clean-${_arch}:
	if [ -e ${OBJDIRPREFIX_${_arch}} ]; then \
		${CHFLAGS} noschg ${OBJDIRPREFIX_${_arch}}; \
		${RM} -r ${OBJDIRPREFIX_${_arch}}; \
	fi;

TAG_TGTS+=		tag-${_arch}
CONFIG_TGTS+=		config-${_arch}
BUILDWORLD_TGTS+=	build-world-${_arch}
BUILDKERNEL_TGTS+=	build-kernel-${_arch}
PACKAGE_TGTS+=		packages-${_arch}
CLEAN_TGTS+=		clean-${_arch}
.endif
.endfor

tag:	${TAG_TGTS}

config:
	${WRKDIR_MAKE}
	${ECHO_CMD} "== PHASE: Install Config =="
	${ECHO_TIME} > ${WRKDIR}/config.start
	@for tgt in ${CONFIG_TGTS}; do \
		echo $${tgt}; \
		(cd ${.CURDIR} && make $${tgt}); \
	done
	${ECHO_TIME} > ${WRKDIR}/config.end
	${ECHO_CMD} "== END PHASE: Install Config (" $$((`cat ${WRKDIR}/config.end` - `cat ${WRKDIR}/config.start`)) "s) =="

build-world:	config
	${ECHO_CMD} "== PHASE: Build World =="
	${ECHO_TIME} > ${WRKDIR}/build-world.start
	@for tgt in ${BUILDWORLD_TGTS}; do \
		echo $${tgt}; \
		(cd ${.CURDIR} && make $${tgt}); \
	done
	${ECHO_TIME} > ${WRKDIR}/build-world.end
	${ECHO_CMD} "== END PHASE: Build World (" $$((`cat ${WRKDIR}/build-world.end` - `cat ${WRKDIR}/build-world.start`)) "s) =="

build-kernel:	config
	${ECHO_CMD} "== PHASE: Build Kernel =="
	${ECHO_TIME} > ${WRKDIR}/build-kernel.start
	@for tgt in ${BUILDKERNEL_TGTS}; do \
		echo $${tgt}; \
		(cd ${.CURDIR} && make $${tgt}); \
	done
	${ECHO_TIME} > ${WRKDIR}/build-kernel.end
	${ECHO_CMD} "== END PHASE: Build Kernel (" $$((`cat ${WRKDIR}/build-kernel.end` - `cat ${WRKDIR}/build-kernel.start`)) "s) =="

build:		tag config build-world build-kernel

packages:	build
	${ECHO_CMD} "== PHASE: Install Packages =="
	${ECHO_TIME} > ${WRKDIR}/packages.start
	@for tgt in ${PACKAGE_TGTS}; do \
		echo $${tgt}; \
		(cd ${.CURDIR} && make $${tgt}); \
	done

		# Make sure the repo dir exists
	@if [ ! -d ${PKGTOP}/repo ]; then \
		${MKDIR} ${PKGTOP}/repo
	fi;

		# Symlink in the different ABI repositories
	@for repodir in ${ALL_REPOS}; do \
		for abidir in ${FIND} $${repodir} -type d -d 1; do \
			if [ ! -e ${PKGTOP}/repo/`basename $${abidir}` ]; then \
				${LN} -s $${abidir} ${PKGTOP}/repo; \
			fi; \
		done; \
	done;

	${ECHO_TIME} > ${WRKDIR}/packages.end
	${ECHO_CMD} "== END PHASE: Install Packages (" $$((`cat ${WRKDIR}/packages.end` - `cat ${WRKDIR}/packages.start`)) "s) =="

clean:
	${RM} -r ${WRKDIR}

cleanall:
	@for tgt in ${CLEAN_TGTS}; do \
		echo $${tgt}; \
		(cd ${.CURDIR} && make $${tgt}); \
	done

	(cd ${SRCTOP} && \
		${SETENV} ${MAKE_ENV} make ${MAKE_ARGS} cleandir && \
		${SETENV} ${MAKE_ENV} make ${MAKE_ARGS} cleandir)
