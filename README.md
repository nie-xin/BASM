BASM
====

Bash Advanced Symfony Manager

Simple tool to manage your Symfony Project


Usage
=====
Launch it like a simple script.

For simple use add it to your path, or better, add a alias (in .bash_aliases for example)

    alias sm="<path_to_your_project>/vendor/jmeyo/BASM/sco_manager.sh"

Then use it like :
    sm -h // show help
    sm -ac // copy assets, and clear cache
    
About configuration
===================

Its possible to load a configuration from several places. 

Either through the -f option, to link with a specific file, or if you just want to work on a specific project, just put a ".sm_config" file in your root directory. A sample ".sm_config" can be found in the default BASM directory

Check `.sm_config` Sample for more information

Integrate with Composer
=======================

1)Define a repository, as BASM is not yet in Packagist
,
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
    

2) Add the following line to your Symfony2 composer.json file:

	{
		"require": {
			/* other libs */
			"jmeyo/BASM": "dev-master"
		}
	}

3) Update composer
	php /usr/local/bin/composer.phar update

