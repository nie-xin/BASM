#!/bin/bash 
# 
# Initialized by Jean-Christophe Meillaud (www.github.com/jmeyo)
# TODO :
#  - support git
#  - more install options

#set -e

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions

function error() {
    JOB="$0"              # job name
    LASTLINE="$1"         # line of error occurrence
    LASTERR="$2"          # error code
    #echo "ERROR in ${JOB} : line ${LASTLINE} with exit code ${LASTERR}"
    cecho "Stopping  "`basename $0` $red
    exit 1
}
trap 'error ${LINENO} ${?}' ERR

declare -a MYACTIONS

# default if unset
default_projectname=""
default_scmtool="git"
default_scmurl=""
default_scmversion=""
default_install_path=""
default_install_env="prod"
default_deployment_user="www-data"
default_install_user=$USER
default_bundles=""
default_behat=""

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

sm_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

trap ctrl_c INT

function ctrl_c() {
	echo
	cecho "Halting  "`basename $0` $red
	exit 0;
}
cecho ()                    
# cecho.
# Argument $1 = message
# Argument $2 = color
{
	local default_msg="No message passed."
	message=${1:-$default_msg}   # Defaults to default message.
	color=${2:-$black}           # Defaults to black, if not specified.
	echo -e "$color-> $message $resetcolor"
}

confirm () {
	if $FORCE; then true;return;fi;
    q=$(cecho "${1:-Doing some stuff} \n-> Are you sure? [Y/n]")
    read -r -p "$q" response
    case $response in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            exit 0
            ;;
    esac
}

help()
{
	echo "Commands : "`basename $0`" OPTIONS"
	echo "WHERE OPTIONS"
	echo -e "\t-a : Dump bundles assets resources and generate assets"	
	echo -e "\t-b : Update composer dependencies"
	echo -e "\t-c : Clear and setup cache"
	echo -e "\t-e <environment_name> : Set symfony environment"
	echo -e "\t-f : Do not ask question mo'fo'"	
	echo -e "\t-g : Launch Behat tests"	
	echo -e "\t-i : Install a version of the application"	
	echo -e "\t-k : Check tools and/or install them"
	echo -e "\t-l <sm_config_file> : Load config from a spcific file"	
	echo -e "\t-p <installation_path> : Set an installation path"
	echo -e "\t-s : Drop and ReInstall Database"	
	echo -e "\t-t : Launch Phpunit tests"
	echo -e "\t-u <install|update|none>: Update a version of the application with option for the database : "	
	echo -e "\t\t - install: install database from scratch (drop everything first)"	
	echo -e "\t\t - update: update the database"	
	echo -e "\t\t - none: do not update the database"	
	echo -e "\t-u reinstall|update|none: Update a version of the application with option for the database : "	
	echo -e "\t-v <svn_version> : Set svn tag/version"	
	echo -e "\t-w : Generate and watch assets"
	echo -e "\t-y : Update database"
	echo -e "\t-z : Update Sco Manager"
	echo -e "You can mix those option together"
}

setup_webserver_apache()
{
	#tofinish....
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
	if [ -d "${install_path}/app/cache" -a -d "${install_path}/app/logs" ]; then
		sudo chown -R $user.$install_user ${install_path}/app/cache ${install_path}/app/logs
		sudo chmod -R 775 ${install_path}/app/cache ${install_path}/app/logs
	fi
}
install_assets()
{
	cecho "Install and dump assets"
	cd $install_path
	php ${install_path}/app/console assets:install web --env=$install_env --symlink
	php ${install_path}/app/console assetic:dump --env=$install_env
	cecho "Assets installed"
}


check_needed_apps()
{
	command -v less >/dev/null 2>&1 || { sudo apt-get update;sudo apt-get install npm;sudo npm install less -g; }
}

install_database()
{
	manage_database "install"
}

update_database()
{
	manage_database "update"
}

manage_database() 
{ 

	if [ $1 == "install" ]; then
		# hack to ignore error for already existing acl tables
		php app/console doctrine:database:drop --force --env="$install_env" || true
		php app/console doctrine:database:create --env="$install_env"	
	fi
	
	php app/console doctrine:schema:update --env="$install_env" --force
	if  $(confirm "Do you want to generate acl tables") ; then
		# hack to ignore error for already existing acl tables
		php app/console init:acl --env="$install_env" || true
		
	fi
	
	#add intial fixtures
	${FORCE} && opt="-n"
	php app/console doctrine:fixtures:load --env="$install_env" $opt
	#add environment specific fixtures
	for bundle in "${application_bundles[@]}"
    do
		if [ ! -z `ls ./src/$bundle/DataFixtures/$install_typenv 2>/dev/null` ]; then
			php app/console doctrine:fixtures:load --append --env="$install_env" --fixtures=./src/$bundle/DataFixtures/$install_typenv
		else
			cecho "No fixtures in ./src/$bundle/DataFixtures/$install_typenv" $blue
		fi
    done
}

