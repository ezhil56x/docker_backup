#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo or as root. Exiting."
    exit 1
fi

clear

user_home=$(eval echo ~${SUDO_USER})
backup_dir="$user_home/docker_volume_backups"

if [ ! -d "$backup_dir" ]; then
    mkdir -p "$backup_dir"
    echo "Created backup directory: $backup_dir"
fi

echo ""
echo "====================================="
echo "        Docker Volume Manager        "
echo "====================================="
echo ""
echo "1. Backup Docker Volume"
echo "2. Restore Docker Volume"
echo "3. Backup All Docker Volumes"
echo "4. Restore All Docker Volumes"
echo ""
echo "-------------------------------------"

read -p "Enter your choice (1-4): " action
clear

if [ "$action" == "1" ]; then
    echo ""
    echo "-------------------------------------"
    echo "          Backup Docker Volumes      "
    echo "-------------------------------------"
    echo ""

    volumes=($(docker volume ls -q))

    if [ ${#volumes[@]} -eq 0 ]; then
        echo "No Docker volumes found. Exiting."
        exit 1
    fi

    echo "Available Docker volumes:"
    for i in "${!volumes[@]}"; do
        echo "$((i+1)). ${volumes[$i]}"
    done

    echo ""
    read -p "Select the volume number to backup: " volume_number

    if [ "$volume_number" -le "${#volumes[@]}" ] && [ "$volume_number" -ge 1 ]; then
        volume="${volumes[$((volume_number-1))]}"
    else
        echo "Invalid selection. Exiting."
        exit 1
    fi

    container_id=$(docker ps -q -f volume=$volume)
    if [ ! -z "$container_id" ]; then
        docker stop $container_id
    fi

    backup_file="$backup_dir/${volume}.tar.gz"
    uid=$(id -u ${SUDO_USER})
    gid=$(id -g ${SUDO_USER})
    docker run --rm -v $volume:/volume -v $backup_dir:/backup --user $uid:$gid ubuntu bash -c "cd /volume && tar czf /backup/${volume}.tar.gz ."

    if [ ! -z "$container_id" ]; then
        docker start $container_id
    fi

    echo ""
    echo "Backup completed for volume '$volume' at:"
    echo "$backup_file"
    echo ""

elif [ "$action" == "2" ]; then
    echo ""
    echo "-------------------------------------"
    echo "        Restore Docker Volumes       "
    echo "-------------------------------------"
    echo ""

    backups=($(ls $backup_dir))
    if [ ${#backups[@]} -eq 0 ]; then
        echo "No backups found. Exiting."
        exit 1
    fi

    echo "Available Docker volume backups:"
    for i in "${!backups[@]}"; do
        echo "$((i+1)). ${backups[$i]}"
    done

    echo ""
    read -p "Select the backup number to restore: " backup_number

    if [ "$backup_number" -le "${#backups[@]}" ] && [ "$backup_number" -ge 1 ]; then
        backup="${backups[$((backup_number-1))]}"
    else
        echo "Invalid selection. Exiting."
        exit 1
    fi

    volume=$(echo $backup | cut -d'.' -f1)

    docker run --rm -v $volume:/volume -v $backup_dir:/backup ubuntu bash -c "cd /volume && tar xzf /backup/$backup"

    echo ""
    echo "Restore completed for volume '$volume' from backup:"
    echo "$backup"
    echo ""

elif [ "$action" == "3" ]; then
    echo ""
    echo "-------------------------------------"
    echo "       Backup All Docker Volumes     "
    echo "-------------------------------------"
    echo ""

    volumes=($(docker volume ls -q))

    if [ ${#volumes[@]} -eq 0 ]; then
        echo "No Docker volumes found. Exiting."
        exit 1
    fi

    for volume in "${volumes[@]}"; do
        container_id=$(docker ps -q -f volume=$volume)
        if [ ! -z "$container_id" ]; then
            docker stop $container_id
        fi

        backup_file="$backup_dir/${volume}.tar.gz"
        uid=$(id -u ${SUDO_USER})
        gid=$(id -g ${SUDO_USER})
        docker run --rm -v $volume:/volume -v $backup_dir:/backup --user $uid:$gid ubuntu bash -c "cd /volume && tar czf /backup/${volume}.tar.gz ."

        if [ ! -z "$container_id" ]; then
            docker start $container_id
        fi

        echo "Backup completed for volume '$volume' at: $backup_file"
    done

    echo ""
    echo "All volumes have been backed up."
    echo ""

elif [ "$action" == "4" ]; then
    echo ""
    echo "-------------------------------------"
    echo "      Restore All Docker Volumes     "
    echo "-------------------------------------"
    echo ""

    backups=($(ls $backup_dir))
    if [ ${#backups[@]} -eq 0 ]; then
        echo "No backups found. Exiting."
        exit 1
    fi

    for backup in "${backups[@]}"; do
        volume=$(echo $backup | cut -d'.' -f1)
        docker run --rm -v $volume:/volume -v $backup_dir:/backup ubuntu bash -c "cd /volume && tar xzf /backup/$backup"
        echo "Restore completed for volume '$volume' from backup: $backup"
    done

    echo ""
    echo "All volumes have been restored."
    echo ""

else
    echo "Invalid choice. Exiting."
    exit 1
fi
