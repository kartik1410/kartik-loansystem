CREATE TABLE IF NOT EXISTS `players_loan` (
  `loan_id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL DEFAULT '0',
  `loan_details` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`loan_details`)),
  `status` int(11) NOT NULL DEFAULT 0,
   PRIMARY KEY (`loan_id`)
);