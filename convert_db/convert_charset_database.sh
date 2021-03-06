#!/bin/bash

# Carlos Smaniotto
# carlos.smaniotto@datapower.com.br
# https://github.com/csmanioto/

# This script will export and convert charset of database´s data.
# Important: Export and Import data only! You need prepar the new mysql to do it.
# I recommend the use of clean_export_structure.sh to  help you to do this task.
# https://raw.githubusercontent.com/csmanioto/mysql_scripts/master/clean_export_structure.sh
# Remember of set the variables in your my.cnf :
# - character_set_server
# - character_set_client
# - character_set_results
# - collation_connection
# With your $DESTINATION_MYSQL_CHARSET and $DESTINATION_MYSQL_COLLATE


##############################################################
# Your source environment setings in file user_variables.cfg #
##############################################################


#########################################
# imutable variables                    #
# Don´t change code below..             #
#########################################
BASEDIR="${PWD}"
if [ -f ${BASEDIR}/user_variables.cfg ]; then
  source ${BASEDIR}/user_variables.cfg
  echo "Variables loaded"
else
  echo "${BASEDIR}/user_variables.cfg not found."
  exit 1
fi

if [ ! -d "$FILE_DESTINANTIO_PATH" ]; then
    mkdir -p ${FILE_DESTINANTIO_PATH}
fi

DATE=$(date +%Y-%m-%d)
ERROR_LOG="${FILE_DESTINANTIO_PATH}/error_${DATE}.log"
STATUS_LOG="${FILE_DESTINANTIO_PATH}/status_${DATE}.log"

#Variables of SOURCE DATABASE - MySQLDUMP
SRC_LOGIN="-u ${SOURCE_MYSQL_USER} -p${SOURCE_MYSQL_PASSWORD}"
SRC_HOST="-h ${SOURCE_MYSQL_ENDPOINT}"
SOURCE_MYSQL_CHARSET=$(echo ${SOURCE_MYSQL_CHARSET} | tr '[:upper:]' '[:lower:]' )
SOURCE_ICONV_CHARSET=$(echo ${SOURCE_MYSQL_CHARSET} | tr '[:lower:]' '[:upper:]' )
MYSQLDUMP_OPTIONS="--default-character-set=${SOURCE_MYSQL_CHARSET} --disable-keys --skip-triggers --no-create-info --single-transaction --no-set-names  " # --complete-insert --skip-extended-insert
MYSQLDUMP_PARAMETERS="${SRC_LOGIN} ${SRC_HOST} ${MYSQLDUMP_OPTIONS} "

#Variables of destinantion - MySQL (Import)
DST_LOGIN="-u ${DESTINATION_MYSQL_USER} -p${DESTINATION_MYSQL_PASSWORD}"
DST_HOST="-h ${DESTINATION_MYSQL_ENDPOINT}"
DESTINATION_MYSQL_CHARSET=$(echo ${DESTINATION_MYSQL_CHARSET} | tr '[:upper:]' '[:lower:]' )
DESTINATION_MYSQL_COLLATE=$(echo ${DESTINATION_MYSQL_COLLATE} | tr '[:upper:]' '[:lower:]' )
DESTINATION_ICONV_CHARSET=$(echo ${DESTINATION_MYSQL_CHARSET} | tr '[:lower:]' '[:upper:]' )

MYSQL_OPTIONS="--default-character-set=${DESTINATION_MYSQL_CHARSET}"
MYSQL_PARAMTERS="${DST_LOGIN} ${DST_HOST} ${MYSQL_OPTIONS} "


export_data(){
    ###########################################
    # Start of export algorithim              #
    ###########################################
    echo "--------------------------------------" > ${STATUS_LOG}
    echo "--------------------------------------" > ${ERROR_LOG}
    NEW_DATE=$(date "+%Y-%m-%d %H:%M:%S")
    echo "${NEW_DATE}:  +++ START PROCESS "  | tee -a ${STATUS_LOG}

    for db in ${MYSQL_DATABASES_LIST};
    do
        NEW_DATE=$(date "+%Y-%m-%d %H:%M:%S")
        echo "${NEW_DATE}: Exporting database ${db}..."  | tee -a ${STATUS_LOG}
        ORIGINAL_FILE="${FILE_DESTINANTIO_PATH}/${db}_dataonly_${SOURCE_MYSQL_CHARSET}_${DATE}.sql"
        CONVERTED_FILE="${FILE_DESTINANTIO_PATH}/${db}_dataonly_${DESTINATION_MYSQL_CHARSET}_${DATE}.sql"

        if mysqldump ${MYSQLDUMP_PARAMETERS} ${db} -r ${ORIGINAL_FILE}; then
          if iconv -f ${SOURCE_ICONV_CHARSET} -t ${DESTINATION_ICONV_CHARSET}  ${ORIGINAL_FILE} > ${CONVERTED_FILE}; then
            #sed -e "s/SET NAMES ${SOURCE_MYSQL_CHARSET}/SET NAMES ${DESTINATION_MYSQL_CHARSET}/g" -i ${CONVERTED_FILE}
            #sed -e "s/CHARSET=latin1/CHARSET=${DESTINATION_MYSQL_CHARSET} COLLATE=${DESTINATION_MYSQL_COLLATE}/g" -i ${CONVERTED_FILE}
            # apply custom Filters
            rm -f ${ORIGINAL_FILE}
            if [ -f ${BASEDIR}/convert_charset_database_afterdump_custom.cmd ]; then
                echo "Using a custom filter..."
                source ${BASEDIR}/convert_charset_database_afterdump_custom.cmd
            fi
          else
            echo "${NEW_DATE}: Error on iconv of ${db} " | tee -a ${ERROR_LOG}
            echo "${NEW_DATE}:  +++ END PROCESS WITH ERROR.. SEE ${ERROR_LOG} "  | tee -a ${STATUS_LOG}
            exit 1
          fi
        else
          echo "${NEW_DATE}: Error on mysqldump of ${db} " | tee -a ${ERROR_LOG}
          echo "${NEW_DATE}:  +++ END PROCESS WITH ERROR.. SEE ${ERROR_LOG} "  | tee -a ${STATUS_LOG}
          exit 1
        fi
    done
}


