# Introduction

This project is our DevOps Midterm project repository. In this project, we deploy the sample node js application to the cloud. This repository contains all the source code for the app as well as the scripts needed to run a traditional deployment as well as a container deployment.

# Team Members

**Saw Baw Mu Thaw - 523K0077**
**Nan Hnin Yai Kyi - 523K0051**
**Aung Khant Paing - 523K0072**

# Tech Stack

The application is a node js CRUD application. The database is mongodb. The `phase1` folder contains the souce code as well as setup script. `phase2` folder contains the deployment and configuration scripts inside `scripts` folder. `phase3` folder contains the source code for building the node image, docker-compose file as well as scripts for running it.

## Instructions

1. Get a ubuntu cloud server (AWS, Azure, etc) with 15gb of space.
2. If you use AWS, only allow port 22, 80 and 443 in security group. Add a keypair. Get an elastic IP for DNS record.
4. SSH into your server and run `git clone https://github.com/SawBawMuThaw/DevOpsMidterm.git`
3. Go to cloned directory

### Phase 2 Instruction (traditional deployment)
4. From inside the cloned directory, run `sudo bash ./phase1/scripts/setup.sh`. This will install required dependencies
5. Run `sudo bash ./phase2/scripts/ufw-setup.sh`
5. Run `nano ./phase1/.env` and add following. Save it.
```
PORT=3000
MONGO_URI=mongodb://localhost:27017/products_db
```

5. Run the following commands to run the node js application.
```
$ pm2 start ./phase1/main.js -n trad-app
$ pm2 startup
```
Copy and run the command given by startup.
```
$ pm2 save
```
6. Run the following commands to set up nginx reverse proxy and https.
```
$ sudo cp ./phase2/scripts/nginx.conf /etc/nginx/nginx.conf
$ sudo certbot --nginx
```
Choose all domains.

7. Create DNS records. If you are using AWS, associate elastic IP with your instance and use this IPv4 address to create 2 DNS A records for aqiu.click and www.aqiu.click respectively.

**You are now done with the traditional deployment**

### Phase 3 Instruction (Docker Container Deployment)
8. From inside the cloned directory, run `sudo bash ./phase3/scripts/setup-docker.sh`. This will install docker and run docker compose.
9. Optional: Run `sudo bash ./phase3/scripts/transfer-data.sh` if you wish to tranfer data from phase 2 to phase3. **Note that the seed data will be duplicated**
10. Run the following commands to reconfigure nginx reverse proxy and https.
```
$ sudo cp ./phase3/scripts/nginx.conf /etc/nginx/nginx.conf
$ sudo certbot --nginx
```
Choose all domains and choose attempt to reinstall this existing certificate

**You are now done with container deployment**

# Scripts
**Note: These scripts are designed to only run under the cloned directory. Running them elsewhere might cause errors**
* `phase1/scripts/setup.sh` - This script refreshes package index, installs the latest nodejs runtime, mongodb and ufw. Also install pm2 and dependencies for application.
* `phase2/scripts/ufw-setup.sh` - This script sets up the ufw firewall to only allow SSH(22), HTTP(80) and HTTPS(443) connections.
* `phase2/scripts/nginx.conf` - This is the nginx configuration file for phase 2. Redirects all traffic coming in HTTP and HTTPS port to local port 3000 where our app is listening.
* `phase3/scripts/setup-docker.sh` - This script refreshes index, installs docker and run the docker compose file. 
* `phase3/scripts/transfer-data.sh` - This script copies the data from phase 2 to 3. It dumps the products_db collection. Restores it inside the mongodb container. Then copies the images in upload folder to `uploads_data` volume.
* `phase3/scripts/nginx.conf` - This is the nginx configuration file for phase 3. Redirects all traffic coming in HTTP and HTTPS port to local port 3001 where our node container is listening.

# Environment Variables
* **PORT**-The port number of the application
* **MONGO_URI**-The mongodb connection string. The default string in this case.