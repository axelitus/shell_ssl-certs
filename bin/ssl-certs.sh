#!/bin/bash
# ================================================================================
# SSL cert management script for Let's Encrypt - Script
#
# author: Axel Pardemann (axelitus)
# inspired-by: https://gist.github.com/thisismitch/7c91e9b2b63f837a0c4b
# ================================================================================
declare -r VERSION="0.1-alpha" # Sets the script's version following SemVer convention
declare -r SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Set the path where this script is installed
declare -r UTILS_PATH="/lib/ssl-certs/ssl-certs-utils" # Load utils scripts

# Load utils script
if [[ -f "$UTILS_PATH" ]]; then
    source "$UTILS_PATH"
else
    echo "[ERROR] Cannot find \"$UTILS_PATH\" utils library."
    exit 1
fi


# ========== begin: main ==========

__ssl-certs()
{
    local args action

    args=("$@")
    action=${args[0]}
    case "$action" in
        "certbot")
            __ssl-certs_certbot "${args[@]:1}"
            ;;
        "config")
            __ssl-certs_config "${args[@]:1}"
            ;;
        "get")
            __ssl-certs_get "${args[@]:1}"
            ;;
        "help" | "-h" | "-?")
            __ssl-certs_help
            ;;
        "list")
            __ssl-certs_list "${args[@]:1}"
            ;;
        "renew")
            __ssl-certs_renew "${args[@]:1}"
            ;;
        "revoke")
            __ssl-certs_revoke "${args[@]:1}"
            ;;
        "version")
            __ssl-certs_version
            ;;
        *)
            __ssl-certs_help
            ;;
    esac
}

# ========== end: main ==========


# ========== begin: certbot ==========

__ssl-certs_certbot()
{
    local args action

    args=("$@")
    action=${args[0]}
    case "$action" in
        "help" | "-h" | "-?")
            __ssl-certs_certbot_help
            ;;
        "install")
            __ssl-certs_certbot_install "${args[@]:1}"
            ;;
        "remove")
            __ssl-certs_certbot_remove
            ;;
        "update")
            __ssl-certs_certbot_update "${args[@]:1}"
            ;;
        *)
            __ssl-certs_certbot_help
            ;;
    esac
}

