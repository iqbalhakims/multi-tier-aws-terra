# multi-tier-aws-terra
 AWS Multi-Tier Architecture with Terraform  

## **Overview**  
This project demonstrates the deployment of a highly available multi-tier architecture on AWS using Terraform for infrastructure as code (IaC). The architecture includes public and private subnets, an application load balancer (ALB), EC2 instances, and an RDS MySQL database.  

## **Key Features**  
- Automated deployment using Terraform.  
- Secure VPC setup with public and private subnets.  
- Load balancing and traffic distribution using AWS ALB.  
- Database hosting with AWS RDS (MySQL) and SSL encryption.  
- Domain management via Route53 with SSL certificates from AWS Certificate Manager.  

## **Technologies Used**  
- **Cloud Platform:** AWS (EC2, S3, RDS, ALB, VPC, Route53)  
- **IaC Tool:** Terraform  
- **Database:** MySQL on AWS RDS  
- **Languages:** PHP (for deployed application)  

## **Architecture Diagram**  


## **Project Structure**  
```plaintext
├── terraform/  
│   ├── main.tf           # Main Terraform configuration  
│   ├── variables.tf      # Input variables  
│   ├── outputs.tf        # Output values  
│   └── ...               # Other Terraform modules  
├── app/                  # PHP application files  
└── README.md             # Project documentation  
