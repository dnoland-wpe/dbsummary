#!/bin/bash

# Author: David T. Noland
# Title: Database Summary Report
# Version: 1.2
# Command: dbsummary

function dbsummary() {
# Obtain directory and define variables
   install=$(pwd | cut -d'/' -f5)
   env=$(pwd | cut -d'/' -f4)
   db=$(grep -i db_name /nas/content/$env/$install/wp-config.php | cut -d"'" -f4)
   totalMB=$(wp db query "SELECT SUM(round(((data_length + index_length) / 1024 / 1024),2)) as 'Total_DB_Size' FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE';" | tail -1)
   rows=$(wp db query "SELECT SUM(table_rows) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE';" | tail -1)
   tables=$(wp db query "SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE';" | tail -1)
   myi=$(wp db query "SELECT COUNT(Engine) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='MyISAM';" | tail -1)
   inno=$(wp db query "SELECT COUNT(Engine) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='InnoDB';" | tail -1)
   myirows=$(wp db query "SELECT SUM(table_rows) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='MyISAM';" | tail -1)
   innorows=$(wp db query "SELECT SUM(table_rows) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='InnoDB';" | tail -1)

# output layout header 
   printf "\n${purple}Install name: ${yellow}%-20s ${purple}Database name: ${yellow}%-20s ${purple}Total database size: ${yellow}%s MB${NC}\n" ${install} ${db} ${totalMB}
   printf "${purple}MyISAM tables: ${yellow}%-19s ${purple}InnoDB tables: ${yellow}%-20s ${purple}Total tables: ${yellow}%s ${NC}\n" ${myi} ${inno} ${tables}
   printf "${purple}MyISAM rows: ${yellow}%-21s ${purple}InnoDB Rows: ${yellow}%-22s ${purple}Total rows: ${yellow}%s ${NC}\n\n" ${myirows} ${innorows} ${rows}
   echo ""

echo -e "${purple}Database tables sorted by table size: ${NC}${yellow}${db}${NC}"
# Body of report
   wp db query "SELECT TABLE_NAME as 'Table', Engine, table_rows as 'Rows', data_length as 'Data_size_in_MB', index_length as 'Index_size_in_MB', round(((data_length + index_length) / 1024 / 1024),2) as 'Total_size_MB' FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' ORDER BY Engine, Total_size_MB DESC;"

## MyISAM -> InnoDB conversion check

#    if [[ "$myi" -gt 0 ]] ; then {
#      echo -e "\n${yellow}You have ${NC}${red}$myi MyISAM tables${NC}${yellow} in your database."
#      read "Did you want to convert them to InnoDB? [y/n]${NC}" convert
#      if [ "$convert" =~ "y" ]; then {
#        echo "Backing up database and moving to _wpeprivate"
#        wp db export && mv -v ${db}.sql _wpeprivate/;
#        echo "Database backup for ${db}.sql is now in _wpeprivate folder."
#        echo "Converting MyISAM tables to InnoDB..."
#        wp db query "show table status where engine = 'MyISAM';" | awk '{print $1}' | while read tbl;
#          do echo "Converting $tbl..." && wp db query "ALTER TABLE $table ENGINE=InnoDB;";
#          printf "${purple}MyISAM tables: ${yellow}%-19s ${purple}InnoDB tables: ${yellow}%-20s ${purple}Total tables: ${yellow}%s ${NC}\n" ${myi} ${inno} ${tblCount};
#          done
#        }
#      else echo -e "${yellow}Have a great day!"
#      fi;
#    }
#  fi;

}

