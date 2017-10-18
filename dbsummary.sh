#!/bin/bash

# Author: David T. Noland
# Title: Database Summary Report
# Version: 1.0
# Command: dbsummary

function dbsummary() {
# Obtain directory and define variables
   install=$(pwd | cut -d'/' -f5)
   env=$(pwd | cut -d'/' -f4)
   db=$(grep -i db_name /nas/content/$env/$install/wp-config.php | cut -d"'" -f4)
   table_prefix=$(grep -i table_prefix /nas/content/$env/$install/wp-config.php | cut -d"'" -f2)

   echo -e "${teal}Compiling database summary report..."
   echo -e "Thank you for your patience.${NC}"

# Calculating BASE TABLE counts

   totalMB=$(wp db query "SELECT SUM(round(((data_length + index_length) / 1024 / 1024),2)) as 'Total_DB_Size' FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE';" | tail -1)
   rows=$(wp db query "SELECT SUM(table_rows) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE';" | tail -1)
   tblCount=$(wp db query "SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE';" | tail -1)
   myi=$(wp db query "SELECT COUNT(Engine) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='MyISAM';" | tail -1)
   inno=$(wp db query "SELECT COUNT(Engine) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='InnoDB';" | tail -1)
   myirows=$(wp db query "SELECT SUM(table_rows) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='MyISAM';" | tail -1)
   innorows=$(wp db query "SELECT SUM(table_rows) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='InnoDB';" | tail -1)
   autoload=$(wp db query "SELECT SUM(LENGTH(option_value)) FROM ${table_prefix}options WHERE autoload = 'yes';" | tail -1)

#Determining Multisite configuration
   if [[ $(grep "'MULTISITE'" /nas/content/$env/$install/wp-config.php | awk '{ print $3 }') = "true" ]]
   then
      multisite="TRUE"
   else
      multisite="FALSE"
   fi
#Calculating key optimization variables
   revisions=$(wp db query "SELECT COUNT(*) as row_count FROM ${table_prefix}posts WHERE post_type = 'revision';" | tail -1)
   trash_posts=$(wp db query "SELECT COUNT(*) as row_count FROM ${table_prefix}posts WHERE post_type = 'trash';" | tail -1)
   spam_comments=$(wp db query "SELECT COUNT(*) as row_count FROM ${table_prefix}comments WHERE comment_approved = 'spam';" | tail -1)
   trash_comments=$(wp db query "SELECT COUNT(*) as row_count FROM ${table_prefix}comments WHERE comment_approved = 'trash';" | tail -1)
   orphaned_postmeta=$(wp db query "SELECT COUNT(pm.meta_id) as row_count FROM ${table_prefix}postmeta pm LEFT JOIN ${table_prefix}posts wp ON wp.ID = pm.post_id WHERE wp.ID IS NULL;" | tail -1)
   orphaned_commentmeta=$(wp db query "SELECT COUNT(*) as row_count FROM ${table_prefix}commentmeta WHERE comment_id NOT IN (SELECT comment_id FROM ${table_prefix}comments);" | tail -1)
   transients=$(wp db query "SELECT COUNT(*) as row_count FROM ${table_prefix}options WHERE option_name LIKE ('%\_transient\_%%');" | tail -1)

# output layout header
   printf "\n${teal}Install name: ${yellow}%-20s ${teal}Database name: ${yellow}%-20s ${teal}Total database size: ${yellow}%s MB${NC}\n" ${install} ${db} ${totalMB}

   if [ $multisite = "TRUE" ];
   then {
      echo -e "${teal}Multisite: ${NC}${yellow}${multisite}${NC}"
      echo -e "${teal}Number of subsites: ${NC}$(wp db query "SELECT COUNT(*) FROM ${table_prefix}blogs WHERE blog_id > 1" | tail -1)\n"
    }
   else
      echo -e "${teal}Multisite: ${NC}${yellow}${multisite}${NC}\n"
   fi

   echo -e "${red}Tables and Rows counts:${NC}"
   printf "${teal}MyISAM tables: ${yellow}%-19s ${teal}InnoDB tables: ${yellow}%-20s ${teal}Total tables: ${yellow}%s ${NC}\n" ${myi} ${inno} ${tblCount}
   printf "${teal}MyISAM rows: ${yellow}%-21s ${teal}InnoDB Rows: ${yellow}%-22s ${teal}Total rows: ${yellow}%s ${NC}\n\n" ${myirows} ${innorows} ${rows}
   echo -e "${red}Key optimization counts:${NC}"
   printf "${teal}Revisions: ${yellow}%-23s ${teal}Trashed Posts: ${yellow}%-20s ${teal}Orphaned Postmeta: ${yellow}%s ${NC}\n" ${revisions} ${trash_posts} ${orphaned_postmeta}
   printf "${teal}Spam Comments: ${yellow}%-19s ${teal}Trashed Comments: ${yellow}%-17s ${teal}Orphaned Commentmeta: ${yellow}%s ${NC}\n" ${spam_comments} ${trash_comments} ${orphaned_commentmeta}
   printf "${teal}Transients: ${yellow}%-21s ${NC}" ${transients}

   if [ ${autoload} -gt 800000 ];
    then {
       echo -e "${teal}Autoload data (in bytes): ${NC}${red}${autoload}${NC}"
     }
    else {
       echo -e "${teal} Autoload data (in bytes): ${NC}${yellow}${autoload}${NC}"
   }
   fi

   echo -en  "\n${teal}Sort table listing by ${red}rows (r)${NC}${teal} or ${red}size (s)${NC}${teal} [default = size]? ${NC}${yellow}"
   read table_sort

# Body of report
   if [[ ${table_sort} =~ ^(rows|ROWS|r|R)$ ]];
   then {
     echo -e "${NC}\n${teal}Top 20 ${NC}${yellow}MyISAM${NC}${teal} database tables sorted by row count: ${NC}${yellow}${db}${NC}"
     wp db query "SELECT TABLE_NAME as 'Table', Engine, table_rows as 'Rows', data_length as 'Data_size_in_MB', index_length as 'Index_size_in_MB', round(((data_length + index_length) / 1024 / 1024),2) as 'Total_size_MB' FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='MyISAM' ORDER BY  table_rows DESC LIMIT 20;"
     echo -e "${NC}\n${teal}Top 20 ${NC}${yellow}InnoDB${NC}${teal} database tables sorted by row count: ${NC}${yellow}${db}${NC}"
     wp db query "SELECT TABLE_NAME as 'Table', Engine, table_rows as 'Rows', data_length as 'Data_size_in_MB', index_length as 'Index_size_in_MB', round(((data_length + index_length) / 1024 / 1024),2) as 'Total_size_MB' FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='InnoDB' ORDER BY table_rows DESC LIMIT 20;"
   }
   else {
     echo -e "${NC}\n${teal}Top 20 ${NC}${yellow}MyISAM${NC}${teal} database tables sorted by table size: ${NC}${yellow}${db}${NC}"
     wp db query "SELECT TABLE_NAME as 'Table', Engine, table_rows as 'Rows', data_length as 'Data_size_in_MB', index_length as 'Index_size_in_MB', round(((data_length + index_length) / 1024 / 1024),2) as 'Total_size_MB' FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='MyISAM' ORDER BY Total_size_MB DESC LIMIT 20;"
     echo -e "${NC}\n${teal}Top 20 ${NC}${yellow}InnoDB${NC}${teal} database tables sorted by table size: ${NC}${yellow}${db}${NC}"
     wp db query "SELECT TABLE_NAME as 'Table', Engine, table_rows as 'Rows', data_length as 'Data_size_in_MB', index_length as 'Index_size_in_MB', round(((data_length + index_length) / 1024 / 1024),2) as 'Total_size_MB' FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='InnoDB' ORDER BY Total_size_MB DESC LIMIT 20;"
   }
  fi
}
#EOF
