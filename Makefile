# pkgbase Build Script

.sinclude "${.CURDIR}/Makefile.local"

PREFIX?=	/usr/local
PB_OBJTOP?=	/usr/obj
PB_SRCTOP?=	/usr/src
PKGTOP?=	${PREFIX}/pkgbase
CONFTOP?=	${.CURDIR}/files
WRKDIR?=	${.CURDIR}/work

# Local SRCCONF
.if empty(SRC_CONF)
_SRC_CONF=	${CONFTOP}/src.conf
_SRC_CONF_EXISTS!=	[ -f ${_SRC_CONF} ] && echo ${_SRC_CONF} || echo ""

.if !empty(_SRC_CONF_EXISTS)
SRC_CONF=	${_SRC_CONF}
.endif
.endif

.if empty(SRC_ENV_CONF)
_SRC_ENV_CONF=	${CONFTOP}/src-env.conf
_SRC_ENV_CONF_EXISTS!=	[ -f ${_SRC_ENV_CONF} ] && echo ${_SRC_ENV_CONF} || echo ""

.if !empty(_SRC_ENV_CONF_EXISTS)
SRC_ENV_CONF=	${_SRC_ENV_CONF}
.endif
.endif

# Intentionally mis-named and normalized
SRC_CONF?=	/dev/null
SRC_ENV_CONF?=	/dev/null
MAKE_CONF?=	/dev/null
MAKE_ARGS+=	${PKGBASE_MAKE_ARGS}
MAKE_ARGS+=	NO_INSTALLEXTRAKERNELS=no
MAKE_ARGS+=	SRCCONF=${SRC_CONF} _SRC_ENV_CONF=${SRC_ENV_CONF} __MAKE_CONF=${MAKE_CONF}
KERNCONF?=	GENERIC

.if ${.MAKEFLAGS:M-s} == "-s"
MAKE_ARGS+=	-s
.endif

# Only pull files from ${CONFTOP} with this prefix
CONFPREFIX?=	conf-
IGNOREEXPR?=

# We'll populate this later if this didn't pick up everything
ARCH_DIRS!=	find ${CONFTOP} -type d ! -path ${CONFTOP} | sed -e 's!${CONFTOP}/!!g' -e 's!${CONFTOP}!!g'

NUMCPU!=	sysctl -n hw.ncpu
NUMTHREADS!=	echo $$(( ${NUMCPU} + ${NUMCPU} ))

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
ECHO_TIME=		@echo `date +"%s"`
WRKDIR_MAKE=		[ -e "${WRKDIR}" ] || ${MKDIR} "${WRKDIR}"

CONFPATTERN=${CONFPREFIX}(.+)
ALL_SRCARCH:=		# For validation
BUILDARCHS:=		# For later iteration -- all architectures to build

