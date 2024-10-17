#!/bin/bash
# Script Name: script.sh
# Author: krishnakishore.reddy@salesforce.com
# Date: 15-Oct-2023

# Description: This script will help to automate the installation of tableau server by asking the prompts from users

# Modification History:
# - Date: 02-Nov-2023
#   Author: Krishnakishore.reddy
#   Description: Added exception Handling 

# Define color codes for text formatting
Green='\033[0;32m'
Blue='\033[0;34m'
Cyan='\033[0;36m'
NC='\033[0m' # No Color
RED='\e[31m'
# Check if the Active Directory JSON file is configured

tsm &> /dev/null

if [[ $? = "0" ]]; then
        echo -e "${Green}Welcome Again!!${NC}"
else
echo -e "${Cyan}Have you configured your Active Directory JSON file for further steps? Please reply with y/n || if you want a local identity store, press y:${NC} " 
read store
if [[ "$store" == "n" ]]; then
    echo -e "${Green}To configure the Identity Store, follow the official Tableau article: [https://help.tableau.com/current/server-linux/en-us/entity_identity_store.htm]${NC}"
    exit 1
fi
fi
# Check whether 'wget' exists or not
if ! command -v wget &> /dev/null; then
    echo -e "${RED}wget command not found. Do you want to install it? (y/n):${NC} " 
    read wget_command
    if [[ "$wget_command" == "y" || "$wget_command" == "Y" ]]; then
      set -x
      yum install wget -y
      set +x
    fi
fi

# Check if 'tsm' command is available

tsm &> /dev/null

if [[ $? != 0 ]]; then
    echo -e  "${Green}tsm command not found, searching for .rpm or .deb file" ${NC}
    sleep 2

    # Check if an RPM or DEB file exists in the current folder
   set -x
   rpm_file=$(ls -1 *.rpm 2>/dev/null)
   deb_file=$(ls -1 *.deb 2>/dev/null)
   set +x
    if [ -n "$rpm_file" ]; then
        # An RPM file is found, ask if the user wants to install it with a custom path
        echo
        echo "Found RPM file: $rpm_file"
        echo -e "${RED}The default installation, which typically occurs in the "/opt" directory, utilizes the "yum" command. This command will automatically resolve any dependencies that are required for the installation process.${NC}"
        echo -e "${RED}On the other hand, a custom installation uses the "rpm" command. In this case, dependencies will not be automatically resolved, and you'll need to manually handle them. Additionally, during a custom installation, you'll have the flexibility to specify the installation location according to your preferences.${NC}"
        echo -e "${Cyan}Do you want to perform a custom install(y) or default install(n)? (y/n): ${NC}"
        read custom_install
        if [[ "$custom_install" == "y" || "$custom_install" == "Y" ]]; then
            echo -e "${Cyan}Enter the preferred installation path:${NC} "
            read install_path
            set -x
            rpm -i --prefix "$install_path" "$rpm_file"
            set +x
if [[ $? != 0 ]]
then
        echo -e "${Cyan}Installing the dependenices!!${NC}"
        set -x
        rpm -ivh --prefix="$install_path" "$rpm_file" &> error.txt
 
        cat error.txt | awk '{print $1}' | grep -v error > dep_list.txt
        for i in $(cat dep_list.txt)
        do
                yum install $i -y
        done
        rm -rf error.txt
        rm -rf dep_list.txt
fi
rpm -ivh --prefix="$install_path" "$rpm_file"
        else
            yum localinstall "$rpm_file" -y
        fi
    elif [ -n "$deb_file" ]; then
        # A DEB file is found, ask if the user wants to install it with a custom path
            apt-get -y install gdebi-core
            gdebi -n "$deb_file"
    else
        # No RPM or DEB file found, prompt for the Tableau Server installation link
        echo
        set +x
        echo -e "${Cyan}Enter the Tableau Server installation link:${NC} " 
        read tableau_link
        set -x
        curl -LO "$tableau_link"
        set +x
        filename=$(basename "$tableau_link")

        if [[ "$filename" == *".rpm" ]]; then
            # Ask if the user wants to perform a custom install for the downloaded RPMi
            echo -e "${RED}The default installation, which typically occurs in the "/opt" directory, utilizes the "yum" command. This command will automatically resolve any dependencies that are required for the installation process.${NC}"
        echo -e "${RED}On the other hand, a custom installation uses the "rpm" command. In this case, dependencies will not be automatically resolved, and you'll need to manually handle them. Additionally, during a custom installation, you'll have the flexibility to specify the installation location according to your preferences.${NC}"
             echo -e "${Cyan}Do you want to perform a custom install(y) or default install(n)? (y/n): ${NC}"
             read custom_install
             if [[ "$custom_install" == "y" || "$custom_install" == "Y" ]]; then
                echo -e "${Cyan}Enter the preferred installation path:${NC} "
                read install_path
                set -x
                rpm -i --prefix "$install_path" "$filename"
                                 if [[ $? != 0 ]]
                                 then
                                         set +x
                                      echo -e "${Cyan}Installing the dependenices!!${NC}"
                                      sleep 2
                                      set -x
                                      rpm -ivh --prefix="$install_path" "$filename" &> error.txt
                                      cat error.txt | awk '{print $1}' | grep -v error > dep_list.txt
                                                 for i in $(cat dep_list.txt)
                                                 do
                                                    yum install $i -y
                                                 done
                                      rm -rf error.txt
                                      rm -rf dep_list.txt
                                 fi
                                 set +x
               set -x
                                 rpm -ivh --prefix="$install_path" "$filename"
            else
                yum localinstall "$filename" -y
            fi
            set +x
        elif [[ "$filename" == *".deb" ]]; then
                set -x
                apt-get -y install gdebi-core    
                gdebi -n "$filename"
                set +x
        else
            echo
            echo -e "${RED}Unsupported file format. Please provide an RPM or DEB file.${NC}"
            exit 1
        fi
    fi

    # Step 3: Initializing Tableau Server 
