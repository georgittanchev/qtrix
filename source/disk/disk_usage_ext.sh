#!/bin/bash

# Additional disk usage checks from disk_usage.sh
# This script collects advanced disk usage data

# Determine server type
server=$(/bin/hostname)
if [ -z $(echo "$server" | grep pro ) ]; then
    server_type='regular'
else
    server_type='pro'
fi

# Check for large system logs
check_system_logs() {
    system_logs_total=$( find /usr/local/ /var/ -type f -iname '*log' -size +500M -exec du -hsxc {} + | sort -k 2 | head -n 1 | awk '{print$1}' )

    if [ -n "$system_logs_total" ]; then
        system_logs=$( find /usr/local/ /var/ -type f -iname '*log' -size +500M -exec du -hsx {} + | sort -rh )
        echo "System Logs:"
        echo "Total: $system_logs_total" 
        echo "$system_logs"
        echo
    fi
}

# Check MySQL temporary file size
check_mysql_temp() {
    if [ -f /var/lib/mysql/ibtmp1 ]; then
        mysql_ibtmp1_size_in_gb=$( echo `du -sm /var/lib/mysql/ibtmp1` | awk '{ print $1 / 1024 }' | cut -d . -f 1 )

        if [ "$mysql_ibtmp1_size_in_gb" -gt 30 ]; then
            echo "The size of the ibtmp1 file is $mysql_ibtmp1_size_in_gb GB."
            echo
        fi
    fi
}

# Check large files in home and transfer directories
check_home_transfer_files() {
    total_size_for_files_in_homedir_and_transfer_dir=$( find /home/ /home/transfer/ /var/www/html/ -maxdepth 1 -type f -size +200M -exec du -hsxc {} + | sort -rh | head -n 1 | awk '{print$1}' 2>/dev/null )

    if [ -n "$total_size_for_files_in_homedir_and_transfer_dir" ]; then
        size_for_files_in_homedir_and_transfer_dir=$( find /home/ /home/transfer/ /var/www/html/ -maxdepth 1 -type f -size +200M -exec du -hsx {} + | sort -rh 2>/dev/null )
        echo "Total Size of Backups in /home/, /home/transfer/ and /var/www/html/ Directories:" 
        echo "Total: $total_size_for_files_in_homedir_and_transfer_dir" 
        echo "$size_for_files_in_homedir_and_transfer_dir"
        echo
    fi
}

# Check large user files
check_user_large_files() {
    if command -v whmapi1 >/dev/null 2>&1; then
        for user in $(whmapi1 listaccts | grep 'user:' | awk '{print$2}' | sort ); do
            output=$( find /home/"$user" -maxdepth 7 ! -path "/home/*/tmp/analog/*" -type f -size +200M -exec du -hsxc {} + | sort -rh 2>/dev/null )

            if [ -n "$output" ]; then
                total=$( echo "$output" | head -n 1 | awk '{print$1}' )
                echo "$total" - "$user"
            fi
        done | sort -rh | awk '{print$1, $3}' | while read total user; do
            echo "User: $user"
            find /home/"$user" -maxdepth 7 ! -path "/home/*/tmp/analog/*" -type f -size +200M -exec du -hsxc {} + | sort -rh 2>/dev/null
            echo
        done
    fi
}

# Check for large backup directories
check_backup_dirs() {
    large_backup_directories=$(find /home/ -maxdepth 7 -type d \( -iname '*backup*' -o -iname '*updraft*' -o -iname '*wp-snapshots*' -o -iname '*wp-clone*' \) -exec du -hsx {} + | grep '[0-9]G' | sort -rh 2>/dev/null)

    if [ ! -z "$large_backup_directories" ]; then
        echo "Backup Directories Larger Than 1GB:"
        echo "$large_backup_directories"
        echo
    fi
}

# Check for large LS Cache directories (only on pro servers)
check_lscache() {
    if [ "$server_type" = 'pro' ]; then
        large_lscache_directories=$(du -sh /home/*/lscache/ 2>/dev/null | sort -rh | grep '[0-9]G')

        if [ ! -z "$large_lscache_directories" ]; then
            echo "Users with LS Cache Directory Larger Than 1GB:"
            echo "$large_lscache_directories"
            echo
        fi
    fi
}

# Check for other large cache directories
check_cache_dirs() {
    large_cache_directories=$(find /home/ -maxdepth 7 ! -path "/home/*/lscache" -type d -iname '*cache*' -exec du -hsx {} + | sort -rh | grep '[0-9]G' 2>/dev/null)

    if [ ! -z "$large_cache_directories" ]; then
        echo "Cache Directory Larger Than 1GB:"
        echo "$large_cache_directories"
        echo
    fi
}

# Check for large transfer directories and files
check_transfer() {
    transfer_dirs_and_files=$( du -sh /home/*/*transfer* 2>/dev/null | sort -rh | grep '[0-9]G')

    if [ ! -z "$transfer_dirs_and_files" ]; then
        echo "Transfer Files and Directories Larger Than 1GB:"
        echo "$transfer_dirs_and_files"
        echo
    fi
}

# Check for other public_html directories
check_public_html() {
    other_public_html_directories=$(du -sh /home/*/public_html-* /home/*/public_html_* 2>/dev/null | grep '[0-9]G' | sort -rh)

    if [ ! -z "$other_public_html_directories" ]; then
        echo "Other public_html Directories Larger Than 1GB:"
        echo "$other_public_html_directories"
        echo
    fi
}

# Check for large trash directories
check_trash() {
    large_trash_directories=$(du -sh /home/*/.trash 2>/dev/null | grep '[0-9]G' | sort -rh)

    if [ ! -z "$large_trash_directories" ]; then
        echo "Large Trash Directories:"
        echo "$large_trash_directories"
        echo
    fi
}

# Function to run all checks and collect results
run_extended_disk_checks() {
    result=""
    
    # Run each check and collect results
    result+=$(check_system_logs)
    result+=$(check_mysql_temp)
    result+=$(check_home_transfer_files)
    result+=$(check_user_large_files)
    result+=$(check_backup_dirs)
    result+=$(check_lscache)
    result+=$(check_cache_dirs)
    result+=$(check_transfer)
    result+=$(check_public_html)
    result+=$(check_trash)
    
    echo "$result"
}

# If script is executed directly, run all checks
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_extended_disk_checks
fi 