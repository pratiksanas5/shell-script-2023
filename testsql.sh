#!/bin/bash
USER="destination_user"
PASSWORD="$(gcloud secrets versions access latest --secret="destination-password")"
EIP='35.200.175.180'
DATABASE="destination_db"

# Check if sql instance is connecting
if mysql -u $USER -p$PASSWORD -h $EIP $DATABASE -e "SHOW TABLES;" > /dev/null 2>&1; then
  echo "$DATABASE instance is connected."
else
  echo "$DATABASE instance is not connected."
fi

# Connect to the database and execute the queries
  mysql -v -u $USER -p$PASSWORD -h $EIP $DATABASE <<'EOF'
  alter table destination_db.users
  drop column latest_passwords;

  alter table destination_db.users
  add column latest_passwords tinyblob;

  INSERT INTO destination_db.`settings`
  (`id`, `active`, `created_at`, `created_by`, `data`, `modified_at`, `modified_by`, `type`)
  VALUES
  ('008f391f-60c9-4648-9490-7d062d325a43', 1, '2023-05-22 04:41:01', '4f8a7d03-76fe-11ed-a857-4200a9fe0102', '{\"primary\":\"#191A60\",\"secondary\":\"#219CC4\",\"color\":\"#3E3E3E\",\"sidebarSecondary\":\"#6D6D6D\",\"inputBorder\":\"#BCBCBC\",\"placeholder\":\"#BCBCBC\",\"sidebarSubmenu\":\"#E5EDF0\"}', '2023-05-28 09:23:28', 'a9a67a3e-419a-11ea-aed1-02a138ea209a', 'theme');

  DROP TABLE `contract_note`;

  CREATE TABLE `contract_note` (
  `id` char(36) NOT NULL,
  `contract_noteid` varchar(255) NOT NULL,
  `action` varchar(255) DEFAULT NULL,
  `avgrate` double NOT NULL,
  `brok` double NOT NULL,
  `broker_regno` varchar(255) DEFAULT NULL,
  `buyqty` double NOT NULL,
  `client_code` varchar(255) DEFAULT NULL,
  `client_name` varchar(255) DEFAULT NULL,
  `con_flag` varchar(255) DEFAULT NULL,
  `contractno` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `created_by` varchar(255) DEFAULT NULL,
  `cust_code` varchar(255) DEFAULT NULL,
  `cust_name` varchar(255) DEFAULT NULL,
  `dealrate` double NOT NULL,
  `diff` double NOT NULL,
  `exchange` varchar(255) DEFAULT NULL,
  `isin` varchar(255) DEFAULT NULL,
  `m_cpcode` varchar(255) DEFAULT NULL,
  `modified_at` datetime DEFAULT NULL,
  `modified_by` varchar(255) DEFAULT NULL,
  `netamt` double NOT NULL,
  `netrate` double NOT NULL,
  `orderdate` datetime DEFAULT NULL,
  `other_chrg` double NOT NULL,
  `scrip_code` varchar(255) DEFAULT NULL,
  `scripname` varchar(255) DEFAULT NULL,
  `sebi_tax` double NOT NULL,
  `sellqty` double NOT NULL,
  `service_tax` double NOT NULL,
  `sett_no` varchar(255) DEFAULT NULL,
  `sett_type` varchar(255) DEFAULT NULL,
  `stamp_duty` double NOT NULL,
  `stp_date` varchar(255) DEFAULT NULL,
  `stp_provider` varchar(255) DEFAULT NULL,
  `stt` double NOT NULL,
  `t_cpcode` varchar(255) DEFAULT NULL,
  `totall_totbrok` double NOT NULL,
  `totall_tottax` double NOT NULL,
  `totbrok` double NOT NULL,
  `totdch_totbrok` double NOT NULL,
  `totdch_tottax` double NOT NULL,
  `totdvp_totbrok` double NOT NULL,
  `totdvp_tottax` double NOT NULL,
  `tradetype` varchar(255) DEFAULT NULL,
  `turn_tax` double NOT NULL,
  `unique_orderid` varchar(255) DEFAULT NULL,
  `broker_code` varchar(255) DEFAULT NULL,
  `bulk_orderid` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
EOF

echo "Query is excuted"