.for src in ${PB_SRCTOP}
_src:=			${src:C/\:.*//}
ALL_PB_SRCTOP:=		${ALL_PB_SRCTOP} ${_src}
${_src}_ARCHS:=		${src:C/^[^\:]*(\:|\$)//:S/,/ /g}
${_src}_ALL_ARCHS!=	make -C ${_src} targets | grep -e '^ ' | sed -e 's/    //' -e's|/|.|'
_revision!=		make -C ${_src}/release -V REVISION
${_src}_REVISION:=	${_revision:C/\..*//}
ALL_REPOS:=		${ALL_REPOS} ${PB_OBJTOP}${_src}/repo

.if empty(${_src}_ARCHS)
.	if empty(ARCH_DIRS)
.error "No idea what archs we are are packaging for... please create archdirs in files/, or specify in PB_SRCTOP what archs apply."
.	endif
${_src}_ARCHS+=		${ARCH_DIRS}
.else
# See if we need to populate ARCH_DIRS
.	for _arch in ${${_src}_ARCHS}
.		if empty(${ARCH_DIRS:M${_arch}:L})
ARCH_DIRS+=	${_arch}
.		endif
.	endfor
.endif

# Validate _ARCHS vs. _ALL_ARCHS and make sure we don't have multiply defined osrel+arch combos
# The latter would result in ABI collision
.for _arch in ${${_src}_ARCHS}
.if empty(${_src}_ALL_ARCHS:M${_arch})
.if VERBOSE
.warning ${_arch} not valid in ${_src} context
.endif
${_src}_ARCHS:=		${${_src}_ARCHS:C/${_arch}//}
.else
_srcarch:=		${${_src}_REVISION}${_arch}
.if !empty(ALL_SRCARCH:M${_srcarch})
.error Multiply defined version/arch combinations for ${_arch} (used: ${ALL_SRCARCH})
.else
ALL_SRCARCH:=		${ALL_SRCARCH} ${_srcarch}
PB_SRCTOP_${_arch}:=	${PB_SRCTOP_${_arch}} ${_src}

.if empty(BUILDARCHS:M${_arch})
BUILDARCHS:=		${BUILDARCHS} ${_arch}
.endif
.endif
.endif
.endfor

.if empty(MACHINE)
MACHINE!=	make -C ${_src} -V MACHINE
.endif

.if empty(MACHINE_ARCH)
MACHINE_ARCH!=	make -C ${_src} -V MACHINE_ARCH
.endif
.endfor

.for _arch in ${ARCH_DIRS}
# We now construct BUILDARCHS from PB_SRCTOP information... ugh. It's valid, though
.if !empty(BUILDARCHS:M${_arch})
BUILDARCH+=		${_arch}
TARGET_${_arch}=	${_arch:C/\..+//}
TARGET_ARCH_${_arch}=	${_arch:C/.+\.//}
BUILDTAG_${_arch}=	${TARGET_ARCH_${_arch}}
ARCHTOP_${_arch}=	${CONFTOP}/${_arch}
ARCHTOP_${_arch}_EXISTS!=	([ -e ${ARCHTOP_${_arch}} ] && echo "YES") || echo "NO"

.if ${ARCHTOP_${_arch}_EXISTS:MYES}
.	if !empty(IGNOREEXPR)
CONFIGFILES_${_arch}!=	find -E ${ARCHTOP_${_arch}} -regex "${ARCHTOP_${_arch}}/${CONFPATTERN}" ! -regex ${IGNOREEXPR}
.	else
CONFIGFILES_${_arch}!=	find -E ${ARCHTOP_${_arch}} -regex "${ARCHTOP_${_arch}}/${CONFPATTERN}"
.	endif
.else
CONFIGFILES_${_arch}=
.endif

CONFIGS_${_arch}=	${CONFIGFILES_${_arch}:C/${ARCHTOP_${_arch}}\///:C/${CONFPATTERN}/\1/}
.for _srctop in ${PB_SRCTOP_${_arch}}
ALL_CONFDEST_${_arch}:=	${ALL_CONFDEST_${_arch}} ${_srctop}/sys/${TARGET_${_arch}}/conf
.endfor

ALL_KERNCONFS_${_arch}=	${KERNCONF} ${CONFIGS_${_arch}}
MAKE_ARGS_${_arch}+=	${MAKE_ARGS} KERNCONF="${ALL_KERNCONFS_${_arch}}"

.if ${MACHINE} != ${TARGET_${_arch}} && ${MACHINE_ARCH} != ${TARGET_ARCH_${_arch}}
MAKE_ARGS_${_arch}+=	TARGET=${TARGET_${_arch}} TARGET_ARCH=${TARGET_ARCH_${_arch}}
.endif

	# XXX kevans91: DO NOT ADD SOURCE TARGETS FOR ANY OF THESE ARCH-SPECIFIC
	# TARGETS! make(1) is re-invoked to execute each of these targets,
	# adding sources can and will cause bad things to happen. I can probably
	# find a better way to manage this, but for the time being -- I don't really
	# care to.

	# Tag the repository for this arch, unless we're not tagging
tag-${_arch}:
	@if [ "${NOTAG}" == "" ] && [ `which git` ]; then \
		for _srctop in ${PB_SRCTOP_${_arch}}; do \
			if [ -e $${_srctop}/.git ]; then \
				env GIT_DIR=$${_srctop}/.git git tag "build/${BUILDTAG_${_arch}}/${TAGDATE}"; \
			fi; \
		done; \
	fi

	# Clean up any kernel configs that have disappeared. Ensure that we have
	# symlinks for all of the configurations we're using. If there's a difference,
	# remove the in-tree kernconf and re-symlink it Otherwise, leave it be.
config-${_arch}:
	@for _cfgdest in ${ALL_CONFDEST_${_arch}}; do \
		for _cfgfile in `${FIND} "$${_cfgdest}/" -lname "${CONFTOP}/*"`; do \
			if [ ! -e "$${_cfgfile}" ]; then \
				${RM} "$${_cfgfile}"; \
			fi; \
		done; \
	done;

	@for _cfg in ${CONFIGS_${_arch}}; do \
		for _cfgdest in ${ALL_CONFDEST_${_arch}}; do \
			if [ -e "$${_cfgdest}/$${_cfg}" ]; then \
				${DIFF} "$${_cfgdest}/$${_cfg}" "${ARCHTOP_${_arch}}/${CONFPREFIX}$${_cfg}"; \
				if [ $$? -ne 0 ]; then \
					${RM} "$${_cfgdest}/$${_cfg}"; \
				fi; \
			fi; \
			if [ ! -e "$${_cfgdest}/$${_cfg}" ]; then \
				${LN} -s "${ARCHTOP_${_arch}}/${CONFPREFIX}$${_cfg}" "$${_cfgdest}/$${_cfg}"; \
			fi; \
		done; \
	done;

WLOG=	${WRKDIR}/build-world-${_arch}.log
KLOG=	${WRKDIR}/build-kernel-${_arch}.log
PLOG=	${WRKDIR}/packages-${_arch}.log

	# Build world for this architecture
# Major subshell hack to get equivalent of bash's pipefail was stolen from:
# https://unix.stackexchange.com/a/70675 (user: lesmana)
build-world-${_arch}:
	@${RM} ${WLOG};
	@for _srctop in ${PB_SRCTOP_${_arch}}; do \
		((((${SETENV} ${MAKE_ENV} make -C $${_srctop} ${MAKE_ARGS_${_arch}} \
		    buildworld; echo $$? >&3) | tee ${WLOG} >&4) 3>&1) | \
		    (read xs; exit $$xs)) 4>&1; \
		ret=$$?; \
		if [ "$$ret" -ne 0 ]; then \
			exit $$ret; \
		fi; \
	done;

	# Build kernel for this architecture
build-kernel-${_arch}:
	@${RM} ${KLOG};
	@for _srctop in ${PB_SRCTOP_${_arch}}; do \
		((((${SETENV} ${MAKE_ENV} make -C $${_srctop} ${MAKE_ARGS_${_arch}} \
		    buildkernel; echo $$? >&3) | tee ${KLOG} >&4) 3>&1) | \
		    (read xs; exit $$xs)) 4>&1; \
		ret=$$?; \
		if [ "$$ret" -ne 0 ]; then \
			exit $$ret; \
		fi; \
	done;

	# Build packages for this architecture
	# This is needed because the actual OBJDIR is based on TARGET/TARGET_ARCH
packages-${_arch}:
	@${RM} ${PLOG};
	@for _srctop in ${PB_SRCTOP_${_arch}}; do \
		((((${SETENV} ${MAKE_ENV} make -C $${_srctop} ${MAKE_ARGS_${_arch}} \
		    packages; echo $$? >&3) | tee ${PLOG} >&4) 3>&1) | \
		    (read xs; exit $$xs)) 4>&1 ; \
		ret=$$?; \
		if [ "$$ret" -ne 0 ]; then \
			exit $$ret; \
		fi; \
	done

TAG_TGTS+=		tag-${_arch}
CONFIG_TGTS+=		config-${_arch}
BUILDWORLD_TGTS+=	build-world-${_arch}
BUILDKERNEL_TGTS+=	build-kernel-${_arch}
PACKAGE_TGTS+=		packages-${_arch}
.endif
.endfor

tag:	${TAG_TGTS}

	# From here out, the targets are all of a pretty straightforward recipe:
	# * A loop to run make(1) for all of the architecture-specific targets
	# * A wrapper to do profiling for each target's full run
config:
	${WRKDIR_MAKE}
	@echo "== PHASE: Install Config =="
	${ECHO_TIME} > ${WRKDIR}/config.start
	@for tgt in ${CONFIG_TGTS}; do \
		make -C ${.CURDIR} $${tgt}; \
	done
	${ECHO_TIME} > ${WRKDIR}/config.end
	@echo "== END PHASE: Install Config (" $$((`cat ${WRKDIR}/config.end` - `cat ${WRKDIR}/config.start`)) "s) =="

build-world:	config
	@echo "== PHASE: Build World =="
	${ECHO_TIME} > ${WRKDIR}/build-world.start
	@for tgt in ${BUILDWORLD_TGTS}; do \
		make -C ${.CURDIR} $${tgt}; \
	done
	${ECHO_TIME} > ${WRKDIR}/build-world.end
	@echo "== END PHASE: Build World (" $$((`cat ${WRKDIR}/build-world.end` - `cat ${WRKDIR}/build-world.start`)) "s) =="

build-kernel:	config
	@echo "== PHASE: Build Kernel =="
	${ECHO_TIME} > ${WRKDIR}/build-kernel.start
	@for tgt in ${BUILDKERNEL_TGTS}; do \
		make -C ${.CURDIR} $${tgt}; \
	done
	${ECHO_TIME} > ${WRKDIR}/build-kernel.end
	@echo "== END PHASE: Build Kernel (" $$((`cat ${WRKDIR}/build-kernel.end` - `cat ${WRKDIR}/build-kernel.start`)) "s) =="

build:		tag config build-world build-kernel

	# Packages is the exception. This one has to do some extra
	# work after the packages are all built, because our build
	# system actually generates multiple repos based on the
	# TARGET/TARGET_ARCH
	# This leads to us needing an overarching pkgbase repo that
	# actually symlinks individual ABI directories into it, to
	# easily support multiarch pkgbase builds
packages:	build
	@echo "== PHASE: Install Packages =="
	${ECHO_TIME} > ${WRKDIR}/packages.start
	@for tgt in ${PACKAGE_TGTS}; do \
		make -C ${.CURDIR} $${tgt}; \
	done

		# Make sure the repo dir exists
	@if [ ! -d ${PKGTOP}/repo ]; then \
		${MKDIR} ${PKGTOP}/repo; \
	fi;

		# Symlink in the different ABI repositories
	for repodir in ${ALL_REPOS}; do \
		for abidir in `${FIND} $${repodir} -type d -d 1`; do \
			if [ ! -e ${PKGTOP}/repo/`basename $${abidir}` ]; then \
				${LN} -s $${abidir} ${PKGTOP}/repo; \
			fi; \
		done; \
	done;

	${ECHO_TIME} > ${WRKDIR}/packages.end
	@echo "== END PHASE: Install Packages (" $$((`cat ${WRKDIR}/packages.end` - `cat ${WRKDIR}/packages.start`)) "s) =="

	# This is really a target for cleaning 'local' things
clean:
	${RM} -r ${WRKDIR}

	# This is for a thorough leaning of all of the different OBJDIRS
	# as well as the src tree itself.
cleanall:
	# Clean up architecture-specific stuff
	# To be clear, this is really ony OBJDIR materials
	# src stuff gets cleaned up inthe 'cleanall' target
	if [ -e "${PB_OBJTOP}/" ]; then \
		${CHFLAGS} noschg "${PB_OBJTOP}/"; \
		${RM} -r "${PB_OBJTOP}/"; \
	fi;

	for _srctop in ${ALL_PB_SRCTOP}; do \
		${SETENV} ${MAKE_ENV} make -C $${_srctop} ${MAKE_ARGS} cleandir; \
		${SETENV} ${MAKE_ENV} make -C $${_srctop} ${MAKE_ARGS} cleandir; \
	done;
