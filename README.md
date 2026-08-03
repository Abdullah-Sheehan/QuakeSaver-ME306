## QuakeSAVER - Multi-Agent Decentralized Autonomous Rescue System

A decentralized multi-agent UAV/UGV system for earthquake disaster response, developed as an ME 366 (Electro-Mechanical System Design) capstone project at BUET. Motivated by Bangladesh's seismic hazard — particularly the Sylhet/Dauki fault zone — QuakeSAVER coordinates two UAVs ("Scout" and "Relay") and two ground rovers to search, detect, and map victims in earthquake-affected environments without relying on centralized control.

The system uses an auction-based Contract Net Protocol (CNP) for task allocation and a Bully election algorithm for leader selection within agent pools, with the base station acting as a passive observer holding only a human ABORT override. UAVs run on Pixhawk 2.4.8 + ArduCopter with Raspberry Pi 4 companion computers; UGVs run ROS 2 Humble with Nav2 and slam_toolbox for autonomous navigation and mapping. Inter-agent communication uses LoRa (433 MHz).

Stack: ROS 2 (Humble/Jazzy) · MAVROS · ArduPilot SITL · Gazebo
