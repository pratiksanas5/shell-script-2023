CURRENT_TIME: $(date "+%Y.%m.%d-%H.%M.%S")
PROJECT: "ayan-oms"
REGION: "asia-south1"
ZONE: "asia-south1-c"
GCS: "ayan_database_backup"

SOURCE_DATABASE: "pricebridge_uat"
SOURCE_EIP: "34.93.251.38"
SOURCE_PASSWORD: $(gcloud secrets versions access latest --secret="ayan-uat-sql-password")
SOURCE_FILENAME: $SOURCE_DATABASE.$CURRENT_TIME.sql
SOURCE_SQL_INSTANCE: "ayan-uat-south-asia-1-sql"

DESTINATION_DATABASE: "test_db_25062023"
DESTINATION_EIP: "34.93.251.38"
DESTINATION_PASSWORD: $(gcloud secrets versions access latest --secret="ayan-uat-sql-password")
DESTINATION_FILENAME: $DESTINATION_DATABASE.$CURRENT_TIME.sql
DESTINATION_INSTANCE_GROUP_NAME: "pricebridge-uat-asia-south1-mig-2"
DESTINATION_SQL_INSTANCE: "ayan-uat-south-asia-1-sql"

# show public ip of local instance
public_ip=$(curl ifconfig.io)

# Update the authorized network in $SOURCE_PROD_SQL_INSTANCE
gcloud sql instances patch ${SOURCE_SQL_INSTANCE} --authorized-networks="${public_ip}/32" --quiet

# Check if $SOURCE_DATABASE sql instance is connecting
if mysql -u root -p$SOURCE_PASSWORD -h ${SOURCE_EIP} ${SOURCE_DATABASE} -e "SHOW TABLES;" > /dev/null 2>&1; then
    echo "${SOURCE_DATABASE} instance is connected."
else
    echo "${SOURCE_DATABASE} instance is not connected."
fi

# create a backup of $SOURCE_DATABASE & wait until the complete backup 
gcloud sql backups create --async --instance=${SOURCE_SQL_INSTANCE} --project=${PROJECT}
backup_id=$(gcloud sql backups list --instance ${SOURCE_SQL_INSTANCE} | head -2 | tail -1 | awk '{print $1}')
backup_status=$(gcloud sql backups describe ${backup_id} --instance ${SOURCE_SQL_INSTANCE} --format="value(status)")

check=true
while $check; do
    echo "${SOURCE_SQL_INSTANCE} backup is ${backup_status}"; sleep 10;
    backup_status=$(gcloud sql backups describe ${backup_id} --instance ${SOURCE_SQL_INSTANCE} --format="value(status)")
    if [ $backup_status == "RUNNING" ]
    then
    check=true
    else
    check=false
    fi
done

# backup of $SOURCE_DATABASE & copy into GCS.
mysqldump -u root -p$SOURCE_PASSWORD -h ${SOURCE_EIP} --databases ${SOURCE_DATABASE} --triggers --routines --events --set-gtid-purged=OFF > $SOURCE_FILENAME
gsutil cp ${SOURCE_FILENAME} gs://${GCS}

# remove the unauthorized network in $SOURCE_PROD_SQL_INSTANCE
gcloud sql instances patch ${SOURCE_SQL_INSTANCE} --clear-authorized-networks --quiet

# Check if Destination MySQL instance is connecting
if mysql -u root -p$DESTINATION_PASSWORD -h ${DESTINATION_EIP} ${DESTINATION_DATABASE} -e "SHOW TABLES;" > /dev/null 2>&1; then
    echo "${DESTINATION_DATABASE} instance is connected."
else
    echo "${DESTINATION_DATABASE} instance is not connected."
fi

# create a system backup $DESTINATION_SQL
gcloud sql backups create --async --instance=${DESTINATION_SQL_INSTANCE}
backup_id=$(gcloud sql backups list --instance ${DESTINATION_SQL_INSTANCE} | head -2 | tail -1 | awk '{print $1}')
backup_status=$(gcloud sql backups describe ${backup_id} --instance ${DESTINATION_SQL_INSTANCE} --format="value(status)")

check=true
while $check; do
    echo "${DESTINATION_SQL_INSTANCE} backup is ${backup_status}"; sleep 10;
    backup_status=$(gcloud sql backups describe ${backup_id} --instance ${DESTINATION_SQL_INSTANCE} --format="value(status)")
    if [ $backup_status == "RUNNING" ]
    then
    check=true
    else
    check=false
    fi
done

# # Create a backup of $DESTINATION_DATABASE & copy into GCS
mysqldump -u root -p$DESTINATION_PASSWORD -h ${DESTINATION_EIP} --databases ${DESTINATION_DATABASE} --triggers --routines --events --set-gtid-purged=OFF > ${DESTINATION_FILENAME}
gsutil cp ${DESTINATION_FILENAME} gs://${GCS}/

# stop the $DESTINATION_INSTANCE_GROUP
gcloud compute instance-groups managed set-autoscaling ${DESTINATION_INSTANCE_GROUP_NAME} --region ${REGION} --min-num-replicas=0 --max-num-replicas=0

# Get the list of instances in the managed instance group
INSTANCE_LIST=$(gcloud compute instance-groups managed list-instances ${DESTINATION_INSTANCE_GROUP_NAME} --region ${REGION} --format="value(instance,state)" --filter instanceStatus='running' | wc -l )

while (( $INSTANCE_LIST != 0 )); do
    echo "Stopping ${INSTANCE_LIST} running instances.."; sleep 10;
    INSTANCE_LIST=$(gcloud compute instance-groups managed list-instances ${_DESTINATION_INSTANCE_GROUP_NAME} --region ${_REGION} --format="value(instance,state)" --filter instanceStatus='running' | wc -l )
done

# create database in $DESTINATION if not present
mysql -u root -p$DESTINATION_PASSWORD -h ${DESTINATION_EIP} -e "CREATE DATABASE IF NOT EXISTS \`$DESTINATION_DATABASE\`;"

# changes in backup & restore into destination
sed -i '22s/^/-- /' ${SOURCE_FILENAME}
sed -i "24s/${SOURCE_DATABASE}/${DESTINATION_DATABASE}/" ${SOURCE_FILENAME}
mysql -u root -h ${DESTINATION_EIP} -p$DESTINATION_PASSWORD ${DESTINATION_DATABASE} < ${SOURCE_FILENAME}

# start the $DESTINATION_INSTANCE_GROUP
gcloud compute instance-groups managed set-autoscaling ${DESTINATION_INSTANCE_GROUP_NAME} --region ${REGION} --min-num-replicas=1 --max-num-replicas=1

# Loop through each instance and check its status
while (( $INSTANCE_LIST == 1 )); do
    echo "Starting ${INSTANCE_LIST} running instances.."; sleep 10;
    INSTANCE_LIST=$(gcloud compute instance-groups managed list-instances ${DESTINATION_INSTANCE_GROUP_NAME} --region ${REGION} --format="value(instance,state)" --filter instanceStatus='running' | wc -l )
done

#check status
echo "${DESTINATION_INSTANCE_GROUP_NAME} instance is started"