# ---------- begin: certbot help ----------
__ssl-certs_certbot_help()
{
    echo
    __ssl-certs_version
    echo
    echo -e "${COLOR_YELLOW}Usage:${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}ssl-certs certbot${COLOR_RESET} <command>"
    echo
    echo -e "${COLOR_YELLOW}Available commands:${COLOR_RESET}"

    __ssl-certs_certbot_help_commands
    for ((i=0; i<=${#commands[@]}; i+=2)) do
        cmd_str="$cmd_str  ${COLOR_GREEN}${commands[i]}${COLOR_RESET}\t${commands[i+1]}\n"
    done
    echo -e "$cmd_str" | column -t -s $'\t'
}

__ssl-certs_certbot_help_commands()
{
    commands=( \
        "install" "Installs Let's Encrypt certbot." \
        "remove" "Removes Let's Encrypt certbot." \
        "update" "Updates Let's Encrypt certbot to the latest published version." \
    )
}
# ---------- end: certbot help ----------

# ---------- begin: certbot install ----------
__ssl-certs_certbot_install()
{
    local no_deps extra_options
    no_deps=$FALSE
    extra_options=""

    while [[ $# -gt 0 ]] && [[ ."$1" = .--* ]]
    do
        option="$1" && shift
        case "$option" in
            "--no-deps")
                no_deps=$TRUE
                ;;
            "-n" | "--non-interactive" | "--noninteractive" | \
            "--os-packages-only")
                extra_options="$extra_options --noninteractive"
                ;;
        esac
    done
    extra_options="${extra_options:1}"

    certbot=$(__certbot_exists)
    if [[ $? -eq $TRUE ]]; then
        if [[ ! -L "$CERTBOT_SYMLINK" ]]; then
            ln -s "$CERTBOT_PATH/certbot-auto" "$CERTBOT_SYMLINK" &>/dev/null
        fi
        certbot=$(__certbot_exists)
        echo "[INFO] Certbot is already installed and can be execute using \"$certbot\" command."
        exit $EXIT_CODE_OK
    fi

    if [[ -d "$CERTBOT_PATH" ]]; then
        echo "[ERROR] The folder \"$CERTBOT_PATH\" already exists. Please remove it and try again."
        exit $EXIT_CODE_ERROR
    fi

    echo "[INFO] Certbot will be installed in $CERTBOT_PATH and a symlink will be created in \"$CERTBOT_SYMLINK\"..."
    git=$(which git)
    if [[ -z "$git" ]]; then
        "[ERROR] Git is not installed. Please install it before running this command again."
        exit $EXIT_CODE_ERROR
    fi

    git clone "$CERTBOT_REPO" "$CERTBOT_PATH"
    if [[ ! -f "$CERTBOT_PATH/certbot-auto" ]]; then
        echo "[ERROR] Could not install certbot. Please try again."
        exit $EXIT_CODE_ERROR
    fi

    ln -s "$CERTBOT_PATH/certbot-auto" "$CERTBOT_SYMLINK" &>/dev/null
    if [[ ! -L "$CERTBOT_SYMLINK" ]]; then
        "[ERROR] Could not symlink certbot-auto but it was correctly installed in \"$CERTBOT_PATH\" folder."
        exit $EXIT_CODE_ERROR
    fi

    if [[ $no_deps -eq $FALSE ]]; then
        certbot=$(__certbot_exists)
        echo "Installing certbot dependencies..."
        $certbot --os-packages-only $extra_options
        echo "Certbot dependencies installed."
    else
        echo "[INFO] Skipping dependencies installation."
    fi

    echo "[INFO] Certbot was correctly installed. You can use it with \"certbot-auto\" command."
}
# ---------- end: certbot install ----------

# ---------- begin: certbot remove ----------
__ssl-certs_certbot_remove()
{
    certbot=$(__certbot_or_fail $EXIT_CODE_OK "[INFO] Certbot is currently not installed.")

    if [[ -L "$CERTBOT_SYMLINK" ]]; then
        echo "[INFO] Removing certbot symlink..."
        rm "$CERTBOT_SYMLINK" &>/dev/null
        if [[ ! $? -eq $EXIT_CODE_OK ]]; then
            echo "[ERROR] Could not remove certbot-auto symlink."
            exit $EXIT_CODE_ERROR
        else
            echo "[INFO] Certbot symlink removed."
        fi
    fi

    echo "[INFO] Certbot will be remove from \"$CERTBOT_PATH\"..."
    rm -rf "$CERTBOT_PATH" &>/dev/null
    if [[ -d "$CERTBOT_PATH" ]]; then
        echo "[ERROR] Could not remove certbot folder. Please try again."
        exit $EXIT_CODE_ERROR
    else
        echo "[INFO] Certbot application removed."
    fi

    echo "[INFO] Certbot was correctly removed."
}
# ---------- end: certbot remove ----------

# ---------- begin: certbot update ----------
__ssl-certs_certbot_update()
{
    local no_deps extra_options
    no_deps=$FALSE
    extra_options=""

    while [[ $# -gt 0 ]] && [[ ."$1" = .--* ]]
    do
        option="$1" && shift
        case "$option" in
            "--no-deps")
                no_deps=$TRUE
                ;;
            "-n" | "--non-interactive" | "--noninteractive" | \
            "--os-packages-only")
                extra_options="$extra_options $option"
                ;;
        esac
    done
    extra_options="${extra_options:1}"

    certbot=$(__certbot_or_fail $EXIT_CODE_OK "[INFO] Certbot is currently not installed.")

    (cd "$CERTBOT_PATH" && git pull)

    if [[ $no_deps -eq $FALSE ]]; then
        echo "Updating certbot dependencies..."
        $certbot --os-packages-only $extra_options
        echo "Certbot dependencies updated."
    fi
}
# ---------- end: certbot update ----------

# ========== end: certbot ==========


# ========== begin: config ==========

__ssl-certs_config()
{
    local args action

    args=("$@")
    action=${args[0]}
    case "$action" in
        "help" | "-h" | "-?")
            __ssl-certs_config_help
            ;;
        "new")
            __ssl-certs_config_new "${args[@]:1}"
            ;;
        "remove")
            __ssl-certs_config_remove "${args[@]:1}"
            ;;
        *)
            __ssl-certs_config_help
            ;;
    esac
}

