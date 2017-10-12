Last login: Thu Oct 12 10:36:21 on ttys000
# Author: David T. Noland
# Title: Database Summary Report
# Version: 1.0
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
echo -e "${purple}Install name: ${NC}${yellow}${install}${NC}\t\t${purple}Database name: ${NC}${yellow}${db}${NC}\t\t${purple}Total database size: ${NC}${yellow}${totalMB} MB${NC}"
echo -e "${purple}MyISAM tables: ${yellow}${myi}${NC}\t\t${purple}InnoDB tables: ${NC}${yellow}${inno}${NC}\t\t\t${purple}Total tables: ${NC}${yellow}${tables}${NC}"
echo -e "${purple}MyISAM rows: ${NC}${yellow}${myirows}${NC}\t\t\t${purple}InnoDB Rows: ${yellow}${innorows}${NC}\t\t\t${purple}Total rows: ${NC}${yellow}${rows}${NC}"
echo ""

echo -e "${purple}Database tables sorted by table size: ${NC}${yellow}${db}${NC}"
# Body of report
   wp db query "SELECT TABLE_NAME as 'Table', Engine, table_rows as 'Rows', data_length as 'Data_size_in_MB', index_length as 'Index_size_in_MB', round(((data_length + index_length) / 1024 / 1024),2) as 'Total_size_MB' FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' ORDER BY Engine, Total_size_MB DESC;"
}
