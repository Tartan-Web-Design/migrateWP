# MigrateWP
[www.migratewp.org](https://migratewp.org)


## What is MigrateWP?

MigrateWP is a command line utility that lets you migrate a Wordpress site from a macOS [Local](https://www.localwp.com)
 development environment to a Linux server with a single command. It is open source software released by [Tartan Web Design](https://tartanwebdesign.net) under the GPLv2 licence. 



## Who is MigrateWP for?

MigrateWP was built for Wordpress Developers who are comfortable working on the command line. It is most useful for freelancers and agencies who manage multiple Wordpress sites. 

## Why use MigrateWP?

### It’s fast. 

MigrateWP only transfers files that have changed, reducing the time it takes to migrate a site    by as much as 95%. 


### It’s effortless

MigrateWP lets you migrate your WordPress sites without the need to log in to them.  Simply open the terminal and run a single command. That’s it!      

### It’s robust

Our Rollback feature lets you quickly undo a migration in the event something goes wrong. Additionally, Search & Replace is performed using WP CLI, meaning array serialisation is handled correctly.  

### It's collaborative

MigrateWP’s changelog provides a record of all the migrations to and from a remote site. This provides teams with more visibility and reduces the likelihood of merge conflicts.

## How to use MigrateWP

MigrateWP has four commands, push, pull, rollback & report.

**Push**

The push command migrates a site from your local to machine to a remote server 

`mwp pull sitename`

**Pull**

The pull command migrates a site from the remote server to your local machine

`mwp push sitename`

**Rollback**

The rollback command allows you to undo the last push or pull

`mwp rollback sitename`

**Report**

The report command displays the migration history for the site you specify

`mwp report sitename`


## How to setup MigrateWP

### 1. Download the latest MigrateWP release

Download latest release here: 

https://github.com/Tartan-Web-Design/migrateWP/releases

Open terminal and `cd` into the folder containing migrateWP

Create an alias:

`echo "alias mwp="bash /Users/username/**yourfolder**/MigrateWP.sh" >> ~/.zsh`

Then restart your terminal session

`exec zsh` 

For further information see our [Documentation](https://migratewp.org/docs)

  ---

  
### 2. Edit MigrateWP.conf 

Each site in the config will look something like this
```
#! /bin/bash

logUserName="yourNameHere"

case $site in

    site1name)
        sshUser="username@8.8.8.8"

        remoteURL="example.com"
        remotePath="/var/www/vhosts/example.com/httpdocs/wp-content/"
        localURL="example.local"
        localPath="/Users/Scott/Local Sites/example/app/public/wp-content/"

    ;;

    site2name)
        sshUser="sshUser@8.8.8.8"

        remoteURL="site2.org"
        remotePath="/var/www/vhosts/site2.org/httpdocs/wp-content/"
        localURL="site2.local"
        localPath="/Users/Scott/Local Sites/site2/app/public/wp-content/"

    ;;

  *)
      usage
      exit
    ;;

  esac
```

Enter your name in 'yourNameHere'.  This will be used to log events coming from your local machine.

Replace ‘site1name’ with the name you want to use to reference your site   

In 'sshUser', enter an SSH user with permissions over the folder which holds your WordPress installation. 

If you are using Plesk, this will be the systemUser for the plesk webspace. (This user can be found at: subscriptions>sitename>Connection Info)
 
E.g `username@8.8.8.8`


Finally, enter the file path to the wp-content folder on the local and remote servers



---

### 3. (Optional) Configure SSH Access 

MigrateWP accesses the remote server numerous times and so it will be helpful to add a key to your SSH account.

If you are using Plesk this can be done by

1. Installing the ‘SSH Keys Manager’ Plesk extension 

2. Copying your local public SSH key 
 
 `cat ~/.ssh/id_rsa.pub`
 
 Pasting the public key into the Plesk SSH keys page for this website. The Plesk SSH keys page can be found at (subscriptions>sitename>SSH Keys)
 

3. Setting ‘Access to the server over SSH’ to /bin/sh (subscriptions>sitename>Connection Info-> Manage access)

NB, you don't need to set up separate ssh sub-domains, as on Plesk at least, the credentials are the same as the main domain.



## System Requirements

MacOS (Local server)

Linux (Remote server)

## Dependencies

### Local machine

1. WP CLI 2.4.0
2. Rsync 2.6.9

### Remote server

1. SSH user
2. WP CLI 2.4.0
3. Rsync 2.6.9