echo -e "${Cyan}Specify the Admin User:${NC} " 
read admin_user 
        set -x
        if [[ -d "$install_path"/packages ]]; then
                cd "$install_path"/packages/scripts.*
                ./initialize-tsm --accepteula -a "$admin_user" -f
        else
                /opt/tableau/tableau_server/packages/scripts.*/initialize-tsm --accepteula -a "$admin_user" -f
        fi
        set +x
       if [[ $? -ne 0 ]]; then
               echo -e "${RED}Something Went Wrong with initialization, Check your server Once${NC}"
                   exit 1
       else
               sudo su -
                   echo
                   echo "Accepting the Tableau Server license agreement..."
                   # Step 5: Exit and re-login
                   echo -e "${RED}To recognise the TSM command, Please exit your current session and log back in to the Linux Server.${NC}"
                   echo -e "${Green}To configure the tableau server run the same script after relogin to the server${NC}"
       fi
else

    echo -e ""$Green"Tsm command is available. You can proceed with Tableau Server configuration."$NC" "

    # Step 6: Activate Tableau Server license
    echo -e "${Cyan}Enter your Tableau Server license key: " ${NC}
    read license_key
    echo
    set -x
    tsm licenses activate -k "$license_key"
    set +x
    if [[ ${?} -ne 0 ]]
    then
            echo -e "${RED}Error in Licensing, Check the license key once again${NC}"
            exit 1
    else

    # Step 7: Register Tableau Server
    echo "Generate an editable template for registration:"
    set -x
    tsm register --template > registration_file.json
    tsm register --file registration_file.json
    # Step 9 and 10: LDAP configuration (if applicable)
    #echo "If LDAP configuration is required, configure LDAP and disable encryption."
    tsm configuration set -k wgserver.domain.ldap.starttls.enabled -v false --force-keys
    set +x
    fi
# Step 11: Import settings from identity-store.json
echo -e "${Cyan}Choose the Identity Store (ActiveDirectory or Local):${NC} " 
read identity_store

if [[ "$identity_store" == "ActiveDirectory" || "$identity_store" == "Activedirectory" || "$identity_store" == "AD" || "$identity_store" == "ad" ]]; then
    echo -e "${Cyan}Enter the absolute path to identity-store.json:${NC} " 
    read identity_store_path
    set -x
    tsm settings import -f "$identity_store_path"
    set +x
elif [[ "$identity_store" == "local" || "$identity_store" == "Local" ]]; then
        echo -e "${Cyan}Specify the location where tableau server is installed${NC}"
        read install_path
        set -x
        config_files=$(find "$install_path"/packages/scripts* -type f -name "config.json")
        if [ -n "$config_files" ]; then
                tsm settings import -f $config_files
        set +x
        else
                echo "Config file not found in the preferred installation path"
        fi
else
    echo -e "${RED}Invalid choice for Identity Store. Please choose either 'ActiveDirectory' or 'Local'.${NC}"
    exit 1
fi
if [[ $? -ne 0 ]]; then
        exit 1
else

    # Step 13: Apply configuration changes
    set -x
    tsm pending-changes apply
    set +x
fi
    # Step 14: Initialize and start Tableau Server
    set -x
    tsm initialize --start-server --request-timeout 1800
    set +x
if [[ $? -ne 0 ]]; then 
        exit 1
fi
    # Step 15: Create the Tableau Server administrator account
    echo -e "${Cyan}Enter the Tableau Server administrator username:${NC} " 
    read admin_username
    echo -e "${Cyan}Enter the Tableau Server administrator password:${NC} "
    read admin_password
    set -x
    tabcmd initialuser --server 'localhost:80' --username "$admin_username" --password "$admin_password"
    set +x
    if [[ $? -ne 0 ]]
    then
            echo -e "${RED}Something might have gone wrong, possibly due to extra carriage return (Enter key) input from your keyboard.${NC}"
            echo -e "${RED}Run the below command Manually${NC}"
            echo -e "${Green}tabcmd initialuser --server 'localhost:80' --username <admin_username> --password <Password>${NC}"
            exit 1
    else
    echo -e "${Green}Tableau Server is succesfully Configured" ${NC}
    fi
fi