getcode ()
{
	action=$1
	case $action in
		"create")
            case $application_scmtool in
				"git")
					cecho "Cloning git repository"
					git clone $application_scmurl .
				;; 
				"svn")
					cecho "Checkout svn repository"
					svn co $application_scmurl/$application_scmversion .
				;;
				esac
            ;;
		"update")
			case $application_scmtool in
				"git")
					cecho "Updating git repository from $application_scmversion branch"
					git pull origin master
				;; 
				"svn")
					cecho "Updating from svn repository"
					svn up
				;;
				esac
            ;;            
        *)
			cecho 
            exit 0;
            ;;
    esac
}
# those 2 functions should be merged
install_application ()
{
	action=${1:-"update"}
	if  $(confirm "Install $application_projectname into $install_path") ; then
		check_needed_tools
		check_needed_apps
		getcode "create"
		manage_composer "update"
		case "$UPDATEDB" in
			"install")
				install_database
			;;  
			"update")
				update_database
			;;
			"none")
				#doing nothing
			;;
		esac
		install_assets
		clear_cache
	fi
}
update_application ()
{
	if  $(confirm "Update $application_projectname into $install_path") ; then
		check_needed_tools
		cecho "Checkout code"
		getcode "update"
		manage_composer "update"
		install_database
		install_assets
		clear_cache
	fi
}
manage_composer()
{
	action=${1:-"update"}
	cecho $action"ing symfony dependencies through composer"
	php /usr/local/bin/composer.phar "$action"
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
launch_behat_test()
{
	if [ ${#application_behat[*]} -gt 0 ]; then
		cecho "Launching Behat Testing" $red
		for bundle in "${application_behat[@]}"
		do
			cecho "Behat Testing of bundle $bundle" $red
			php bin/behat @${bundle}
		done
    fi
}


install_composer()
{
	command -v curl >/dev/null 2>&1 && { exit 0; } || { sudo apt-get install curl; }	
	curl -s https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin
}

watch_assets()
{
	set_working_rights $depl_user
	php ${install_path}/app/console assetic:dump --env=$install_env --watch
}

setup_conf()
{
	if [ ! -z "$MYCONF" ]; then
		[ -f $MYCONF ] && cecho "Loading specific configuration from $MYCONF" $blue && source $MYCONF
		[ ! -f $MYCONF ] && cecho "Can't find configuration ile : $MYCONF in $PWD" $red && exit 0
	else 
		[ -f $PWD/.sm_config ] && cecho "Loading local configuration from $PWD/.sm_config" $blue && source $PWD/.sm_config
		[ -f ~/.sm_config -a ! -f $PWD/.sm_config ] && cecho "Loading personal default configuration from ~/.sm_config" $blue && source ~/.sm_config
	fi
	
	FORCE=${FORCE:-false}
	
	application_projectname=${application_projectname:-$default_projectname}
	application_scmurl=${application_scmurl:-$default_scmurl}
	application_scmtool=${application_scmtool:-$default_scmtool}
	[ "$application_scmtool" == "git" -o "$application_scmtool" == "svn" ] || (cecho "SCM tool not supported : $application_scmtool" $red && exit 0)
	
	application_bundles=${application_bundles:-$default_bundles}
	application_behat=${application_behat:-$default_behat}

	# Setup install_path
	if [ ! -z "$MYVERSION" ]; then
		application_scmversion=$MYVERSION
	else 
		application_scmversion=${application_scmversion:-$default_scmversion}
	fi
	
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
	cecho "\t - Environment : $install_env" $blue 
	cecho "\t - Install path : $install_path" $blue 
	cecho "\t - SCM Url : $application_scmurl" $blue
	cecho "\t - SCM Type : $application_scmtool" $blue 
	cecho "\t - SCM Application version : $application_scmversion" $blue 


	if [ ! -d "$install_path" ]; then
		if $(confirm "Work on $application_projectname (path: $install_path )"); then
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

# hce:awusitp:k
while getopts ":abcde:fghikl:p:r:stu:v:wyz" optname
  do
    case "$optname" in
      "f")
        FORCE=true
        ;;  
      "l")
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
      "r")
        MYREVISION=${OPTARG}
        ;;
      "v")
        MYVERSION=${OPTARG}
        ;;
      "h")
        help
        exit 0
        ;;    
      "c")
        MYACTIONS=("${MYACTIONS[@]}" "clear_cache")
        ;;
      "g")
        MYACTIONS=("${MYACTIONS[@]}" "launch_behat_test")
       ;;
      "i")
        MYACTIONS=("${MYACTIONS[@]}" "install_application")
        ;;
      "u")
        MYACTIONS=("${MYACTIONS[@]}" "update_application")
        UPDATEDB=${OPTARG}
       ;;
	  "y")
        MYACTIONS=("${MYACTIONS[@]}" "update_database")
       ;;
      "s")
        MYACTIONS=("${MYACTIONS[@]}" "install_database")
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
        MYACTIONS=("${MYACTIONS[@]}" "manage_composer")
        ;;                       
      "?")
        cecho "Unknown option $OPTARG" $red
        ;;
      ":")
        cecho "No argument value for option $OPTARG" $red
        ;;
      "z")
		  (
			cecho "Pull latest version of `basename $0` from master repository" $red
			cd $sm_dir
			git pull
		  ) 
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
    cecho "You are about to do those actions : ${MYACTIONS[*]}\n" $red
    set_working_rights $install_user
    for action in "${MYACTIONS[@]}"
    do
            $action
    done
    set_working_rights $depl_user

else 
    cecho "Nothing to do, try help (-h)\n" 
fi
