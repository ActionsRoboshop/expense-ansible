#read -p "Enter component name:" project_component

project_component=${server_name}

if [ -z "${project_component}" ]; then
  echo "Variable is missing: project_component" && exit 1
fi

ami_id="ami-031d574cddc5bb371"
security_group_id="sg-0a88820d7b4d3ff2a"
subnet_id="subnet-0b4d667be365dede4"


zone_id=$(aws route53  list-hosted-zones-by-name --dns-name azcart.online --query "HostedZones[].Id" --output text | awk -F"/" '{print $3}' )
dns_name=$(aws route53  list-hosted-zones-by-name --dns-name azcart.online --query "DNSName" --output text)

create_instance() {
  private_ip=$(aws ec2 run-instances \
    --image-id ${ami_id} \
    --instance-type t3.micro \
    --subnet-id ${subnet_id} \
    --security-group-ids ${security_group_id} \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${component}},{Key=Project,Value=RoboShop}]" \
    --instance-market-options "MarketType=spot,SpotOptions={SpotInstanceType=persistent,InstanceInterruptionBehavior=stop}" --query "Instances[].PrivateIpAddress" --output text)

    cat << EOF > /tmp/route53_record.json
    {
        "Comment": "Update record of $component",
        "Changes": [
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "${component}-dev.$dns_name",
                    "Type": "A",
                    "TTL": 30,
                    "ResourceRecords": [
                        {
                            "Value": "${private_ip}"
                        }
                    ]
                }
            }
        ]
    }
EOF

echo -e "\e[32m"
aws route53 change-resource-record-sets --hosted-zone-id ${zone_id} --change-batch file:///tmp/route53_record.json
echo -e "\e[0m"

}


for component in ${project_component}
do
  create_instance
done