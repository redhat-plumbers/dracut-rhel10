#!/bin/bash

# called by dracut
check() {
    return 0
}

depends() {
    echo openssl
}

# called by dracut
installkernel() {
    local _fipsmodules _mod _bootfstype
    if [[ -f "${srcmods}/modules.fips" ]]; then
        read -d '' -r _fipsmodules < "${srcmods}/modules.fips"
    else
        _fipsmodules=""

        # Hashes:
        _fipsmodules+="sha1 sha224 sha256 sha384 sha512 "
        _fipsmodules+="sha3-224 sha3-256 sha3-384 sha3-512 "
        _fipsmodules+="crc32c crct10dif ghash "

        # Ciphers:
        _fipsmodules+="cipher_null des3_ede aes cfb dh ecdh "

        # Modes/templates:
        _fipsmodules+="ecb cbc ctr xts gcm ccm authenc hmac cmac ofb cts "

        # Compression algs:
        _fipsmodules+="deflate lzo "

        # PRNG algs:
        _fipsmodules+="ansi_cprng "

        # Misc:
        _fipsmodules+="aead cryptomgr tcrypt crypto_user "
    fi

    for _mod in $_fipsmodules; do
        if hostonly='' instmods -c -s "$_mod"; then
            echo "$_mod" >> "${initdir}/etc/fipsmodules"
            echo "blacklist $_mod" >> "${initdir}/etc/fips.conf"
        fi
    done

    # with hostonly_default_device fs module for /boot is not installed by default
    if [[ $hostonly ]] && [[ $hostonly_default_device == "no" ]]; then
        _bootfstype=$(find_mp_fstype /boot)
        if [[ -n $_bootfstype ]]; then
            hostonly='' instmods "$_bootfstype"
        else
            dwarning "Can't determine fs type for /boot, FIPS check may fail."
        fi
    fi
}

# called by dracut
install() {
    inst_hook pre-pivot 00 "$moddir/fips-boot.sh"
    inst_hook pre-pivot 01 "$moddir/fips-noboot.sh"
    inst_hook pre-udev 01 "$moddir/fips-load-crypto.sh"
    inst_script "$moddir/fips.sh" /sbin/fips.sh

    inst_multiple sha512hmac rmmod insmod mount uname umount grep sed cut find sort cat tail tr

    inst_simple /etc/system-fips
}
