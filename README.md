# BWRP - Blockchain Wholesale Roaming Project

This repository contains all setup files for joining the production network.
It is based on Kubernetes and provides scripts for generating crypto material and starting pods as well as configuration files. 
For a general description of this project's software architechture, components and workflows, please check the [wiki page](https://github.com/GSMA-CPAS/BWRP).

## Pre-requisites

Ubuntu Linux LTS 16.04 and Above
2 CPU Machine and Above
4 Gb RAM and Above

Either AWS Ubuntu Instance or Standalone 
machine/network with static IP can also be used

Update the Hostname of the machine by updating below files -
- /etc/hosts
- /etc/hostname

Make sure you "reboot" the instance to bring hostname changes into effect.
And use this new hostname in further "docker" and "kubernetes" installation processes.