import_data(){
    NEW_DATE=$(date "+%Y-%m-%d %H:%M:%S")
    echo "${NEW_DATE}: IMPORTING PROCESSS.."  | tee -a ${STATUS_LOG}
    echo "---------------------------------"  | tee -a ${STATUS_LOG}

    echo "${NEW_DATE}: IMPORTING database ${db}..."  | tee -a ${STATUS_LOG}

    #
    # Investigar o problema do pq não importou...
    # Tratar erro no final:
    #ERROR 1231 (42000): Variable 'time_zone' can't be set to the value of 'NULL'
    #ERROR 1231 (42000): Variable 'sql_mode' can't be set to the value of 'NULL'
    #ERROR 1231 (42000): Variable 'foreign_key_checks' can't be set to the value of 'NULL'
    #ERROR 1231 (42000): Variable 'unique_checks' can't be set to the value of 'NULL'
    #ERROR 1231 (42000): Variable 'sql_notes' can't be set to the value of 'NULL'

    for db in ${MYSQL_DATABASES_LIST};
    do
      NEW_DATE=$(date "+%Y-%m-%d %H:%M:%S")
      echo "${NEW_DATE}: IMPORTING database ${db}..."  | tee -a ${STATUS_LOG}
      CONVERTED_FILE="${FILE_DESTINANTIO_PATH}/${db}_dataonly_${DESTINATION_MYSQL_CHARSET}_${DATE}.sql"
      DB_LOG="${FILE_DESTINANTIO_PATH}/${db}.log"

      if mysql ${MYSQL_PARAMTERS} --tee=$DB_LOG  $db -e "SET @FOREIGN_KEY_CHECKS = FALSE; SET @TRIGGER_CHECKS = FALSE;source ${CONVERTED_FILE};"; then
        NEW_DATE=$(date "+%Y-%m-%d %H:%M:%S")
        echo "${NEW_DATE}: ${db} IMPORTED WITH SUCCESSFUL"  | tee -a ${STATUS_LOG}
      else
        NEW_DATE=$(date "+%Y-%m-%d %H:%M:%S")
        echo "${NEW_DATE}: Error on import ${db} " | tee -a ${ERROR_LOG}
        echo "${NEW_DATE}:  +++ END PROCESS WITH ERROR.. SEE ${ERROR_LOG} "  | tee -a ${STATUS_LOG}
        exit 1
      fi
    done

    NEW_DATE=$(date "+%Y-%m-%d %H:%M:%S")
    echo "${NEW_DATE}:  +++ END PROCESS "  | tee -a ${STATUS_LOG}
}


show_menus() {
  	clear
  	echo "~~~~~~~~~~~~~~~~~~~~~"
  	echo " M A I N - M E N U"
  	echo "~~~~~~~~~~~~~~~~~~~~~"
    echo "Before continue, please edit user_variables.cfg with your setings."
    echo "For custom command (sed for exemple):"
    echo " -> You can do it using the file: convert_charset_database_afterdump_custom.cmd"
  	echo "1. Export Data and Import"
  	echo "2. Export Only"
  	echo "3. Import Only"
    echo "4. EXIT"
}

read_options(){
  	local choice
  	read -p "Enter choice [ 1 - 4] " choice
  	case $choice in
  		1) export_data && import_data ;;
  		2) export_data ;;
      3) import_data ;;
  		4) exit 0;;
  		*) echo -e "${RED}Error...${STD}" && sleep 2
  	esac
}


# ----------------------------------------------
# Step #3: Trap CTRL+C, CTRL+Z and quit singles
# ----------------------------------------------
trap '' SIGINT SIGQUIT SIGTSTP

# -----------------------------------
# Step #4: Main logic - infinite loop
# ------------------------------------
while true
do
	show_menus
	read_options
done
