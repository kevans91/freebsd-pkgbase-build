#!/bin/sh

# \o/!
set -o pipefail

SCRIPTDIR=$(dirname $(realpath ${0}))
subrscript=${SCRIPTDIR}/package.subr
localscript=${SCRIPTDIR}/local.sh

WORKDIR=${SCRIPTDIR}/work
SCRATCHDIR=$(mktemp -d /tmp/fpbuild.XXXXX)
trap "rm -rf ${SCRATCHDIR}" exit

. ${subrscript}
[ -f "${localscript}" ] && . ${localscript}

: ${PREFIX:=/usr/local}
: ${OBJTOP:=/usr/obj}
: ${SRCTOP:=/usr/src}
: ${PKGTOP:=${PREFIX}/pkgbase}
: ${REPODIR:=${PKGTOP}/repo}

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
: ${GIT:=$(which git)}
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

args=$(getopt s $*)
if [ $? -ne 0 ]; then
	echo "Usage: $0 [-s]"
	exit 1
fi

set -- ${args}
while :; do
	case "$1" in
		-s)
			SILENT=yes
			shift
			;;
		--)
			shift
			break
			;;
	esac
done

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
	# Stash them away for now
	echo ${archs} > ${SCRATCHDIR}/arch.$(canonicalize_srctop ${srctop})
done

builddate=$(get_tag_date)
# Start building
for srctop in ${SRCTOP}; do
	csrctop=$(canonicalize_srctop "${srctop}")
	archlist=$(cat ${SCRATCHDIR}/arch.${csrctop})
	srctop=$(path_from_srctop "${SRCTOP}")

	# First, we tag
	if [ -z "${NOTAG}" ] && [ ! -z "${GIT}" ]; then
		for arch in ${archlist}; do
			buildtag=$(get_machine_arch "${arch}")
			env GIT_DIR=${srctop}/.git git tag "build/${buildtag}/${builddate}"
		done
	fi

	# Next, we sync up this srctop's configs
	for arch in ${archlist}; do
		confdest=${srctop}/sys/$(get_machine "${arch}")/conf
		for cfgfile in $(${FIND} "${confdest}" -lname "${CONFTOP}/*"); do
			[ -e ${cfgfile} ] || ${RM} ${cfgfile}
		done

		configs=$(get_arch_configs "${arch}")
		for cfgfile in ${configs}; do
			cname=$(get_config_name "${cfgfile}")
			tgtcfg="${confdest}/${cname}"
			if [ -e "${tgtcfg}" ]; then
				${DIFF} "${tgtcfg}" "${cfgfile}" || ${RM} "${tgtcfg}"
			fi

			[ ! -e "${tgtcfg}" ] && ${LN} -s "${cfgfile}" "${tgtcfg}"
		done
	done

	# Let's start building!
	for archspec in ${archlist}; do
		WLOG=${WRKDIR}/build-world-${csrctop}-${archspec}.log
		KLOG=${WRKDIR}/build-kernel-${csrctop}-${archspec}.log
		PLOG=${WRKDIR}/packages-${csrctop}-${archspec}.log

		${RM} ${WLOG}
		${RM} ${KLOG}
		${RM} ${PLOG}

		args=$(build_make_args "${srctop}" "${archspec}")
		KERNCONF=$(_get_kernconf_set "${archspec}")
		_build_target buildworld "${WLOG}"
		_build_target buildkernel "${KLOG}"
		_build_target packages "${PLOG}"
	done
done
