#!/bin/bash

function dbsummary() {

  local description='produces a high level summary of key WordPress database optimization values, along with recommendations for variables that are impacting site performance.'
  local sorter='table_rows'
  [[ "$@" =~ '--rows' ]] || [[ "$@" =~ '-r' ]] && sorter='table_rows'
  [[ "$@" =~ '--size' ]] || [[ "$@" =~ '-s' ]] && sorter='Total_size_MB'
  [[ "$@" =~ '--help' ]] || [[ "$@" =~ '-h' ]] && {
    echo -e "${yellow}dbsummary${NC} ${description}\n"
    echo "dbsummary <table-sort>"
    echo -e "\nAvailable flags for table sort:"
    echo -e "\t--rows, -r (default)"
    echo -e "\t--size, -s (output in MB)"
    return
  }

  # Colors
  red='\x1b[0;31m'
  yellow='\x1b[0;33m'
  green='\x1b[0;32m'
  teal='\x1b[0;36m'
  blue='\x1b[0;34m'
  purple='\x1b[0;35m'
  NC='\x1b[0m' # No Color
  uline='\e[4m' # Underline
  nuline='\e[0m' # No Underline

  #Obtain directory and define variables
  local install="$(cut -d'/' -f5 <<< ${PWD})"
  [[ ${install} == "" ]] && {
    echo "This command needs to be run within an install's directory."
    echo -e "Please ${yellow}cd${NC} there and try again."
    return 1
  }

  #define database and environment variables
  local env="$(cut -d'/' -f4 <<< ${PWD})"
  local db="$(grep -i db_name /nas/content/$env/$install/wp-config.php | cut -d"'" -f4)"
  local table_prefix="$(grep -i table_prefix /nas/content/$env/$install/wp-config.php | cut -d"'" -f2)"
  local version="$(wp core version)"

  # Proceed with report
  echo -e "${teal}Compiling database summary report..."
  echo -e "Thank you for your patience."

  #Set "wp db query" variable
  local WPDB="wp db query --skip-plugins --skip-themes"

  #Calculating BASE TABLE counts
  local totalMB="$(${WPDB} "SELECT SUM(round(((data_length + index_length) / 1024 / 1024),2)) as 'Total_DB_Size' FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE';" | tail -1)"
  local unroundedTotalMB="$(${WPDB} "SELECT SUM(data_length + index_length) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE';" | tail -1)"
  local rows="$(${WPDB} "SELECT SUM(table_rows) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE';" | tail -1)"
  local tblCount="$(${WPDB} "SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE';" | tail -1)"
  local myi="$(${WPDB} "SELECT COUNT(Engine) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='MyISAM';" | tail -1)"
  local inno="$(${WPDB} "SELECT COUNT(Engine) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='InnoDB';" | tail -1)"
  local myirows="$(${WPDB} "SELECT SUM(table_rows) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='MyISAM';" | tail -1)"
  local innorows="$(${WPDB} "SELECT SUM(table_rows) FROM information_schema.TABLES WHERE table_schema = '${db}' and TABLE_TYPE='BASE TABLE' and Engine='InnoDB';" | tail -1)"
  local autoload="$(${WPDB} "SELECT SUM(LENGTH(option_value)) FROM ${table_prefix}options WHERE autoload = 'yes';" | tail -1)"

  #Determining Multisite configuration
  local multi="$(awk '/[^_]MULTISITE/ {print toupper($3)}' /nas/content/$env/$install/wp-config.php)"

  #Calculating key optimization variables
  local revisions="$(${WPDB} "SELECT COUNT(*) as row_count FROM ${table_prefix}posts WHERE post_type = 'revision';" | tail -1)"
  local trash_posts="$(${WPDB} "SELECT COUNT(*) as row_count FROM ${table_prefix}posts WHERE post_type = 'trash';" | tail -1)"
  local spam_comments="$(${WPDB} "SELECT COUNT(*) as row_count FROM ${table_prefix}comments WHERE comment_approved = 'spam';" | tail -1)"
  local trash_comments="$(${WPDB} "SELECT COUNT(*) as row_count FROM ${table_prefix}comments WHERE comment_approved = 'trash';" | tail -1)"
  local orphaned_postmeta="$(${WPDB} "SELECT COUNT(pm.meta_id) as row_count FROM ${table_prefix}postmeta pm LEFT JOIN ${table_prefix}posts wp ON wp.ID = pm.post_id WHERE wp.ID IS NULL;" | tail -1)"
  local orphaned_commentmeta="$(${WPDB} "SELECT COUNT(*) as row_count FROM ${table_prefix}commentmeta WHERE comment_id NOT IN (SELECT comment_id FROM ${table_prefix}comments);" | tail -1)"
  local transients="$(${WPDB} "SELECT COUNT(*) as row_count FROM ${table_prefix}options WHERE option_name LIKE ('%\_transient\_%%');" | tail -1)"

  # output layout header
  printf "\n${teal}Install name: ${green}%-20s ${teal}Database name: ${green}%-20s ${teal}Total database size: ${green}%s MB${NC}\n" ${install} ${db} ${totalMB}
  echo -e "${teal}WordPress core version: ${green}${version}${NC}"

  #Multisite check
  if [[ $multi = "TRUE" ]];
  then
    local subsite_count="$(${WPDB} "SELECT COUNT(*) FROM ${table_prefix}blogs WHERE blog_id > 1;" | tail -1)"
    printf "${teal}Multisite: ${green}%-24s${teal}Number of subsites: ${green}%-16s${NC}\n" ${multi} ${subsite_count}
  fi
  # Display following recommendations if database contains more than 200MB of data
  [[ ${unroundedTotalMB} -gt 200000000 ]] && {
    echo -e "\n${red}Recommendations:${NC}"
    echo -e "Execute ${yellow}du -h --max-depth=1 /var/lib/mysql/${db}${NC} and compare to ${yellow}Total database size${NC}. "
    echo -e "If ${yellow}MySQL disk usage${NC} is inordinately larger than ${yellow}Total database size${NC}, recommend excuting ${yellow}mysqlcheck -o ${db}${NC}."
  }

  #Tables and row counts and recommendations
  echo -e "\n${red}Tables and Rows counts:${NC}"
  printf "${teal}MyISAM tables: ${green}%-19s ${teal}InnoDB tables: ${green}%-20s ${teal}Total tables: ${green}%s ${NC}\n" ${myi} ${inno} ${tblCount}
  printf "${teal}MyISAM rows: ${green}%-21s ${teal}InnoDB Rows: ${green}%-22s ${teal}Total rows: ${green}%s ${NC}\n\n" ${myirows} ${innorows} ${rows}

  echo -e "${red}Recommendations:${NC}"
  [[ ${myi} -gt 0 ]] \
    && echo -e "${red}Recommend convert MyISAM tables to InnoDB.${NC}" \
    || echo -e "${green}No ${yellow}storage engine${green} recommendations to make."
  [[ ${rows} -gt 1000000 ]] && echo -e "${red}Review table row distributions.${NC}"

  #Conditional checks for key optimization counts
  local totalCounts="$(($revisions+$trash_posts+$orphaned_postmeta+$spam_comments+$trash_comments+$orphaned_commentmeta))"
  local obj_cache="$(wpephp option-get-json ${install} use_object_cache)"
  [[ ${totalCounts} -gt 6000 ]] && {
    #Key Optimization counts and recommendations
    echo -e "\n${red}Key optimization counts:${NC}"
    printf "${teal}Revisions: ${green}%-23s ${teal}Trashed Posts: ${green}%-20s ${teal}Orphaned Postmeta: ${green}%s ${NC}\n" ${revisions} ${trash_posts} ${orphaned_postmeta}
    printf "${teal}Spam Comments: ${green}%-19s ${teal}Trashed Comments: ${green}%-17s ${teal}Orphaned Commentmeta: ${green}%s ${NC}\n" ${spam_comments} ${trash_comments} ${orphaned_commentmeta}

    #Conditional display of autoload colorized based on thresholds
    printf "${teal}Transients: ${green}%-22s ${NC}\n" ${transients}

    #Positive optimization values and object caching test
    echo
    [[ ${totalCounts} -lt 6000 ]] && echo -e "${green}Key optimation value counts below analysis threshold.${NC}"
    [[ ${obj_cache} == 'false' ]] && echo -e "${yellow}Object caching${green} is disabled.${NC}"
    [[ ${obj_cache} == 'true' ]] \
      && echo -e "${yellow}Object caching${green} is enabled.${NC}" \
      || echo -e "${yellow}Object caching${green} is disabled.${NC}"
    [[ ${autoload} -gt 800000 ]] && echo -e "${green}Core version: ${yellow}${version} ${green}(Beginning with WP Core version 4.9, the core will automatically remove expired transients.)${NC}"

    #Recommendations if total optimization value count is over 6000 (combined total based on average 1000 per value)
    [[ ${totalCounts} -gt 6000 ]] && {
      echo -e "\n${red}Recommendations:${NC}"
      echo -en "Optimize the following items from OD > Queries (${red}with customer permission${NC}): "
      [[ ${revisions} -gt 0 ]] && echo -n 'Revisions '
      [[ ${trash_posts} -gt 0 ]] && echo -n 'Trashed_Posts '
      [[ ${orphaned_postmeta} -gt 0 ]] && echo -n 'Orphaned_postmeta '
      [[ ${spam_comments} -gt 0 ]] && echo -n 'Spam_comments '
      [[ ${trash_comments} -gt 0 ]] && echo -n 'Trashed_comments '
      [[ ${orphaned_commentmeta} -gt 0 ]] && echo -n 'Orphaned_commentmeta '
      [[ ${transients} -gt 0 ]] && [[ ${obj_cache} == 'true' ]] && echo -n 'Transients '
    }
  }
  #Conditional dbautoload data query output
  echo
  if [[ ${autoload} -gt 800000 ]];
  then
    echo -e "\n${red}Autoload data (in bytes): ${red}${autoload}${NC}"
  elif [[ ${autoload} -gt 500000 ]];
  then
    echo -e "\n${red}Autoload data (in bytes): ${yellow}${autoload}${NC}"
  else
    echo -e "\n${red}Autoload data (in bytes): ${green}${autoload}${NC}"
  fi
  [[ ${autoload} -gt 800000 ]] && {
    echo -e "${teal}Top 5 Autoload items from ${yellow}${table_prefix}options${teal}:${NC}"
    wp db query "SELECT LENGTH(option_value),option_name FROM ${table_prefix}options WHERE autoload='yes' ORDER BY length(option_value) DESC LIMIT 5;" | tail -5  #The tail pipe here is to remove the table structure and header and simply output the bytes and option_name
    echo -e "${red}Execute ${yellow}dbautoload ${red}for full autoload report."
  }

  #Tables sorted by storage engine and sorted by preference report.  Will only display MyISAM tables if present.
  [[ ${myi} -gt 0 ]] && {
    echo -e "\n${teal}Top 20 ${yellow}MyISAM ${teal}database tables sorted by ${sorter}: ${yellow}${db}${NC}"
    ${WPDB} "SELECT TABLE_NAME as 'Table',
    Engine,
    table_rows as 'Rows',
    round(((data_length) / 1024 / 1024),2) as 'Data_size_in_MB',
    round(((index_length) / 1024 / 1024),2) as 'Index_size_in_MB',
    round(((data_length + index_length) / 1024 / 1024),2) as 'Total_size_MB'
    FROM information_schema.TABLES
    WHERE table_schema = '${db}'
      and TABLE_TYPE='BASE TABLE'
      and Engine='MyISAM'
    ORDER BY  ${sorter} DESC LIMIT 20;"
  }

  echo -e "\n${teal}Top 20 ${yellow}InnoDB ${teal}database tables sorted by ${sorter}: ${yellow}${db}${NC}"
  ${WPDB} "SELECT TABLE_NAME as 'Table',
  Engine,
  table_rows as 'Rows',
  round(((data_length) / 1024 / 1024),2) as 'Data_size_in_MB',
  round(((index_length) / 1024 / 1024),2) as 'Index_size_in_MB',
  round(((data_length + index_length) / 1024 / 1024),2) as 'Total_size_MB'
  FROM information_schema.TABLES
  WHERE table_schema = '${db}'
    and TABLE_TYPE='BASE TABLE'
    and Engine='InnoDB'
  ORDER BY ${sorter} DESC LIMIT 20;"
}
