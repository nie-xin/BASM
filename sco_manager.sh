#!/bin/bash 
# jcz
# TODO :

#set -e
#set -o pipefail

declare -a MYACTIONS

# default if unset
default_projectname="scolibri"
default_svnurl="svn://schulcloud.de/scolarium/"
default_svnpath="trunk"
default_install_path="."
default_install_env="prod"
default_deplyment_user="www-data"
default_install_user=$USER


black='\E[30;47m'
red='\E[31;47m'
green='\E[32;47m'
yellow='\E[33;47m'
blue='\E[34;47m'
magenta='\E[35;47m'
cyan='\E[36;47m'
white='\E[37;47m'

resetcolor='\e[0m'      
# Text Reset

alias Reset="tput sgr0"

cecho ()                    
# Color-echo.
# Argument $1 = message
# Argument $2 = color
{
	local default_msg="No message passed."
	message=${1:-$default_msg}   # Defaults to default message.
	color=${2:-$black}           # Defaults to black, if not specified.
	echo -e "$color-> $message $resetcolor"
}

confirm () {
    # call with a prompt string or use a default
    q=$(cecho "${1:-Doing some stuff} \n-> Are you sure? [Y/n]")
    read -r -p "$q" response
    case $response in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

help()
{
	echo "Commands : "`basename $0`" OPTIONS"
	echo "WHERE OPTIONS"
	echo -e "\t-p <installation_path> : Set an installation path"
	echo -e "\t-e <environment_name> : set symfony environment"
	echo -e "\t-c : clear and setup cache"
	echo -e "\t-a : dump bundles assets resources and generate assets"
	echo -e "\t-w : generate and watch assets"
	echo -e "\t-k : check tools and/or install them"
	echo -e "\t-i : install a version of scolibri"
	echo -e "\t-b : update composer.phar"
	echo -e "\t-u : Drop and ReInstall Database"	
	echo -e "\t-s : Update database"	
	echo -e "\t-t : Launch test"
}

setup_webserver_apache()
{
	sudo a2enmod rewrite
	service apache2 restart

}
check_needed_tools()
{
	command -v svn >/dev/null 2>&1 || { sudo apt-get install subversion; }
	command -v git >/dev/null 2>&1 || { sudo apt-get install git; }
	locate composer.phar >/dev/null 2>&1 || install_composer
}

clear_cache ()
{
	cecho "Clear cache and logs" $red
	sudo rm -rf ${install_path}/app/cache/*
	sudo rm -rf ${install_path}/app/logs/*
	cecho "Set good rights for cache and logs"
	cecho "Clear cache done"
}
set_working_rights()
{
        user=${1:-$depl_user}
        sudo chown $user.$install_user ${install_path}/app/cache ${install_path}/app/logs
        sudo chmod 775 ${install_path}/app/cache ${install_path}/app/logs
}
install_assets()
{
	cecho "Install and dump assets"
	cd $install_path
	php ${install_path}/app/console assets:install web --env=$install_env --symlink
	php ${install_path}/app/console assetic:dump --env=$install_env
	cecho "Assets installed"
}

install_database()
{

	cd $install_path
    sudo -u www-data php app/console doctrine:database:drop --force --env="$install_env"
	sudo -u www-data  php app/console doctrine:database:create --env="$install_env"
	sudo -u www-data php app/console doctrine:schema:update --env="$install_env" --force
	sudo -u www-data php app/console doctrine:fixtures:load --env="$install_env"
	sudo -u www-data php app/console doctrine:fixtures:load --append --env="$install_env" --fixtures=./src/Scolibri/CoreBundle/DataFixtures/$install_typenv
}

update_database()
{
	cd $install_path
	php app/console doctrine:schema:update --env="$install_env" --force
	#add intial fixtures
	php app/console doctrine:fixtures:load --env="$install_env"
	#add environment specific fixtures
	php app/console doctrine:fixtures:load --append --env="$install_env"  --fixtures=./src/Scolibri/CoreBundle/DataFixtures/$install_typenv
}

install_application ()
{
	if  $(confirm "Install $application_projectname into $install_path") ; then
		mkdir -p $install_path && cd $install_path
		# do dangerous stuff		
		check_needed_tools
		cecho "Checkout code"
		svn co $application_svnurl/$application_svnversion .
		cecho "Installing symfony dependencies through composer"
		php /usr/local/bin/composer.phar install
		install_database
		install_assets
		clear_cache
	fi

}
update_composer()
{
	php /usr/local/bin/composer.phar update
}
install_phpunit()
{
	command -v phpunit >/dev/null 2>&1 && { return; } || { cecho "Trying to install phpunit" $red >&2;  }	
	# test and/or install pear
	command -v pear >/dev/null 2>&1 || { cecho "I require pear but it's not installed. lets install that shit." >&2;sudo apt-get install php-pear;}	
	sudo apt-get install phpunit
	sudo pear channel-discover pear.phpunit.de
	sudo pear channel-discover components.ez.no
	sudo pear install --force --alldeps phpunit/PHPUnit
	sudo apt-get install php5-xdebug
	cecho "Phpunit might work now" $red 
}

launch_test()
{
	install_phpunit
	cecho "Launching Test" $red
	phpunit -c app/
	
}

install_composer()
{
	command -v curl >/dev/null 2>&1 && { exit 0; } || { sudo apt-get install curl; }	
	curl -s https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin
}

watch_assets()
{
	php ${install_path}/app/console assetic:dump --env=$install_env --watch
}

setup_conf()
{
	if [ ! -z "$MYCONF" ]; then
		[ -f $MYCONF ] && cecho "Loading configuration from $MYCONF" $blue && source $MYCONF
		[ -f $PWD/$MYCONF ] && cecho "Loading configuration from $PWD/$MYCONF" $blue && source $PWD/$MYCONF
	else 
		[ -f $PWD/.sm_config ] && cecho "Loading configuration from $PWD/.sm_config" $blue && source $PWD/.sm_config
	fi
	
	application_projectname=${application_projectname:-$default_projectname}
	application_svnurl=${application_svnurl:-$default_svnurl}
	application_svnversion=${application_svnversion:-$default_svnversion}
	
	# Setup install_path
	if [ ! -z "$MYPATH" ]; then
		install_path=$MYPATH
	else 
		install_path=${install_path:-$application_install_path}
	fi
	
	# Setup install_env
	if [ ! -z "$MYENV" ]; then
		install_env=$MYENV
	else
		install_env=${application_install_env:-$default_install_env}
	fi
	
	# Hack to load fixtures for dev and test
	[ "${install_env:0:3}" == "dev" ] && install_typenv="tes" || install_typenv=${install_env:0:3}

	cecho "Working on project $application_projectname" $blue
	cecho "\t - environment : $install_env" $blue 
	cecho "\t - install path : $install_path" $blue 

	if [ ! -d "$install_path" ]; then
		if $(confirm "Work on $application_projectname (path: $install_path )") ; then
		#if [ confirm "Working with $application_projectname into $install_path\n" ]; then
			mkdir -p $install_path
		else
			exit 0;
		fi
	fi
	install_user=${application_install_user:-$default_install_user}
	depl_user=${application_deployment_user:-$default_deployment_user}

	cd $install_path
	#[ ! -n "$install_path" ] && echo "Cannot find symfony application" && exit 0

}

get_conf()
{
	svnurl="svn://schulcloud.de/scolarium/"
	svnpath="."
	
}

# get the conf
get_conf

# hce:awusitp:k

while getopts ":hf:ce:abwusitdp:k:" optname
  do
    case "$optname" in
      "f")
        MYCONF=${OPTARG}
        ;;    
      "d")
        set -x
        ;;  
      "e")
        MYENV=${OPTARG}
        ;;
      "p")
        MYPATH=${OPTARG}
        ;;
      "h")
        help
        exit 0
        ;;
      "c")
        MYACTIONS=("${MYACTIONS[@]}" "clear_cache")
        ;;
      "i")
        MYACTIONS=("${MYACTIONS[@]}" "install_application")
        ;;
      "u")
        MYACTIONS=("${MYACTIONS[@]}" "update_database")
       ;;
      "s")
        MYACTIONS="install_database"
        ;;        
      "a")
        MYACTIONS=("${MYACTIONS[@]}" "install_assets")
        ;;
      "w")
        MYACTIONS=("${MYACTIONS[@]}" "watch_assets")
        ;;
      "k")
        MYACTIONS=("${MYACTIONS[@]}" "check_needed_tools")
        ;;
      "t")
        MYACTIONS=("${MYACTIONS[@]}" "launch_test")
        ;;
      "b")
        MYACTIONS=("${MYACTIONS[@]}" "update_composer")
        ;;                       
      "?")
        cecho "Unknown option $OPTARG" $red
        ;;
      ":")
        cecho "No argument value for option $OPTARG" $red
        ;;
      *)
        cecho -e "\n\t-> $OPTARG Bad options\n\n" $red
        help
        ;;
    esac
  done
 
[ -z "$1" ] && cecho "Nothing to do, try help (-h)\n" && exit


if [ ! -z $MYACTIONS ]; then
    setup_conf
    cecho "\nYou are about to do those actions : ${MYACTIONS[*]}\n" $red
    set_working_rights $install_user
    for action in "${MYACTIONS[@]}"
    do
            $action
    done
    set_working_rights $depl_user
else 
    cecho "Nothing to do, try help (-h)\n" 
fi
