#!/usr/bin/env bash

<< ////

This script is a wrapper that runs and collects the following information by running different collectinfo commands and produces a .tar.gz file.
- Alluxio cluster information
- Environment it is deployed on
- Configuration files
- Logs etc

For more information on collectinfo please see below link
https://docs.alluxio.io/ee/user/stable/en/operation/Troubleshooting.html#alluxio-collectinfo-command

**** Important ****
 - This script assumes Alluxio is in user path
 - It is hardcoded to run in local mode so that we only collect information from the node we want
 - To collect information from different Alluxio nodes (Masters/Workers), run this script individually in the respective nodes.

Usage:
./<filename.sh> -p /path/to/output/directory -c "cluster_info,config,sys_info,logs"

Example Output:
All files archived and ready to collect at: alluxio_info_ip-10-0-2-60.ec2.internal.tar.gz
////

usage() {                                 # Function: Print a help message.
  echo "Usage: $0 -p /path/to/output/directory -c "cluster_info",config,sys_info,logs" 1>&2
}

exit_script() {                         # Function: Exit with error.
  usage
  exit 1
}

clean_dest () {
 printf "\n Running this script will first delete everything under \n ${output_path}\n"
 # todo: Check if directory exists and create of not
 read -p 'Are you sure you want to delete? (Y/N): ' input
 printf "\n selected option: ${input} \n"

 if [[ $input == 'Y' ]]
 then
        printf "\n deleting... \n"
        rm -rf $output_path/*
        printf "\n deleted all contents under ${output_path}/ \n"
 else
        printf "\n exiting script \n"
        exit 1
 fi
}

# This collects cluster information using fsadmin report, getConf
collect_alluxio_info () {
 collect_alluxio_info_file_path=$output_path/collectAlluxioInfo
 printf "\n collecting Alluxio cluster information \n"
 alluxio collectInfo --local collectAlluxioInfo $output_path/
 printf "\n ************  \n"

 cat $collect_alluxio_info_file_path/collectAlluxioInfo.txt | grep -i key

 printf "\n ************  \n"
 printf "\n Above are the configurations that may be sensitive, would you like to delete the displayed configurations before sharing? \n"
 printf "\n If yes the above will be removed from the file and if No everything will be shared \n"

 read -p 'User input (Y/N): ' input
 if [[ $input == 'N' ]]
 then
        printf "\n You have chosen not to delete - All configurations will be shared "
 elif [[ $input == 'Y' ]]
 then
        printf "\nStart deleting\n"
        cat $collect_alluxio_info_file_path/collectAlluxioInfo.txt | grep -v -i key > $collect_alluxio_info_file_path/CollectALluxioInfo_ConfKeysRemoved.txt
        printf "\n Removed congurations that may contain sensitive information\n"
        printf "\n New AlluxioConf file is at: ${collect_alluxio_info_file_path}/CollectALluxioInfo_ConfKeysRemoved.txt \n"
        printf "\n Removing original file \n"
        rm -f ${collect_alluxio_info_file_path}/collectAlluxioInfo.txt
        printf "\n Original file removed\n"
 else
        printf "\n You have chosen not to delete - All configurations will be shared "
 fi
}


# This collects all config files under $ALLUXIO_HOME/conf/ except alluxio-site.properties
collect_config_files () {
 printf "\n Collecting all files under \$ALLUXIO_HOME/conf/ except alluxio-site.properties \n"
 alluxio collectInfo --local collectConfig $output_path/
 printf "\n Completed collecting Alluxio configs"
}

# This will collect logs
collect_logs () {
 printf "\n Collecting all logs \n"
 alluxio collectInfo --local collectLog $output_path/
 printf "\n Completed collecting logs \n"
}

# This will extract the alluxio clustrer host related infoirmation
collect_sys_info () {
 printf "\n Extracting system information \n"
 alluxio collectInfo --local collectEnv $output_path/

 printf "****** free -g ******* \n" > $output_path/additional_sys_info.txt
 free -g >> $output_path/additional_sys_info.txt
 printf "\n\n ****** lscpu ******* \n" >> $output_path/additional_sys_info.txt
 lscpu >> $output_path/additional_sys_info.txt
 printf "\n Completed extracting system information \n"
}

create_archive () {
 printf "\n Creating archive \n"
 hostname=$(hostname -f)
 tar -czvf $output_path/alluxio_info_${hostname}.tar.gz $output_path/collect*
 printf "\n All files archived and ready to collect at: [${output_path}/alluxio_info_${hostname}.tar.gz]  \n"
}

process_collecting_info() {
  clean_dest
  IFS=', ' read -r -a arr <<< "$1"
  for i in ${arr[@]};
  do
    #printf "\n array value: ${i} \n"
    case $i in
      cluster_info) echo "Yo cluster info"
        collect_alluxio_info
        ;;
      config) echo "config created"
        collect_config_files
        ;;
      logs) echo "yo logs"
        collect_logs
        ;;
      sys_info) echo "sys info"
        collect_sys_info
    esac
  done
  create_archive
}

while getopts 'p:c:h' options
do
  case $options in
        p) printf "\n Output path received: ${OPTARG} \n"
                output_path=${OPTARG}
                if [[ $output_path == "" ]]
                then
                        printf "Output path empty so exiting... \n"
                        exit_script
                fi
                ;;
        c) printf "\n Collecting information for: ${OPTARG} \n"
                sub_commands=${OPTARG}
                process_collecting_info $sub_commands
                ;;
        h) exit_script
                ;;
        *) exit_script
                ;;
  esac
done

if [ $OPTIND -eq 1 ];
then
        echo "No options were passed";
        exit_script
fi
