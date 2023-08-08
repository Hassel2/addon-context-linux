#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash

source $stdenv/setup;

buildPhase() {
    TAGS=${TAGS:-linux systemd one networkd}

    set -e

    UNAME_PATH=$(mktemp -d)
    BUILD_DIR=$(mktemp -d)

    _POSTIN=$(mktemp)
    _PREUN=$(mktemp)
    _POSTUN=$(mktemp)
    _POSTUP=$(mktemp)

    trap "rm -rf ${UNAME_PATH} ${BUILD_DIR} ${_POSTIN} ${_PREUN} ${_POSTUN} ${_POSTUP}" EXIT

    while IFS= read -r -d $'\0' SRC; do
        F_TAGS=${SRC##*##}
        if [ "x${SRC}" != "x${F_TAGS}" ]; then
            for F_TAG in $(echo "${F_TAGS}" | sed -e 's/\./ /g'); do
                for TAG in ${TAGS}; do
                    if [ "${F_TAG}" = "${TAG}" ]; then
                        continue 2 # tag matches, continue with next tag
                    fi
                done
                continue 2 # tags not maching, skip this file
            done
        fi

        # file matches
        DST=${SRC%##*} #strip tags
        mkdir -p "${BUILD_DIR}/$(dirname "${DST}")"
        cp "src/${SRC}" "${BUILD_DIR}/${DST}"
    done < <(cd src/ &&  find . -type f -print0)

    for F in "$@"; do
        cp -r "$F" "${BUILD_DIR}/"
    done

    find "${BUILD_DIR}/" -perm -u+r -exec chmod go+r {} \;
    find "${BUILD_DIR}/" -perm -u+x -exec chmod go+x {} \;
}

installPhase() {
    mkdir "${out}";
    cp -rT "${BUILD_DIR}" "${out}"
}

postInstall() {
    SERVICES=${SERVICES:-one-context-local one-context-online one-context}
    TIMERS=${TIMERS:-one-context-reconfigure.timer}

    rm -f /etc/udev/rules.d/70-persistent-cd.rules
    rm -f /etc/udev/rules.d/70-persistent-net.rules

    # Reload udev rules
    udevadm control --reload >/dev/null 2>&1 || :


    ### Enable services ########################################

    if which systemctl >/dev/null 2>&1 && \
        [ -d /etc/systemd ] && \
        [ -f ${out}/usr/lib/systemd/system/one-context.service ];
    then
        systemctl daemon-reload >/dev/null 2>&1 || :

        for S in ${SERVICES} ${TIMERS}; do
            systemctl enable "${S}" >/dev/null 2>&1
        done
    fi


    ### Cleanup network configuration ##########################

    if [ -f /etc/sysctl.d/50-one-context.conf ]; then
        rm -f /etc/sysctl.d/50-one-context.conf
    fi

    # Netplan
    if [ -d /etc/netplan/ ]; then
        rm -f /etc/netplan/*
    fi

    # NetworkManager
    if [ -d /etc/NetworkManager/system-connections/ ]; then
        rm -f /etc/NetworkManager/system-connections/*
    fi

    # systemd-networkd
    if [ -d /etc/systemd/network/ ]; then
        rm -f \
            /etc/systemd/networkd/*.network \
            /etc/systemd/networkd/*.link
    fi
}

genericBuild;