# ---------- begin: config help ----------
__ssl-certs_config_help()
{
    echo
    __ssl-certs_version
    echo
    echo -e "${COLOR_YELLOW}Usage:${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}ssl-certs config${COLOR_RESET} <command>"
    echo
    echo -e "${COLOR_YELLOW}Available commands:${COLOR_RESET}"

    __ssl-certs_config_help_commands
    for ((i=0; i<=${#commands[@]}; i+=2)) do
        cmd_str="$cmd_str  ${COLOR_GREEN}${commands[i]}${COLOR_RESET}\t${commands[i+1]}\n"
    done
    echo -e "$cmd_str" | column -t -s $'\t'
}

__ssl-certs_config_help_commands()
{
    commands=( \
        "new" "Creates new configuration file." \
        "remove" "Removes the configuration file." \
    )
}
# ---------- end: config help ----------

# ---------- begin: config new ----------
__ssl-certs_config_new()
{
    local config_name="$1"
    local edit=$FALSE

    shift
    while [[ $# -gt 0 ]] && [[ ."$1" = .--* ]]
    do
        option="$1" && shift
        case "$option" in
            "--edit")
                edit=$TRUE
        esac
    done

    if [ -z "$config_name" ]; then
        echo "No configuration name given."
        __ssl-certs_config_new_help
        return $EXIT_CODE_ERROR
    fi

    config_name=${config_name%.ini}
    if [ -f "$CONFIG_DOMAINS_PATH/$config_name.ini" ]; then
        echo "Configuration file \"$CONFIG_DOMAINS_PATH/$config_name.ini\" alread exists."
        return $EXIT_CODE_ERROR
    fi

    cp "$CONFIG_DOMAINS_PATH/.example.ini" "$CONFIG_DOMAINS_PATH/$config_name.ini"
    sed -i "s/cert-name = /cert-name = $config_name/g" "$CONFIG_DOMAINS_PATH/$config_name.ini"

    if [ $edit -eq $TRUE ]; then
        vim "$CONFIG_DOMAINS_PATH/$config_name.ini"
    fi

    echo "Config file \"$CONFIG_DOMAINS_PATH/$config_name.ini\" created."
}

# ---------- end: config new ----------

# ---------- begin: config new help ----------
__ssl-certs_config_new_help()
{
    echo
    __ssl-certs_version
    echo
    echo -e "${COLOR_YELLOW}Usage:${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}ssl-certs config new ${COLOR_RED}config_name"
    echo
    echo -e "${COLOR_YELLOW}Available options:${COLOR_RESET}"

    __ssl-certs_config_new_help_options
    for ((i=0; i<=${#options[@]}; i+=2)) do
        cmd_str="$cmd_str  ${COLOR_GREEN}${options[i]}${COLOR_RESET}\t${options[i+1]}\n"
    done
    echo -e "$cmd_str" | column -t -s $'\t'
}

__ssl-certs_config_new_help_options()
{
    options=( \
        "--edit" "Opens configuration file in vim." \
    )
}
# ---------- begin: config new help ----------

# ---------- begin: config remove ----------
__ssl-certs_config_remove()
{
    local config_name="$1"
    local assume_yes=$FALSE

    shift
    while [[ $# -gt 0 ]] && [[ ."$1" = .--* ]]
    do
        option="$1" && shift
        case "$option" in
            "--assume-yes")
                assume_yes=$TRUE
        esac
    done

    if [ -z "$config_name" ]; then
        echo "No configuration name given."
        __ssl-certs_config_remove_help
        return $EXIT_CODE_ERROR
    fi

    config_name=${config_name%.ini}
    if [ ! -f "$CONFIG_DOMAINS_PATH/$config_name.ini" ]; then
        echo "Configuration file \"$CONFIG_DOMAINS_PATH/$config_name.ini\" does not exist."
        return $EXIT_CODE_OK
    fi

    if [ $assume_yes -eq $FALSE ]; then
        echo -n "Are you sure you want to remove configuration \"$config_name\"? (y/N): "
        read remove
        if [[ "${remove[0]}" != "y" && "${remove[0]}" != "Y" ]]; then
            echo "Configuration removal cancelled."
            return $EXIT_CODE_OK
        fi
    fi

    rm "$CONFIG_DOMAINS_PATH/$config_name.ini"
    echo "Config file \"$CONFIG_DOMAINS_PATH/$config_name.ini\" removed."
}

# ---------- end: config remove ----------

# ---------- begin: config remove help ----------
__ssl-certs_config_remove_help()
{
    echo
    __ssl-certs_version
    echo
    echo -e "${COLOR_YELLOW}Usage:${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}ssl-certs config remove ${COLOR_RED}config_name"
    echo
}
# ---------- begin: config remove help ----------

# ========== end: config ==========


# ========== begin: get ==========

__ssl-certs_get()
{
    local extra_options
    extra_options=""

    while [[ $# -gt 0 ]] && [[ ."$1" = .--* ]]
    do
        option="$1" && shift
        case "$option" in
            "--agree-tos" | \
            "--keep-until-expiring" | "--keep" | "--reinstall" | \
            "-n" | "--non-interactive" | "--noninteractive" | \
            "--test-cert" | "--staging")
                extra_options="$extra_options $option"
                ;;
        esac
    done
    extra_options="${extra_options:1}"

    certbot=$(__certbot_or_fail $EXIT_CODE_ERROR "[ERROR] Certbot is not installed. Please install it with \"ssl-certs certbot install\" and run this command again.")
    config_files=$(find "$CONFIG_DOMAINS_PATH" -maxdepth 1 -type f -iname '*.ini' ! -iname '.*' | sort)
    OIFS="$IFS"; IFS=$'\n'; configs=($config_files); IFS="$OIFS"; configc=${#configs[@]}

    if [[ $configc -eq 0 ]]; then
        echo "[INFO] No domain configuration files found."
        exit $EXIT_CODE_OK
    fi

    for f in "${configs[@]}"
    do
        cert_name=$(cat "$f" | grep "cert-name" | sed -E 's/cert-name( +)?=( +)?//')
        cert_info=$($certbot certificates | awk "/Certificate Name: $cert_name\$/,/privkey.pem\$/")

        if [[ -n "$cert_info" ]]; then #|| ( -d "$CERTBOT_LIVE_PATH/$cert_name" && -L "$CERTBOT_LIVE_PATH/$cert_name/$CERTBOT_FULLCHAIN_SUFFIX.pem" ) ]]; then
            echo "[INFO] Certificate \"$cert_name\" exists, skipping certificate registration."
            continue
        fi

        cert_days_expire=$(echo -e "$cert_info" | awk "/\(VALID: /,/ days\)/" | sed -e 's/.*VALID: \(.*\) days)/\1/')
        if [[ -f "$CONFIG_HOOK_PRE_DOMAIN" ]]; then
            echo "[INFO] Executing pre-domain hook for file \"$f\""
            source "$CONFIG_HOOK_PRE_DOMAIN"
        fi

        concat_config=$(__concat_config_files "$CONFIG_FILE" "$f")
        if [[ $? -eq $FALSE ]]; then
            echo "[ERROR] There seems to be an error with your configuration. Fix the problems and try again."
            exit $EXIT_CODE_ERROR
        fi
        
        if [[ $? -eq $FALSE ]]; then
            echo "[ERROR] An error occurred while concatenating config files."
            exit $EXIT_CODE_ERROR
        fi

        tmp_config=$(mktemp "/tmp/ssl-certs-config-XXXXXXXX.tmp")
        if [[ $? -eq $FALSE ]]; then
            echo "[ERROR] An error occurred while saving the temp config file."
            exit $EXIT_CODE_ERROR
        fi
        echo -e "$concat_config" > "$tmp_config"

        $certbot certonly --config "$tmp_config" $extra_options
        echo "[INFO] Finished executing certbot for config file \"$f\" with certificate name \"$cert_name\"."

        cert_fullchain="$CERTBOT_LIVE_PATH/$cert_name/$CERTBOT_FULLCHAIN_SUFFIX.pem"
        if [[ ! -L "$cert_fullchain" ]]; then
            echo "[WARN] Seems like the certificate has not been correctly created, the live $CERTBOT_FULLCHAIN_SUFFIX file is missing."
        fi

        cert_privkey="$CERTBOT_LIVE_PATH/$cert_name/$CERTBOT_PRIVKEY_SUFFIX.pem"
        if [[ ! -L "$cert_privkey" ]]; then
            echo "[WARN] Seems like the certificate has not been correctly created, the live $CERTBOT_PRIVKEY_SUFFIX file is missing."
        fi

        if [[ -f "$CONFIG_HOOK_POST_DOMAIN" ]]; then
            echo "[INFO] Executing post-domain hook for cert_name \"$cert_name\"."
            source "$CONFIG_HOOK_POST_DOMAIN"
        fi

        rm "$tmp_config" 2>/dev/null
        echo "[INFO] Temp config \"$tmp_config\" removed."

        echo "[INFO] Finished getting certificates for config \"$f\""
    done
}

# ========== end: get ==========


# ========== begin: help ==========

__ssl-certs_help()
{
    echo
    __ssl-certs_version
    echo
    echo -e "${COLOR_YELLOW}Usage:${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}ssl-certs${COLOR_RESET} <command> [<sub-command>]"
    echo
    echo -e "${COLOR_YELLOW}Available commands:${COLOR_RESET}"

    __ssl-certs_help_commands
    for ((i=0; i<=${#commands[@]}; i+=2)) do
        cmd_str="$cmd_str  ${COLOR_GREEN}${commands[i]}${COLOR_RESET}\t${commands[i+1]}\n"
    done
    echo -e "$cmd_str" | column -t -s $'\t'
}

__ssl-certs_help_commands()
{
    commands=( \
        "certbot" "Manages Let's Encrypt certbot." \
        "config" "Handles configuration options." \
        "get" "Gets new certificates for domains from Let's Encrypt." \
        "help" "Displays help for this application." \
        "list" "Lists all registered certifciates."
        "renew" "Renews existing Let's Encrypt issued certificates." \
        "revoke" "Revokes existing Let's Encrypt issued certificates." \
        "version" "Displays this application version." \
    )
}

# ========== end: help ==========


# ========== begin: list ==========

__ssl-certs_list()
{
    local extra_options
    extra_options=""

    while [[ $# -gt 0 ]] && [[ ."$1" = .--* ]]
    do
        option="$1" && shift
        case "$option" in
            "-n" | "--non-interactive" | "--noninteractive" | \
            "--no-bootstrap")
                extra_options="$extra_options $option"
                ;;
        esac
    done
    extra_options="${extra_options:1}"

    certbot=$(__certbot_or_fail $EXIT_CODE_ERROR "[ERROR] Certbot is not installed. Please install it with \"ssl-certs certbot install\" and run this command again.")
    $certbot certificates $extra_options
}

# ========== end: list ==========


# ========== begin: renew ==========

__ssl-certs_renew()
{
    echo "ssl-certs renew"
}

# ========== begin: renew ==========


# ========== begin: revoke ==========

__ssl-certs_revoke()
{
    echo "ssl-certs revoke"
}

# ========== end: revoke ==========


# ========== begin: version ==========

__ssl-certs_version()
{
    echo "ssl-certs version $VERSION"
}

# ========== end: version ==========


# ********** begin: entry point **********
# Enforce to run with root privileges
if [[ $EUID != 0 ]]; then
    echo "Requesting root privileges to run ssl-certs..."
    sudo "$0" "$@"
    exit $?
fi
__ssl-certs "$@"
# ********** end: entry point **********
