BASM
====

Bash Advanced Symfony Manager

Simple tool to manage your Symfony Project


Usage
=====
Launch it like a simple script.

For simple use add it to your path, or better, add a alias (in ~/.bash_aliases for example)

    alias sm="<path_to_your_project>/vendor/jmeyo/BASM/sco_manager.sh"

Then use it like :

    sm -h // show help
    
    
    
    sm -ac // copy assets, and clear cache
    
About configuration
===================

Its possible to load a configuration from several places. 

Either through the -f option, to link with a specific file, or if you just want to work on a specific project, just put a "sm-config-<project_name>" file in your home directory (you can prefix it with a dot to hide it). A sample "sm-config-default" can be found in the default BASM directory

First BASM check for the presence of a configuration file passed as a parameter, then it uses the .sm_config file in the home directory, then it looks in the current directory. If nothing is fine, then it just use default values, which should not feed your needs ;)

Check `.sm_config` Sample for more information

Best Practice
=============

This simple manager gives you the ability to never lose anymore time with annoying symony commands, as it takes care of rights ;)
A good way of using it for several projects might be to define several alias, with different config file and store them in a common directory (for example /home/user/work/config-tools/sm-config). 

With bash, you could add something like that in the ~/.bash_aliases file to parse that directory and add alias for your projects automatically

	# sm conf alias loader
	sco_manager_path=/home/user/work/projects/mygithub/BASM/sco_manager.sh
	sco_manager_conf_directory=/home/user/work/config-tools/sm-config-default
	# default shortcut for the calling symfony manager without any conf files
	alias sm_='$sco_manager_path'
	for conffile in `ls $sco_manager_conf_directory`; do
		project_name=${conffile/sm-config-}
		alias sm_$project_name="$sco_manager_path -l $sco_manager_conf_directory/$conffile"
	done
	
I tend to prefix my configuraiton files with sm-config-<project_name>, but this is not mandatory, and the alias shortcut will be sm_<project_name> <OPTIONS>


Integrate with Composer
=======================

1)Define a repository, as BASM is not yet in Packagist
```
    "repositories": [
    {
        "type": "package",
        "package": {
            "version": "master",
            "name": "jmeyo/BASM",
            "source": {
                "url": "https://github.com/jmeyo/BASM",
                "type": "git",
                "reference": "master"
            },
            "dist": {
                "url": "https://github.com/jmeyo/BASM/zipball/master",
                "type": "zip"
            }
        }
    }
    ],
```  

2) Add the following line to your Symfony2 composer.json file:

	{
		"require": {
			/* other libs */
			"jmeyo/BASM": "dev-master"
		}
	}

3) Update composer
	php /usr/local/bin/composer.phar update

