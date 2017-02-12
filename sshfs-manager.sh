#!/bin/bash
# Title: SSHFS Manager
# Description: A bash script for managing SSHFS connections.
# Author: Tanase Butcaru - butcaru.com
# Date: 05-02-2017
# License: MIT
# Version: 0.1

# Functions - Helpers
showMessage() {
    if [ ${#messages[*]} == 0 ]; then
        messages=(
            [HELP_SCRIPT_DESCRIPTION]='SSHFS Manager is a bash script for managing SSHFS connections.\n\n'
            [HELP_INSTALL_LOCAL]='\t install                 install %s for current user\n'
            [HELP_ADD_SERVER]='\t add-server              add new server\n'
            [HELP_CONNECT]='\t connect                 connect to a specific server from the a list of added servers\n'
            [HELP_DISCONNECT]='\t disconnect [domain]     disconnect all or specific servers\n'
            [HELP_HELP]='\t help --help             opens help menu\n'
            [HELP_SCRIPT_USAGE]='\nUsage: %s command [argument]\n\n'
            [INVALID_COMMAND]='[SSHFS-MGR] Please run one of the available commands from the help menu (%s --help).\n'
            [NO_SERVERS]='[SSHFS-MGR] No servers were found. Add a server using the "add-server" command.\n'
            [AVAILABLE_SERVERS]='[SSHFS-MGR] Available servers:\n'
            [USER_INPUT_SERVER_INDEX]='\n[SSHFS-MGR] Enter a number from the list: '
            [USER_INPUT_INVALID_SERVER_INDEX]='[SSHFS-MGR] Please select a valid number from the list. Exiting...\n'
            [SERVER_NOT_FOUND]='[SSHFS-MGR] Could not find server %s in local database. Exiting...\n'
            [SERVER_CONNECTING]='[SSHFS-MGR] Connecting to server %s...\n'
            [SERVER_DISCONNECT_ONE]='[SSHFS-MGR] Server is now disconnected.\n'
            [SERVER_DISCONNECT_ALL]='[SSHFS-MGR] All servers are now disconnected.\n'
            [SERVER_DISCONNECTING]='[SSHFS-MGR] Disconnecting server %s...\n'
            [ADD_SERVER_INFO]='[SSHFS-MGR] Adding new server...\n'
            [ADD_SERVER_DOMAIN]='\t Server address (eg: mydomain.com): '
            [ADD_SERVER_USER]='\t SSH username: '
            [ADD_SERVER_SOURCEDIR]='\t Server source directory to be mounted (eg: public_html): '
            [ADD_SERVER_MOUNTDIR]='\t Local mount directory under global mount path (eg: mydomain_com): '
            [ADD_SERVER_SSHFSOPTIONS]='\t SSHFS options (any option provided by sshfs --help): '
            [ADD_SERVER_SUCCESS]="[SSHFS-MGR] Server has been successfully saved.\n"
            [ADD_SERVER_SUCCESS_POST]='[SSHFS-MGR] You can now connect to %s using the "connect" command.\n'
            [LOAD_DATA_FILE_ERROR]='[SSHFS-MGR] No installation found. Please run the "install" command.\n'
            [INSTALL_NEW_DESCRIPTION]='[SSHFS-MGR] Begin installation...\n'
            [INSTALL_NEW_CORE_MOUNTPATH]='\t Mount path under which all servers will be mounted: '
            [INSTALL_NEW_SUCCESS]='[SSHFS-MGR] Script has been successfully installed.\n[SSHFS-MGR] Open new terminal window and run "%s --help" for the available commands.\n'
            [INSTALL_EXISTS]='[SSHFS-MGR] Script already installed. Thanks for using it!\n'
            [AUTHOR_REGARDS]='[SSHFS-MGR] Regards from Tanase Butcaru :)\n'
        )
    fi

    printf "${messages[$1]}" $2 $3
}

checkMountingPath() {
    fullMountPath="${config[mountPath]}/$1"

    if [ ! -d $fullMountPath ]; then
        mkdir -p $fullMountPath;
    fi
}

checkIfServerExists() {
    serverIdentifier=$1
    identifyByIndex=$2
    result=1

    if [ "$identifyByIndex" = true ]; then
        if [ ${serverList[$serverIdentifier]+isset} ]; then
            result=0
        fi
    else
        if [ ${servers[$serverIdentifier,'domain']+isset} ]; then
            result=0
        fi
    fi
    
    return $result
}

getServerDomainByMountDir() {
    mountDir=$1

    for key in ${!servers[*]}; do
        keyDomain="${key%%,*}"
        keyProperty="${key#*,}"
        
        if [ ${servers[$keyDomain,'mountDir']} == $mountDir ]; then
            echo "$keyDomain"
            break
        fi
    done

    return 1
}

# Functions - Actions
launchScript() {
    if [ $action == 'install' ]; then
        install
    else
        loadDataFile
    fi

    if [ $action == 'add-server' ]; then
        addServer
    elif [ $action == 'connect' ]; then
        connectPrompt
    elif [ $action == 'disconnect' ]; then
        disconnect $actionArgument
    elif [ $action == 'help' ] || [ $action == '--help' ]; then
        helpMenu
    else
        showMessage INVALID_COMMAND $scriptRunCmd
    fi
}

loadDataFile() {
    # Check installation
    if [ ! -f $scriptDataFilePath ]; then
        showMessage LOAD_DATA_FILE_ERROR
        exit 1;
    fi

    # Load data file
    lastArrayKey=""
    isCore=0
    serverIndex=0

    while read -r line; do
        if [ "${#line}" == 0 ]; then
            continue
        fi

        # Get data section name
        # Remove '[]' from lines that start with '['; section name format "[domain]"
        if [[ $line == [* ]]; then
            lastArrayKey="${line#[}"
            lastArrayKey="${lastArrayKey%]}"

            if [ $line == "[core]" ]; then
                isCore=1
            else
                isCore=0
                serverIndex=$((serverIndex + 1))
            fi
            
            continue
        fi

        # Set data into sections
        # Left side before 1st "=" is the key, right side after 1st "=" is the value
        dataKey="${line%%=*}"
        dataValue="${line#*=}"

        if [ $isCore == 1 ]; then
            config[$dataKey]=$dataValue
        else
            servers[$lastArrayKey,$dataKey]=$dataValue
            serverList[$serverIndex]=$lastArrayKey
        fi

    done < "$scriptDataFilePath"
}

install() {
    # Begin (re)insallation
    if [ -f $scriptDataFilePath ]; then
        installExists
    else
        installNew
    fi
}

installNew() {
    showMessage INSTALL_NEW_DESCRIPTION

    # Let use choose the root mounting path
    showMessage INSTALL_NEW_CORE_MOUNTPATH
    read -e -i $defaultMountPath mountPath
    mountPath=${mountPath:-$defaultMountPath}
    
    # Check installation directory
    if [ ! -d $scriptInstallDir ]; then
        mkdir -p $scriptInstallDir;
    fi

    # Check mount path directory
    if [ ! -d $mountPath ]; then
        mkdir -p $mountPath;
    fi

    # Copy script into install directory
    scriptFileAbsolutePath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    scriptFileInstallPath="$scriptInstallDir/${BASH_SOURCE[0]}"
    cp $scriptFileAbsolutePath $scriptFileInstallPath

    # Save configuration
    touch $scriptDataFilePath
    printf "[core]\n\tmountPath=$mountPath\n\n" > $scriptDataFilePath

    # Add script command alias in user's .bashrc
    printf "\n# SSHFS Manager command alias\nalias $scriptRunCmd='$scriptFileInstallPath'" >> "$userHome/.bashrc"
    source "$userHome/.bashrc"

    showMessage INSTALL_NEW_SUCCESS $scriptRunCmd
    showMessage AUTHOR_REGARDS

    exit 0;
}

installExists() {
    showMessage INSTALL_EXISTS
    showMessage AUTHOR_REGARDS

    exit 0;
}

addServer() {
    showMessage ADD_SERVER_INFO

    # Read server data
    showMessage ADD_SERVER_DOMAIN
    read -e domain

    showMessage ADD_SERVER_USER
	read -e user

	showMessage ADD_SERVER_SOURCEDIR
    read -e sourceDir

    showMessage ADD_SERVER_MOUNTDIR
	read -e mountDir

    showMessage ADD_SERVER_SSHFSOPTIONS
	read -e sshfsOptions

    # Save server data
    saveKey="[$domain]"
    saveDomain="domain=$domain"
    saveUser="user=$user"
    saveSourceDir="sourceDir=$sourceDir"
    saveMountDir="mountDir=$mountDir"
    saveSshfsOptions="sshfsOptions=$sshfsOptions"

    # Save server data to file
    printf "$saveKey\n\t$saveDomain\n\t$saveUser\n\t$saveSourceDir\n\t$saveMountDir\n\t$saveSshfsOptions\n\n" >> $scriptDataFilePath

    printf "
    ##    $saveKey
    ****       $saveDomain
    ****       $saveUser
    ****       $saveSourceDir
    ****       $saveMountDir
    ****       $saveSshfsOptions\n\n"

    showMessage ADD_SERVER_SUCCESS
    showMessage ADD_SERVER_SUCCESS_POST $domain
}

connectPrompt() {
    # Check if a list of servers exists
    if [ ${#serverList[*]} == 0 ]; then
        showMessage NO_SERVERS
        exit 0;
    fi

    # Print available server list
    showMessage AVAILABLE_SERVERS
    for index in ${!serverList[*]}; do
        printf "\t$index - ${serverList[$index]}\n"
    done

    # Let user choose a server from the list
    showMessage USER_INPUT_SERVER_INDEX
    read -e selectedIndex

    # Check if selection exists on the list
    if ! checkIfServerExists $selectedIndex true; then
        showMessage USER_INPUT_INVALID_SERVER_INDEX
        exit 0;
    fi

    # Connect!
    connect ${serverList[$selectedIndex]}
}

connect() {
    serverDomain=$1

    if ! checkIfServerExists $serverDomain; then
        showMessage SERVER_NOT_FOUND $serverDomain
        exit 0;
    else
        showMessage SERVER_CONNECTING $serverDomain
    fi

    # Get server config
    domain=${servers[$serverDomain,'domain']}
	user=${servers[$serverDomain,'user']}
	sourceDir=${servers[$serverDomain,'sourceDir']}
	mountDir=${servers[$serverDomain,'mountDir']}
	sshfsOptions=${servers[$serverDomain,'sshfsOptions']}
    
    fullMountPath=${config[mountPath]}/$mountDir

    # Check mount directory
    checkMountingPath $mountDir

    # Run sshfs command...
    sshfs $user@$domain:$sourceDir $fullMountPath $sshfsOptions
}

disconnect() {
    serverDomain=$1

    # Check if a list of servers exists
    if [ ${#serverList[*]} == 0 ]; then
        showMessage NO_SERVERS
        exit 0;
    fi

    if [ ! $serverDomain ]; then
        disconnectAll
    else
        if ! checkIfServerExists $serverDomain; then
            showMessage SERVER_NOT_FOUND $serverDomain
            exit 0;
        else
            disconnectOne $serverDomain
            showMessage SERVER_DISCONNECT_ONE
        fi
    fi
}

disconnectAll() {
    dirList=`ls -l --time-style="long-iso" ${config[mountPath]} | egrep '^d' | awk '{print $8}'`

    for dirName in $dirList; do
        serverDomain=`getServerDomainByMountDir $dirName`
        if [ ! $serverDomain ]; then
            continue
        else 
            disconnectOne $serverDomain
        fi
    done

    showMessage SERVER_DISCONNECT_ALL
}

disconnectOne() {
    serverDomain=$1
    mountDir=${servers[$serverDomain,'mountDir']}

    fullMountPath="${config[mountPath]}/$mountDir"
    dirIsMounted=`grep -c "$fullMountPath" /etc/mtab`

    if [ $dirIsMounted == 1 ]; then
        showMessage SERVER_DISCONNECTING $serverDomain
        fusermount -u ${fullMountPath}
    fi
}

helpMenu() {
    showMessage HELP_SCRIPT_DESCRIPTION
    showMessage HELP_INSTALL_LOCAL $scriptRunCmd
    showMessage HELP_ADD_SERVER
    showMessage HELP_CONNECT
    showMessage HELP_DISCONNECT
    showMessage HELP_HELP
    showMessage HELP_SCRIPT_USAGE $scriptRunCmd
}

# Script variables
userHome=`echo "$HOME"`
scriptRunCmd='sshfs-mgr'
scriptInstallDir="$userHome/.sshfs-manager"
scriptDataFilePath="$scriptInstallDir/manager.data"
defaultMountPath="$userHome/SSHFS_MGR"

action=${1:-"no_action"}
actionArgument=$2

# Script data
declare -A config=( [mountPath]=$defaultMountPath )
declare -A messages
declare -A serverList
declare -A servers

# Script run
launchScript