#!/bin/bash

# Author: David T. Noland
# Title: Database Summary Report
# Version: 1.0beta
# Command: dbsummary

function dbsummary() {
# Obtain directory and define variables
   install=$(pwd | cut -d'/' -f5)
   env=$(pwd | cut -d'/' -f4)
   db=$(grep -i db_name /nas/content/$env/$install/wp-config.php | cut -d"'" -f4)

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

#Calculating key optimization variables
   revisions=$(wp db query "SELECT COUNT(*) as row_count FROM wp_posts WHERE post_type = 'revision';" | tail -1)
   trash_posts=$(wp db query "SELECT COUNT(*) as row_count FROM wp_posts WHERE post_type = 'trash';" | tail -1)
   spam_comments=$(wp db query "SELECT COUNT(*) as row_count FROM wp_comments WHERE comment_approved = 'spam';" | tail -1)
   trash_comments=$(wp db query "SELECT COUNT(*) as row_count FROM wp_comments WHERE comment_approved = 'trash';" | tail -1)
   orphaned_postmeta=$(wp db query "SELECT COUNT(pm.meta_id) as row_count FROM wp_postmeta pm LEFT JOIN wp_posts wp ON wp.ID = pm.post_id WHERE wp.ID IS NULL;" | tail -1)
   orphaned_commentmeta=$(wp db query "SELECT COUNT(*) as row_count FROM wp_commentmeta WHERE comment_id NOT IN (SELECT comment_id FROM wp_comments);" | tail -1)
   transients=$(wp db query "SELECT COUNT(*) as row_count FROM wp_options WHERE option_name LIKE ('%\_transient\_%%');" | tail -1)

# output layout header
   printf "\n${teal}Install name: ${yellow}%-20s ${teal}Database name: ${yellow}%-20s ${teal}Total database size: ${yellow}%s MB${NC}\n\n" ${install} ${db} ${totalMB}
   echo -e "${red}Tables and Rows counts:${NC}"
   printf "${teal}MyISAM tables: ${yellow}%-19s ${teal}InnoDB tables: ${yellow}%-20s ${teal}Total tables: ${yellow}%s ${NC}\n" ${myi} ${inno} ${tblCount}
   printf "${teal}MyISAM rows: ${yellow}%-21s ${teal}InnoDB Rows: ${yellow}%-22s ${teal}Total rows: ${yellow}%s ${NC}\n\n" ${myirows} ${innorows} ${rows}
   echo -e "${red}Key optimization counts:${NC}"
   printf "${teal}Revisions: ${yellow}%-23s ${teal}Trashed Posts: ${yellow}%-20s ${teal}Orphaned Postmeta: ${yellow}%s ${NC}\n" ${revisions} ${trash_posts} ${orphaned_postmeta}
   printf "${teal}Spam Comments: ${yellow}%-19s ${teal}Trashed Comments: ${yellow}%-17s ${teal}Orphaned Commentmeta: ${yellow}%s ${NC}\n" ${spam_comments} ${trash_comments} ${orphaned_commentmeta}
   printf "${teal}Transients: ${yellow}%-21s ${NC}\n\n" ${transients}
   echo -e "${teal}Database tables sorted by table size: ${NC}${yellow}${db}${NC}"

# Body of report
   wp db query "SELECT TABLE_NAME as 'Table', Engine, table_rows as 'Rows', data_length as 'Data_size_in_MB', index_length as 'Index_size_in_MB', round(((data_length + index_length) / 1024 / 1024),2) as 'Total_size_MB' FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' ORDER BY Engine, Total_size_MB DESC;"

}
#EOF
