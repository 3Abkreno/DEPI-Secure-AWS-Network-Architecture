#!/usr/bin/env bash
# Nightly check (person 3): every list below should be empty when nobody is working.
set -uo pipefail
q() { echo "--- $1"; shift; "$@" --output text || true; }
q "Transit gateways"   aws ec2 describe-transit-gateways --query "TransitGateways[?State=='available'].TransitGatewayId"
q "TGW attachments"    aws ec2 describe-transit-gateway-attachments --query "TransitGatewayAttachments[?State=='available'].TransitGatewayAttachmentId"
q "VPN connections"    aws ec2 describe-vpn-connections --query "VpnConnections[?State=='available'].VpnConnectionId"
q "Client VPN"         aws ec2 describe-client-vpn-endpoints --query "ClientVpnEndpoints[].ClientVpnEndpointId"
q "Running EC2"        aws ec2 describe-instances --filters Name=instance-state-name,Values=running --query "Reservations[].Instances[].InstanceId"
q "RDS instances"      aws rds describe-db-instances --query "DBInstances[].DBInstanceIdentifier"
q "Load balancers"     aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerName"
q "Interface endpoints" aws ec2 describe-vpc-endpoints --query "VpcEndpoints[?VpcEndpointType=='Interface'].VpcEndpointId"
q "NAT gateways (must never exist)" aws ec2 describe-nat-gateways --filter Name=state,Values=available --query "NatGateways[].NatGatewayId"
q "Elastic IPs"        aws ec2 describe-addresses --query "Addresses[].PublicIp"
q "Mirror sessions"    aws ec2 describe-traffic-mirror-sessions --query "TrafficMirrorSessions[].TrafficMirrorSessionId"
q "EBS snapshots"      aws ec2 describe-snapshots --owner-ids self --query "Snapshots[].SnapshotId"
