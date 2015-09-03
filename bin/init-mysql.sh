#! /bin/bash

##
#
# This script will initialize the MySql database for 
# Jira, Confluence and Bamboo
#
##

source $STACI_HOME/functions/tools.f

function exec_sql(){
   local pw=$1
   local sqlcmd=$2
   mySqlIp=$(getContainerIP atlassiandb)
   mysql --host="$mySqlIp" --port="3306" --user=root --password=$pw -e "$sqlcmd"
}

# Find out what to init
start_jira=$(getProperty "start_jira")
start_confluence=$(getProperty "start_confluence")
start_bamboo=$(getProperty "start_bamboo")
mysql_root_pass=$(getProperty "mysql_root_pass")

if [ "$start_jira" == "1" ]; then
   echo " - Setting up MySQL for Jira"
   jira_username=$(getProperty "jira_username")
   jira_password=$(getProperty "jira_password")
   jira_database=$(getProperty "jira_database_name")

   exec_sql $mysql_root_pass "CREATE USER '$jira_username'@'%' IDENTIFIED BY '$jira_password';"
   exec_sql $mysql_root_pass "CREATE DATABASE $jira_database CHARACTER SET utf8 COLLATE utf8_bin;"
   exec_sql $mysql_root_pass "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER,INDEX on $jira_database.* TO '$jira_username'@'%';"
   exec_sql $mysql_root_pass "FLUSH PRIVILEGES;"

   echo "*** Use the following to setup Jira db connection ***
- Database Type : MySQL
- Hostname : 192.168.0.175  (docker host ip)
- Port : 3306
- Database : $jira_database
- Username : $jira_username
- Password : $jira_password
   "
fi

if [ "$start_confluence" == "1" ]; then
   echo " - Setting up MySQL for Confluence"
   confluence_username=$(getProperty "confluence_username")
   confluence_password=$(getProperty "confluence_password")
   confluence_database=$(getProperty "confluence_database_name")

   exec_sql $mysql_root_pass "CREATE DATABASE $confluence_database CHARACTER SET utf8 COLLATE utf8_bin;"
   exec_sql $mysql_root_pass "GRANT ALL PRIVILEGES ON $confluence_database.* TO '$confluence_username'@'%' IDENTIFIED BY '$confluence_password';"
   exec_sql $mysql_root_pass "FLUSH PRIVILEGES;"

   echo "*** Use the following to setup Bamboo db connection ***
- Install type : Production install
- Database Type : MySQL
- Connection : Direct JDBC
- Driver Class Name : com.mysql.jdbc.Driver
- Database URL : jdbc:mysql://192.168.0.175/$confluence_database?sessionVariables=storage_engine%3DInnoDB&useUnicode=true&characterEncoding=utf8
- User Name : $confluence_username
- Password : $confluence_password
   "
fi

if [ "$start_bamboo" == "1" ]; then
   echo " - Setting up MySQL for Bamboo"
   bamboo_username=$(getProperty "bamboo_username")
   bamboo_password=$(getProperty "bamboo_password")
   bamboo_database=$(getProperty "bamboo_database_name")

   exec_sql $mysql_root_pass "CREATE DATABASE $bamboo_database CHARACTER SET utf8 COLLATE utf8_bin;"
   exec_sql $mysql_root_pass "GRANT ALL PRIVILEGES ON $bamboo_database.* TO '$bamboo_username'@'%' IDENTIFIED BY '$bamboo_password';"
   exec_sql $mysql_root_pass "FLUSH PRIVILEGES;"

   echo " *** Use the following to setup Bamboo db connection ***
- Install type : Production install
- Select database : External MySQL
- Connection : Direct JDBC
- Database URL : jdbc:mysql://192.168.0.175/$bamboo_database?autoReconnect=true
- User name : $bamboo_username
- Password : $bamboo_password
- Overwrite Existing data : Yes, if you want
   "
fi

