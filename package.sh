#!/bin/sh

SCRIPTDIR=$(dirname $(realpath ${0}))
subrscript=${SCRIPTDIR}/package.subr
localscript=${SCRIPTDIR}/local.sh

. ${subrscript}
[ -f "${localscript}" ] && . ${localscript}

: ${PREFIX:=/usr/local}
: ${OBJTOP:=/usr/obj}
: ${SRCTOP:=/usr/src}
: ${PKGTOP:=${PREFIX}/pkgbase}

: ${CONFTOP:=${SCRIPTDIR}/files}
: ${WRKDIR:=${SCRIPTDIR}/work}

# PREFIX that files in ${CONFTOP} must have to be used
: ${CONFPREFIX:=conf-}
: ${IGNOREEXPR:=}
CONFPATTERN="${CONFPREFIX}(.+)"

: ${MAKE_CONF:=${CONFTOP}/make.conf}
: ${SRC_CONF:=${CONFTOP}/src.conf}
: ${SRC_ENV_CONF:=${CONFTOP}/src-env.conf}

: ${SILENT:=no}
: ${KERNCONF:=GENERIC}

# Utilities
: ${LN:=ln}
: ${FIND:=find}
: ${DIFF:=diff -q}
: ${MKDIR:=mkdir -p}
: ${RM:=rm -f}
: ${CHFLAGS:=chflags -R}
: ${SETENV:=env}
: ${ECHO_TIME:=echo $(date +"%s")}

[ -f ${MAKE_CONF} ] || MAKE_CONF=/dev/null
[ -f ${SRC_CONF} ] || SRC_CONF=/dev/null
[ -f ${SRC_ENV_CONF} ] || SRC_ENV_CONF=/dev/null

ARCH_DIRS=$(get_arch_dirs)

grabbing_arch_spec=0
[ -z "${ARCH_DIRS}" ] && grabbing_arch_spec=1
for srctop in ${SRCTOP}; do
	if [ ${grabbing_arch_spec} -ne 0 ]; then
		# Need an arch spec... comb through srctop
		archs=$(archs_from_srctop "${srctop}")
		if [ -z "${archs}" ]; then
			1>&2 echo "No idea what archs we are packaging for... please create archdirs in files/, or specify in SRCTOP what archs apply."
			exit 1
		fi
	else
		archs=${ARCH_DIRS}
	fi

	# We always validate archs against the current srctop
	$(validate_archs_against_srctop "${srctop}" "${archs}")
	if [ $? -ne 0 ]; then
		1>&2 echo "Invalid arch detected (in list ${archs})"
		exit 1
	fi
done

args=$(build_make_args)

