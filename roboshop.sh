#!/bin/bash

SG_ID="sg-0c5c5675a6975d499"
AMI_ID="ami-0220d79f3f480ecf5"
SUBNET_ID="subnet-0503024fbd8ea122a"
ZONE_ID="Z027359523QFZK0V41S4X"
DOMAIN_NAME="cineniti.in"

for instance in $@
do
    INSTANCE_ID=$( aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type "t3.micro" \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_ID \
    --associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
    --query 'Instances[0].InstanceId' \
    --output text )
    echo "Launched instance $instance with ID $INSTANCE_ID"
    
    if [ "$instance" == "frontend" ]; then
        IP=$(
            aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query 'Reservations[].Instances[].PublicIpAddress' \
            --output text
        )
        RECORD_NAME="$DOMAIN_NAME"
    else
        IP=$(
            aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query 'Reservations[].Instances[].PrivateIpAddress' \
            --output text
        )
        RECORD_NAME="$instance.$DOMAIN_NAME"
    fi  
    
    echo "IP Address: $IP"
    echo "==========================="

    aws route53 change-resource-record-sets \
    --hosted-zone-id $ZONE_ID \
    --change-batch "{
        \"Comment\": \"Updating record\",
        \"Changes\": [
            {
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
                \"Name\": \"$RECORD_NAME\",
                \"Type\": \"A\",
                \"TTL\": 1,
                \"ResourceRecords\": [
                {
                    \"Value\": \"$IP\"
                }
                ]
            }
            }
        ]
    }"

    echo "record updated for $instance"
done